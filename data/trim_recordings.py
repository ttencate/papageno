'''
Fetches all selected recordings from xeno-canto and trims them according to
various settings. Any permanent errors should be manually added to
`recording_overrides.csv` and then `select_recordings` should be re-run to
select alternative recordings.
'''

import io
import logging
import multiprocessing.pool
import os
import os.path
import signal

import numpy as np
import pydub
import pydub.effects

import fetcher
import progress
from recordings import Recording, SelectedRecording


TRIMMED_RECORDINGS_DIR = os.path.join(os.path.dirname(__file__), 'cache', 'trimmed_recordings')

# Seconds of audio to scan for a suitable sample, from the beginning of the recording
_AUDIO_SCAN_DURATION = 60.0
# Minimum duration in seconds of exported audio clips
_MIN_AUDIO_DURATION = 3.0
# Maximum duration in seconds of exported audio clips
_MAX_AUDIO_DURATION = 8.0
# Duration in seconds of fade in/out
_AUDIO_FADE_DURATION = 0.05
# Amount of silence in seconds to include around the bird sound (including the fade)
_AUDIO_PADDING_DURATION = 0.3
# Minimum silence time for concesutive non-silence to be considered separate utterances
_MIN_UTTERANCE_GAP = 0.3
# Sample rate in Hz of output audio
_AUDIO_SAMPLE_RATE = 44100
# OGG/Vorbis quality level of output audio between 0.0 and 10.0
# (should go down to -2.0, but negative values seem to end up as 3.0)
_AUDIO_QUALITY = 1.0


_fetcher = None


def trimmed_recording_file_name(recording):
    return os.path.join(TRIMMED_RECORDINGS_DIR, f'{recording.recording_id}.ogg')


def trim_recording(recording,
                   skip_if_exists=True, skip_write=False,
                   debug_otsu_threshold=False, debug_utterances=False):
    '''
    Trims the given recording and stores it to a file.
    Returns the file name, or None if this recording is permanently untrimmable for some reason.
    '''

    global _fetcher # pylint: disable=global-statement
    if not _fetcher:
        _fetcher = fetcher.Fetcher('recordings', pool_size=1)

    output_file_name = trimmed_recording_file_name(recording)
    if skip_if_exists and os.path.exists(output_file_name):
        return output_file_name

    try:
        data = _fetcher.fetch_cached(recording.audio_url)
    except fetcher.FetchError as ex:
        logging.error(f'Error fetching {recording.recording_id}: {ex}')
        return None

    try:
        sound = pydub.AudioSegment.from_file(io.BytesIO(data), 'mp3')
    except Exception as ex: # pylint: disable=broad-except
        # These errors can get extremely long.
        logging.error(f'Failed to decode audio file for {recording.url} '
                      f'(cache file {_fetcher.cache_file_name(recording.audio_url)}): {str(ex)[:5000]}')
        return None

    # pydub does everything in milliseconds, and so do we, unless otherwise
    # specified.
    sound = sound[:1000 * _AUDIO_SCAN_DURATION]
    sound = sound.set_channels(1)
    sound = sound.set_frame_rate(_AUDIO_SAMPLE_RATE)

    min_duration = round(1000 * _MIN_AUDIO_DURATION)
    max_duration = round(1000 * _MAX_AUDIO_DURATION)
    padding_duration = round(1000 * _AUDIO_PADDING_DURATION)
    fade_duration = round(1000 * _AUDIO_FADE_DURATION)

    # Find longest utterance, the end of which is a good place to cut off the
    # sample.
    utterances = list(detect_utterances(
        sound, recording.recording_id, debug_otsu_threshold=debug_otsu_threshold))
    # This should not happen, because the threshold is such that there is
    # always something above it.
    assert utterances, f'No utterances detected in {recording.url}'

    # Exhaustively search all possible ranges of consecutive utterances that we
    # want to include, and score them by desirability.
    candidates = []
    # We try to start only from the first three utterances, because recordists
    # tend to trim the audio such that it starts on a relevant bit. This seems
    # to help to avoid including (unlabelled) background species and other
    # noise.
    for i, start_utterance in enumerate(utterances[:3]):
        start_ms = max(0, start_utterance[0] - padding_duration)
        utterance_duration = 0
        for end_utterance in utterances[i:]:
            utterance_duration += end_utterance[1] - end_utterance[0]
            end_ms = min(len(sound), end_utterance[1] + padding_duration)
            total_duration = end_ms - start_ms
            # First criterion: it must be long enough. More negative is more bad.
            longness_score = min(0.0, total_duration - min_duration)
            # Second criterion: it must not be too long. More negative is more bad.
            shortness_score = min(0.0, max_duration - total_duration)
            # Third criterion: it must have a good utterance to silence ratio.
            utterance_score = utterance_duration / total_duration
            score_vector = (longness_score, shortness_score, utterance_score)
            candidates.append((score_vector, (start_ms, end_ms)))
    _, (start_ms, end_ms) = max(candidates)
    duration_ms = end_ms - start_ms
    # Never go above the maximum duration.
    if duration_ms > max_duration:
        end_ms = start_ms + max_duration
    # Never go below the minimum duration.
    if duration_ms < min_duration:
        # Try adding half of the missing duration before and half after.
        margin_ms = (min_duration - duration_ms + 1) // 2
        start_ms -= margin_ms
        end_ms += margin_ms
        if start_ms < 0:
            # Running up to the start of the sound.
            start_ms = 0
            end_ms = min(len(sound), start_ms + min_duration)
        if end_ms > len(sound):
            # Running up to the end of the sound.
            end_ms = len(sound)
            start_ms = max(0, end_ms - min_duration)

    sound = sound[start_ms:end_ms]
    sound = sound.fade_in(fade_duration).fade_out(fade_duration)
    sound = pydub.effects.normalize(sound)

    if debug_utterances:
        import subprocess # pylint: disable=import-outside-toplevel
        import tempfile # pylint: disable=import-outside-toplevel
        from PIL import Image, ImageDraw # pylint: disable=import-outside-toplevel
        sonogram_data = _fetcher.fetch_cached(recording.sonogram_url_full)
        sonogram = Image.open(io.BytesIO(sonogram_data))
        draw = ImageDraw.Draw(sonogram, mode='RGBA')
        def highlight(start_ms, end_ms, color):
            # Fixed parameters for full sonograms drawn by xeno-canto.
            # Visual left margin is at 62px, but it seems the audio starts
            # 4px later.
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
            subprocess.run(['eog', f.name], check=False)

    if skip_write:
        return None

    tmp_file_name = output_file_name + '.tmp'
    sound.export(tmp_file_name, format='ogg', parameters=['-q:a', str(_AUDIO_QUALITY)])
    os.rename(tmp_file_name, output_file_name)

    return output_file_name


