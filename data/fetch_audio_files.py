'''
Fetches all selected recordings from xeno-canto. Any permanent errors should be
manually added to `recordings_blacklist.txt` and then `select_recordings`
should be re-run to select alternative recordings or drop that species
altogether.
'''

import logging
import multiprocessing.pool
import os.path

import urllib3

import progress
from recordings import Recording, SelectedRecording


class _Fetcher:

    def __init__(self, pool_size):
        self._http = urllib3.PoolManager(num_pools=1, maxsize=pool_size)

    def fetch(self, recording):
        url = recording.audio_url
        if not url:
            logging.error(f'Recording {recording.recording_id} has no URL')
            return recording, None
        data = None
        try:
            response = self._http.request('GET', url)
            if response.status != 200:
                raise RuntimeError(f'Got status {response.status}')
            data = response.data
        except: # pylint: disable=bare-except
            logging.error(f'Fetch failed for recording {recording.recording_id}, URL {url}', exc_info=True)
        return recording, data


def add_args(parser):
    parser.add_argument(
        '--output_dir', default=os.path.join(os.path.dirname(__file__), 'cache', 'audio_files'),
        help='Directory to write output files to')
    parser.add_argument(
        '--replace_existing', action='store_true',
        help='Re-fetch and overwrite files instead of assuming they are up to date')
    parser.add_argument(
        '--audio_fetch_jobs', type=int, default=10,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')


def main(args, session):
    logging.info('Loading selected recordings')
    selected_recordings = session.query(Recording).join(SelectedRecording).all()

    def file_name(recording):
        return os.path.join(args.output_dir, recording.recording_id + '.mp3')

    if not args.replace_existing:
        logging.info('Checking existing files')
        recordings_to_fetch = []
        for recording in progress.percent(selected_recordings):
            if not os.path.isfile(file_name(recording)):
                recordings_to_fetch.append(recording)
    else:
        recordings_to_fetch = selected_recordings

    logging.info('Fetching audio files')
    fetcher = _Fetcher(pool_size=args.audio_fetch_jobs)
    with multiprocessing.pool.ThreadPool(args.audio_fetch_jobs) as pool:
        for recording, data in progress.percent(
                pool.imap(fetcher.fetch, recordings_to_fetch),
                len(recordings_to_fetch)):
            if not data:
                continue
            with open(file_name(recording), 'wb') as output_file:
                output_file.write(data)
