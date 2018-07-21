#!/usr/bin/env python3

import logging
import re
import sys

from xenocanto import xenocanto


def main():
    logging.basicConfig(level=logging.INFO)

    queries = sys.stdin

    first = True
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
    main()
