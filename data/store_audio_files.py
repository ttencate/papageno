'''
Fetches all selected recordings from xeno-canto. Any permanent errors should be
manually added to `recordings_blacklist.txt` and then `select_recordings`
should be re-run to select alternative recordings or drop that species
altogether.
'''

import io
import logging
import multiprocessing.pool
import os.path
import signal

import numpy as np
import pydub
import pydub.effects

import fetcher
import progress
from recordings import Recording, SelectedRecording


_fetcher = None


def _detect_utterances(sound, percentile=20):
    # Not using dBFS because it can be -inf, but we're using a percentile for
    # cutoff so it doesn't matter.
    loudnesses = np.array([ms.rms for ms in sound])
    utterance_threshold = np.percentile(loudnesses, percentile)
    utterance_start = None
    for ms, loudness in enumerate(loudnesses):
        if loudness >= utterance_threshold:
            if utterance_start is None:
                utterance_start = ms
        else:
            if utterance_start is not None:
                yield (utterance_start, ms)
                utterance_start = None
    if utterance_start is not None:
        yield (utterance_start, ms)


def _process_recording(recording):
    '''
    Entry point for parallel processing.
    '''

    global _fetcher
    if not _fetcher:
        _fetcher = fetcher.Fetcher('audio_files', pool_size=1)

    output_file_name = f'{recording.recording_id}.ogg'
    full_output_file_name = os.path.join(_args.audio_file_output_dir, output_file_name)
    if os.path.exists(full_output_file_name) and not _args.recreate_audio_files:
        return

    try:
        data = _fetcher.fetch_cached(recording.audio_url)
    except fetcher.FetchError as ex:
        logging.error(f'Error fetching {recording.recording_id}: {ex}')
        return

    sound = pydub.AudioSegment.from_file(io.BytesIO(data), 'mp3')

    # pydub does everything in milliseconds.
    sound = sound[:1000 * _args.max_audio_duration]
    sound = sound.set_channels(1)

    fade_duration = round(1000 * _args.audio_fade_duration)

    # Find longest utterance, the end of which is a good place to cut off the
    # sample.
    utterances = list(_detect_utterances(sound))
    if not utterances:
        raise RuntimeError(f'No utterances detected in {recording.url}')
    _, longest_utterance_end = max(utterances, key=lambda start_end: start_end[1] - start_end[0])
    output_duration = max(round(1000 * _args.min_audio_duration), longest_utterance_end + 3 * fade_duration)
    sound = sound[:output_duration]

    sound = sound.fade_in(fade_duration).fade_out(fade_duration)
    sound = pydub.effects.normalize(sound)

    sound = sound.set_frame_rate(_args.audio_sample_rate)
    try:
        sound.export(full_output_file_name, format='ogg', parameters=['-q:a', str(_args.audio_quality)])
    except:
        os.remove(full_output_file_name)
        raise


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
        '--min_audio_duration', type=float, default=5.0,
        help='Minimum duration in seconds of exported audio clips')
    parser.add_argument(
        '--max_audio_duration', type=float, default=12.0,
        help='Maximum duration in seconds of exported audio clips')
    parser.add_argument(
        '--audio_fade_duration', type=float, default=0.05,
        help='Duration in seconds of fade in/out')
    parser.add_argument(
        '--audio_sample_rate', type=int, default=44100,
        help='Sample rate in Hz of output audio')
    parser.add_argument(
        '--audio_quality', type=float, default=2.0,
        help='OGG/Vorbis quality level of output audio between -1.0 and 10.0')


_args = None


def main(args, session):
    global _args
    _args = args

    logging.info('Loading selected recordings')
    selected_recordings = session.query(Recording).join(SelectedRecording).all()

    def file_name(recording):
        return os.path.join(args.output_dir, recording.recording_id + '.mp3')

    logging.info('Fetching and processing audio files')
    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.image_process_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)
        for _ in progress.percent(
                pool.imap(_process_recording, selected_recordings),
                len(selected_recordings)):
            pass