def otsu_threshold(array, recording_id, debug=False):
    '''
    Computes a binary classification threshold for the given array using Otsu's
    method:
    https://en.wikipedia.org/wiki/Otsu%27s_method
    '''
    num_bins = 256
    hist, bin_edges = np.histogram(array, bins=num_bins)
    hist = hist.astype(np.float32) / hist.sum()

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
    if debug:
        import matplotlib.pyplot as plt # pylint: disable=import-outside-toplevel
        logging.info(f'Histogram from {bin_edges[0]} to {bin_edges[-1]}, Otsu threshold at {threshold}')
        fig, ax1 = plt.subplots()
        ax1.hist(bin_edges[:-1], bin_edges, weights=hist, color=(0.1, 0.2, 1.0))
        ax1.set(title=recording_id)
        ax2 = ax1.twinx()
        ax2.plot(bin_edges[:-1], qualities, color=(1.0, 0.2, 0.1))
        ax2.axvline(x=threshold, color=(0.1, 1.0, 0.2))
        ax2.text(x=threshold, y=best_quality, s=str(best_quality))
        plt.show()
    return threshold


def detect_utterances(sound, recording_id, debug_otsu_threshold=False):
    '''
    Classifies each millisecond of audio as either "utterance" or "silence"
    based on whether loudness is above the Otsu threshold. Returns runs of
    consecutive utterance as a list of (start_ms, end_ms) tuples.

    Sequences of silence shorter than a given threshold are considered part of
    the utterance and do not start a new one.
    '''
    # RMS is easier to work with because it doesn't contain -inf, but dBFS
    # gives a much clearer histogram in practice.
    loudnesses = np.array([ms.dBFS for ms in sound])
    loudnesses[loudnesses == -np.inf] = -90
    utterance_threshold = otsu_threshold(loudnesses, recording_id, debug=debug_otsu_threshold)

    min_gap_ms = round(1000 * _MIN_UTTERANCE_GAP)

    utterances = []
    utterance_start = None
    silence_ms = None
    ms = None
    for ms, loudness in enumerate(loudnesses):
        if loudness >= utterance_threshold:
            if utterance_start is None:
                utterance_start = ms
            silence_ms = 0
        else:
            if utterance_start is not None:
                if silence_ms >= min_gap_ms:
                    utterances.append((utterance_start, ms - silence_ms))
                    utterance_start = None
                    silence_ms = None
                else:
                    silence_ms += 1

    if utterance_start is not None:
        # Final utterance ran right up to the end of the sound.
        utterances.append((utterance_start, ms - silence_ms))

    return utterances


# Hack for lameness of multiprocessing.Pool.imap
def _process_recording(args_kwargs):
    trim_recording(*args_kwargs[0], **args_kwargs[1])


def add_args(parser):
    parser.add_argument(
        '--retrim_recordings', action='store_true',
        help='Overwrite files instead of assuming they are up to date')
    parser.add_argument(
        '--trim_recordings_process_jobs', type=int, default=8,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')
    parser.add_argument(
        '--debug_recording_ids', type=str, default=None,
        help='Process only the given recording IDs (comma separated), do not store results, and show debug windows')
    parser.add_argument(
        '--debug_otsu_threshold', action='store_true',
        help='Show debug rendering of Otsu thresholding')
    parser.add_argument(
        '--debug_utterances', action='store_true',
        help='Show debug rendering of utterance detection')


def main(args, session):
    if args.debug_recording_ids:
        logging.info('Loading specified recordings')
        recording_ids = args.debug_recording_ids.split(',')
        recordings = session.query(Recording)\
            .filter(Recording.recording_id.in_(recording_ids))\
            .all()
        for recording in recordings:
            logging.info(f'Processing recording {recording.recording_id}')
            trim_recording(recording,
                           skip_if_exists=False,
                           skip_write=True,
                           debug_otsu_threshold=args.debug_otsu_threshold,
                           debug_utterances=args.debug_utterances)
        return

    logging.info('Loading selected recordings')
    selected_recordings = session.query(Recording).join(SelectedRecording).all()

    logging.info('Fetching and trimming recordings')
    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.trim_recordings_process_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)
        for _output_file_name in progress.percent(
                pool.imap(
                    _process_recording, [
                        ([selected_recording], {'skip_if_exists': not args.retrim_recordings})
                        for selected_recording in selected_recordings
                    ]),
                len(selected_recordings)):
            pass
