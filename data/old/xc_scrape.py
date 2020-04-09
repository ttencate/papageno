#!/usr/bin/env python3

'''
Scrapes and caches Xenocanto metadata. Reads queries from stdin. Prints JSON
metadata to stdout.
'''

import json
import logging
import sys

from xenocanto import xenocanto
from xenocanto.cache import DownloadError
from xenocanto.readers import strip_comments_and_blank_lines


def _main():
    logging.basicConfig(level=logging.INFO)

    for query in strip_comments_and_blank_lines(sys.stdin):
        recordings = list(xenocanto.find_recordings_cached(query))
        if not recordings:
            logging.warning('No results for query "%s"', query)
            continue
        logging.info('Found %d recordings for query "%s"', len(recordings), query)

        for recording in recordings:
            try:
                metadata = xenocanto.fetch_metadata_cached(recording['id'])
            except DownloadError:
                logging.error('Error downloading recording %s', recording['id'], exc_info=True)
                continue
            print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    _main()
