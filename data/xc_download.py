#!/usr/bin/env python3

import hashlib
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

        recordings.sort(key=lambda recording: (recording['q'], md5(recording['id'])))

        downloaded = 0
        for recording in recordings:
            try:
                file_name = xenocanto.download_recording_cached(recording)
                downloaded += 1
            except Exception as ex:
                logging.error('Error downloading recording %s' % recording['id'], exc_info=True)
                continue
            if downloaded == 10:
                break


if __name__ == '__main__':
    main()

