#!/usr/bin/env python3

'''
Executes search queries on Xenocanto. Reads queries from stdin, prints
recording IDs on stdout.
'''

import logging
import re
import sys

from xenocanto import xenocanto


def _main():
    logging.basicConfig(level=logging.INFO)

    queries = sys.stdin

    for line in queries:
        query = re.sub(r'#.*', '', line).strip()
        if not query:
            continue

        recordings = xenocanto.find_recordings_cached(query)
        if recordings:
            logging.info('Found %d recordings for "%s"', len(recordings), query)
        else:
            logging.warning('No recordings found for "%s"', query)

        for recording in recordings:
            print(recording['id'])


if __name__ == '__main__':
    _main()
