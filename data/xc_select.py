#!/usr/bin/env python3

import json
import logging
import re
import sys

from xenocanto import xenocanto


def quality(metadata):
    q = 100.0

    allowed_licenses = ['by-nc-nd', 'by-nc-sa', 'by-sa'] # All of them for now.
    if not any('/%s/' % license in metadata['lic'] for license in allowed_licenses):
        return -1

    q *= {
        'A': 1.0,
        'B': 0.7,
        'C': 0.3,
        'D': 0.1,
        'E': 0.0,
    }.get(metadata['q'], 0.0)

    q *= 1.0 / len(metadata['type'].split(','))

    if not 'call' in metadata['type'] and not 'song' in metadata['type']:
        q *= 0.3

    length = metadata['length_s']
    min_length = 3
    min_optimal_length = 8
    max_optimal_length = 13
    max_length = 20
    if length < min_length:
        q *= 0.0
    elif length < min_optimal_length:
        q *= (length - min_length) / (min_optimal_length - min_length)
    elif length < max_optimal_length:
        q *= 1.0
    elif length < max_length:
        q *= (max_length - length) / (max_length  - max_optimal_length)
    else:
        q *= 0.0

    return q


def main():
    logging.basicConfig(level=logging.INFO)

    queries = sys.stdin

    first = True
    for line in queries:
        query = re.sub(r'#.*', '', line).strip()
        if not query:
            continue

        print(query)
        print()

        recordings = xenocanto.find_recordings_cached(query)
        metadatas = []
        for recording in recordings:
            try:
                metadata = xenocanto.fetch_metadata_cached(recording['id'])
            except RuntimeError as ex:
                logging.warning(ex)
                continue
            metadatas.append(metadata)

        metadatas.sort(key=quality, reverse=True)
        picks = metadatas[:10]
        if quality(picks[-1]) <= 10.0:
            logging.warning('Quality for %s goes down to %f', quality(picks[-1]))
        logging.info('Quality for %s goes down to %f', query, quality(picks[-1]))

        for pick in picks:
            print(json.dumps(pick, indent=2))
            print(xenocanto.download_recording_cached(pick))

        print()

if __name__ == '__main__':
    main()
