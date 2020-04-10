#!/usr/bin/env python3

'''
Fetches metadata for all recordings from the XenoCanto website
(https://xeno-canto.org/) through its API
(https://www.xeno-canto.org/explore/api).
'''

import argparse
import itertools
import json
import logging
import os.path
import multiprocessing.pool
import sys

import diskcache
import tenacity
import urllib3

from recordings import Recording, RecordingsList


class XcQuery:
    '''
    Wrapper around the XenoCanto API.
    '''

    def __init__(self, parts, pool_size, clear_cache=False):
        self._cache = diskcache.Index(os.path.join(os.path.dirname(__file__), 'cache', 'xc_api'))
        if clear_cache:
            self._cache.clear()
        self._http = urllib3.PoolManager(num_pools=1,
                                         maxsize=pool_size,
                                         timeout=urllib3.util.Timeout(total=300))
        self._query = '%20'.join(f'{k}:{v}' for k, v in parts.items())

    # Note that we even retry 400 errors (i.e. client side). These spuriously
    # happen, perhaps due to a bug in the API.
    @tenacity.retry(stop=tenacity.stop_after_attempt(5))
    def fetch_page(self, page_number):
        '''
        Fetches the given page (1-based) and returns the parsed JSON.
        '''
        url = f'https://www.xeno-canto.org/api/2/recordings?query={self._query}&page={page_number}'
        if url in self._cache:
            logging.info(f'Returning {url} from cache')
            return self._cache[url]
        logging.info(f'Fetching {url}')
        response = self._http.request('GET', url)
        if response.status != 200:
            raise RuntimeError(f'URL {url} returned status code {response.status} '
                               f'and said:\n{response.data}')
        parsed_response = json.loads(response.data)
        # Sanity check so we can retry before returning if needed.
        if 'recordings' not in parsed_response:
            raise RuntimeError(f'URL {url} returned JSON without "recordings":\n{response.data}')
        self._cache[url] = parsed_response
        return parsed_response


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--recordings_file', default=RecordingsList.DEFAULT_FILE_NAME,
        help='CSV file in which to store the resulting recordings')
    parser.add_argument(
        '--start_id', type=int, default=1,
        help='First id to fetch')
    parser.add_argument(
        '--end_id', type=int, default=999999999,
        help='Last id to fetch (inclusive)')
    parser.add_argument(
        '--clear_cache', action='store_true',
        help='Wipe the response cache and start from scratch')
    parser.add_argument(
        '--jobs', '-j', type=int, default=10,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')
    args = parser.parse_args()

    query = XcQuery({'nr': f'{args.start_id}-{args.end_id}'},
                    pool_size=args.jobs,
                    clear_cache=args.clear_cache)
    first_page = query.fetch_page(1)
    num_pages = first_page['numPages']
    num_recordings = int(first_page['numRecordings'])
    logging.info(f'Found {num_pages} pages, {num_recordings} recordings')
    pages_fetched = 0
    recordings_list = RecordingsList()
    with multiprocessing.pool.ThreadPool(args.jobs) as pool:
        for page in itertools.chain(
                [first_page],
                pool.imap(query.fetch_page, range(2, num_pages + 1))):
            try:
                for recording_json in page['recordings']:
                    recording = Recording.from_xc_json(recording_json)
                    # Allow replacements in case the API shifts pages around
                    # (it seems to do that, probably when new recordings are
                    # added during the run).
                    recordings_list.add_recording(recording, allow_replace=True)
                pages_fetched += 1
                logging.info(f'Fetched {pages_fetched}/{num_pages} pages, '
                             f'parsed {len(recordings_list)}/{num_recordings} recordings '
                             f'({pages_fetched / num_pages * 100:.1f}%)')
            except Exception:
                logging.error(f'Error parsing page:\n{json.dumps(page, indent="  ")}',
                              exc_info=True)
                raise

    recordings_list.save(args.recordings_file)


if __name__ == '__main__':
    sys.exit(_main())
