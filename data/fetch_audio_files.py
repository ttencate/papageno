#!/usr/bin/env python3

'''
Fetches and stores audio files for selected recordings.
'''

import argparse
import logging
import multiprocessing.pool
import os.path
import sys

import urllib3

import db
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
            data = response.data
            if response.status != 200:
                raise RuntimeError(f'Got status {response.status}')
                data = None
        except:
            logging.error(f'Fetch failed for recording {recording.recording_id}, URL {url}', exc_info=True)
        return recording, data


def _main():
    logging.basicConfig(level=logging.INFO)
    logging.getLogger('urllib3.poolmanager').setLevel(level=logging.WARNING)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--output_dir', default=os.path.join(os.path.dirname(__file__), 'cache', 'audio_files'),
        help='Directory to write output files to')
    parser.add_argument(
        '--replace_existing', action='store_true',
        help='Re-fetch and overwrite files instead of assuming they are up to date')
    parser.add_argument(
        '--jobs', '-j', type=int, default=10,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')
    args = parser.parse_args()

    session = db.create_session()

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
    fetcher = _Fetcher(pool_size=args.jobs)
    with multiprocessing.pool.ThreadPool(args.jobs) as pool:
        for recording, data in progress.percent(
                pool.imap(fetcher.fetch, recordings_to_fetch),
                len(recordings_to_fetch)):
            if not data:
                continue
            with open(file_name(recording), 'wb') as output_file:
                output_file.write(data)


if __name__ == '__main__':
    sys.exit(_main())
