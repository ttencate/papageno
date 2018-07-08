#!/usr/bin/env python3

import hashlib
import json
import logging
import os.path
import re
import sys

from xenocanto import xenocanto


def md5(string):
    m = hashlib.md5()
    m.update(bytes(string, 'utf8'))
    return m.digest()


def main():
    logging.basicConfig(level=logging.INFO)

    queries = sys.stdin

    first = True
    for line in queries:
        query = re.sub(r'#.*', '', line).strip()
        if not query:
            continue

        recordings = list(xenocanto.find_recordings_cached(query))
        if not recordings:
            logging.warning('No results for query "%s"', query)
            continue
        logging.info('Found %d recordings for query "%s"', len(recordings), query)

        for recording in recordings:
            try:
                metadata = xenocanto.fetch_metadata_cached(recording)
            except Exception as ex:
                logging.error('Error downloading recording %s' % recording['id'], exc_info=True)
                continue
            # print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()

