#!/usr/bin/env python3

'''
Fetches metadata for all recordings from the XenoCanto website
(https://xeno-canto.org/) through its API
(https://www.xeno-canto.org/explore/api).
'''

import argparse
import csv
import json
import logging
import multiprocessing.pool
import os.path
import sys

import urllib3


_FIELD_NAMES = [
    'id', 'gen', 'sp', 'ssp', 'en', 'rec', 'cnt', 'loc', 'lat', 'lng', 'alt', 'type', 'url', 'file',
    'file-name', 'sono-small', 'sono-med', 'sono-large', 'sono-full', 'lic', 'q', 'length', 'time',
    'date', 'uploaded', 'also', 'rmk', 'bird-seen', 'playback-used',
]


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--xc_db_file', default=os.path.join(os.path.dirname(__file__), 'sources', 'xc.csv'),
        help='CSV file in which to store the resulting data')
    parser.add_argument(
        '--overwrite_data', action='store_true',
        help='Scrape and update even those ids that are already present in the database')
    parser.add_argument(
        '--start_id', type=int, default=1,
        help='First id to try scraping')
    parser.add_argument(
        '--end_id', type=int, default=1000000,
        help='Id before which to stop scraping')
    parser.add_argument(
        '--jobs', '-j', type=int, default=10,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')
    args = parser.parse_args()

    query = XcQuery({'since': '1980-01-01'}, pool_size=args.jobs)
    first_page = query.fetch_page(1)
    num_pages = first_page['numPages']
    num_recordings = int(first_page['numRecordings'])
    logging.info(f'Found {num_pages} pages, {num_recordings} recordings')
    pages_fetched = 0
    recordings_written = 0
    with open(args.xc_db_file, 'wt') as xc_db_file:
        writer = csv.DictWriter(xc_db_file, fieldnames=_FIELD_NAMES)
        writer.writeheader()
        with multiprocessing.pool.ThreadPool(args.jobs) as pool:
            for page in pool.imap(query.fetch_page, range(1, num_pages + 1)):
                for recording in page['recordings']:
                    # Massage the recording to flatten string and list fields.
                    for sono_size, sono_url in recording['sono'].items():
                        recording['sono-' + sono_size] = sono_url
                    recording.pop('sono')
                    recording['also'] = ';'.join(recording['also'])
                    writer.writerow(recording)
                    recordings_written += 1
                pages_fetched += 1
                logging.info(f'Fetched {pages_fetched}/{num_pages} pages, '
                             f'wrote {recordings_written}/{num_recordings} recordings '
                             f'({pages_fetched / num_pages * 100:.1f}%)')
    logging.info('Done')


class XcQuery:
    '''
    Wrapper around the XenoCanto API.
    '''

    def __init__(self, parts, pool_size):
        self._http = urllib3.PoolManager(num_pools=1, maxsize=pool_size)
        self._query = '%20'.join(f'{k}:{v}' for k, v in parts.items())

    def fetch_page(self, page_number):
        '''
        Fetches the given page (1-based) and returns the parsed JSON.
        '''
        url = f'https://www.xeno-canto.org/api/2/recordings?query={self._query}&page={page_number}'
        logging.info(f'Fetching {url}')
        response = self._http.request('GET', url)
        return json.loads(response.data)


if __name__ == '__main__':
    sys.exit(_main())
