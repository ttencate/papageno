'''
Fetches all selected recordings from xeno-canto. Any permanent errors should be
manually added to `recordings_blacklist.txt` and then `select_recordings`
should be re-run to select alternative recordings or drop that species
altogether.
'''

import logging
import multiprocessing.pool
import os.path
import signal

import urllib3

import fetcher
import progress
from recordings import Recording, SelectedRecording


_fetcher = None


def _process_recording(recording):
    '''
    Entry point for parallel processing.
    '''

    global _fetcher
    if not _fetcher:
        _fetcher = fetcher.Fetcher('audio_files', pool_size=1)

    output_file_name = f'{recording.recording_id}.ogg'
    full_output_file_name = os.path.join(_args.audio_file_output_dir, output_file_name)
    if os.path.exists(full_output_file_name) and not _args.recreate_images:
        return

    try:
        data = _fetcher.fetch_cached(recording.audio_url)
    except fetcher.FetchError as ex:
        logging.error(f'Error fetching {recording.recording_id}: {ex}')
        return

    # TODO trim and write as OGG


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
