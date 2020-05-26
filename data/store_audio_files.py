'''
Fetches all selected recordings from xeno-canto. Any permanent errors should be
manually added to `recordings_blacklist.txt` and then `select_recordings`
should be re-run to select alternative recordings or drop that species
altogether.
'''

import io
import logging
import multiprocessing.pool
import os
import os.path
import signal
import sys

import numpy as np
import pydub
import pydub.effects

import fetcher
import progress
from recordings import Recording, SelectedRecording


_fetcher = None


def _otsu_threshold(array):
    '''
    Computes a binary classification threshold for the given array using Otsu's
    method:
    https://en.wikipedia.org/wiki/Otsu%27s_method
    '''
    num_bins = 256
    hist, bin_edges = np.histogram(array, bins=num_bins)

    # The implementation below does not look at bin_edges at all; in other
    # words, it assumes equal-sized bins.
    total_weight = hist.sum()
    total_sum = np.dot(range(num_bins), hist)
    background_sum = 0.0
    background_weight = 0.0
    best_quality = -np.inf
    best_bin_edge = None
    qualities = np.zeros(hist.shape)
    for i in range(num_bins):
        foreground_weight = total_weight - background_weight
        if background_weight > 0 and foreground_weight > 0:
            background_mean = background_sum / background_weight
            foreground_mean = (total_sum - background_sum) / foreground_weight
            quality = background_weight * foreground_weight * \
                (background_mean - foreground_mean) * (background_mean - foreground_mean)
            qualities[i] = quality
            if quality >= best_quality:
                best_quality = quality
                best_bin_edge = i
        background_weight += hist[i]
        background_sum += i * hist[i]

    threshold = bin_edges[best_bin_edge]
    if _args.debug_otsu_threshold:
        import matplotlib.pyplot as plt
        logging.info(f'Histogram from {bin_edges[0]} to {bin_edges[-1]}, Otsu threshold at {threshold}')
        fig, ax1 = plt.subplots()
        ax1.hist(bin_edges[:-1], bin_edges, weights=hist, color=(0.1, 0.2, 1.0))
        ax2 = ax1.twinx()
        ax2.plot(bin_edges[:-1], qualities, color=(1.0, 0.2, 0.1))
        ax2.axvline(x=threshold, color=(0.1, 1.0, 0.2))
        plt.show()
    return threshold


def _detect_utterances(sound, max_gap_ms=100):
    '''
    Classifies each millisecond of audio as either "utterance" or "silence"
    based on whether loudness is above the Otsu threshold. Returns runs of
    mostly consecutive utterance as a list of (start_ms, end_ms) tuples.

    "Mostly" consecutive is defined by max_gap_ms; if two runs of utterance are
    closer together than this, they are merged into one.
    '''
    # RMS is easier to work with because it doesn't contain -inf, but dBFS
    # gives a much clearer histogram in practice.
    loudnesses = np.array([ms.dBFS for ms in sound])
    loudnesses[loudnesses == -np.inf] = -90
    utterance_threshold = _otsu_threshold(loudnesses)

    utterances = []
    utterance_start = None
    silence_ms = None
    for ms, loudness in enumerate(loudnesses):
        if loudness >= utterance_threshold:
            if utterance_start is None:
                utterance_start = ms
            silence_ms = 0
        else:
            if utterance_start is not None:
                silence_ms += 1
                if silence_ms >= max_gap_ms:
                    utterances.append((utterance_start, ms - silence_ms))
                    utterance_start = None
                    silence_ms = None

    if utterance_start is not None:
        # Final utterance ran right up to the end of the sound.
        utterances.append((utterance_start, ms - silence_ms))

    return utterances


def _process_recording(recording):
    '''
    Entry point for parallel processing.
    '''

    global _fetcher
    if not _fetcher:
        _fetcher = fetcher.Fetcher('audio_files', pool_size=1)

    # Android hates colons in file names in a really nonobvious way:
    # https://stackoverflow.com/questions/52245654/failed-to-open-file-permission-denied
    output_file_name = f'{recording.recording_id.replace(":", "_")}.ogg'
    full_output_file_name = os.path.join(_args.audio_file_output_dir, output_file_name)
    if os.path.exists(full_output_file_name) and not _args.recreate_audio_files and not _args.debug_recording_ids:
        return output_file_name

    try:
        data = _fetcher.fetch_cached(recording.audio_url)
    except fetcher.FetchError as ex:
        logging.error(f'Error fetching {recording.recording_id}: {ex}')
        return None

    try:
        sound = pydub.AudioSegment.from_file(io.BytesIO(data), 'mp3')
    except Exception as ex:
        # These errors can get extremely long.
        logging.error(f'Failed to decode audio file for {recording.url} '
                      f'(cache file {_fetcher.cache_file_name(recording.audio_url)}): {str(ex)[:5000]}')
        return None

    # pydub does everything in milliseconds.
    sound = sound[:1000 * _args.audio_scan_duration]
    sound = sound.set_channels(1)
    sound = sound.set_frame_rate(_args.audio_sample_rate)

    padding_duration = round(1000 * _args.audio_padding_duration)
    fade_duration = round(1000 * _args.audio_fade_duration)

    # Find longest utterance, the end of which is a good place to cut off the
    # sample.
    utterances = list(_detect_utterances(sound))
    # This should not happen, because the threshold is such that there is
    # always something above it.
    assert utterances, f'No utterances detected in {recording.url}'

    _, longest_utterance_end = max(utterances, key=lambda start_end: start_end[1] - start_end[0])
    start_ms = 0
    end_ms = max(round(1000 * _args.min_audio_duration), longest_utterance_end + padding_duration)
    sound = sound[start_ms:end_ms]

    sound = sound.fade_in(fade_duration).fade_out(fade_duration)
    sound = pydub.effects.normalize(sound)

    if _args.debug_utterances:
        import subprocess
        import tempfile
        from PIL import Image, ImageDraw
        sonogram_data = _fetcher.fetch_cached(recording.sonogram_url_full)
        sonogram = Image.open(io.BytesIO(sonogram_data))
        draw = ImageDraw.Draw(sonogram, mode='RGBA')
        def highlight(start_ms, end_ms, color):
            # Fixed parameters for full sonograms drawn by xeno-canto.
            margin_left = 66
            px_per_ms = 75 / 1000
            left_px = margin_left + px_per_ms * start_ms
            right_px = margin_left + px_per_ms * end_ms
            draw.rectangle(((left_px, 0), (right_px, sonogram.height)), fill=color)
        highlight(start_ms, end_ms, (128, 128, 255, 32))
        for (s, e) in utterances:
            highlight(s, e, (128, 255, 128, 64))
        with tempfile.NamedTemporaryFile() as f:
            sonogram.save(f, format='png')
            subprocess.run(['eog', f.name])

    if _args.debug_recording_ids:
        return None

    sound.export(full_output_file_name + '.tmp', format='ogg', parameters=['-q:a', str(_args.audio_quality)])
    os.rename(full_output_file_name + '.tmp', full_output_file_name)

    return output_file_name


def add_args(parser):
    parser.add_argument(
        '--audio_file_output_dir',
        default=os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'sounds'),
        help='Directory to write compressed and trimmed audio files for recordings to')
    parser.add_argument(
        '--recreate_audio_files', action='store_true',
        help='Overwrite files instead of assuming they are up to date')
    parser.add_argument(
        '--audio_process_jobs', type=int, default=8,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')
    parser.add_argument(
        '--audio_scan_duration', type=float, default=60.0,
        help='Amount of audio to scan for a suitable sample, from the beginning of the recording')
    parser.add_argument(
        '--min_audio_duration', type=float, default=5.0,
        help='Minimum duration in seconds of exported audio clips')
    parser.add_argument(
        '--max_audio_duration', type=float, default=12.0,
        help='Maximum duration in seconds of exported audio clips')
    parser.add_argument(
        '--audio_fade_duration', type=float, default=0.05,
        help='Duration in seconds of fade in/out')
    parser.add_argument(
        '--audio_padding_duration', type=float, default=0.3,
        help='Amount of silence in seconds to include around the bird sound (including the fade)')
    parser.add_argument(
        '--audio_sample_rate', type=int, default=44100,
        help='Sample rate in Hz of output audio')
    parser.add_argument(
        '--audio_quality', type=float, default=2.0,
        help='OGG/Vorbis quality level of output audio between -1.0 and 10.0')
    parser.add_argument(
        '--debug_recording_ids', type=str, default=None,
        help='Process only the given recording IDs (comma separated), do not store results, and show debug windows')
    parser.add_argument(
        '--debug_otsu_threshold', action='store_true',
        help='Show debug rendering of Otsu thresholding')
    parser.add_argument(
        '--debug_utterances', action='store_true',
        help='Show debug rendering of utterance detection')


_args = None


def main(args, session):
    global _args
    _args = args

    if args.debug_recording_ids:
        logging.info('Loading specified recordings')
        recording_ids = args.debug_recording_ids.split(',')
        recordings = session.query(Recording)\
            .filter(Recording.recording_id.in_(recording_ids))\
            .all()
        for recording in recordings:
            logging.info(f'Processing recording {recording.recording_id}')
            _process_recording(recording)
        return

    logging.info('Loading selected recordings')
    selected_recordings = session.query(Recording).join(SelectedRecording).all()

    logging.info('Listing existing audio files')
    old_audio_files = set(os.listdir(args.audio_file_output_dir))

    logging.info('Fetching and processing audio files')
    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.image_process_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)
        for output_file_name in progress.percent(
                pool.imap(_process_recording, selected_recordings),
                len(selected_recordings)):
            if output_file_name:
                old_audio_files.discard(output_file_name)

    logging.info(f'Deleting {len(old_audio_files)} old audio files')
    for old_audio_file in old_audio_files:
        try:
            os.remove(os.path.join(args.audio_file_output_dir, old_audio_file))
        except OSError as ex:
            logging.warning(f'Could not delete {old_audio_file}: {ex}')
