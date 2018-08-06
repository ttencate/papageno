#!/usr/bin/env python3

'''
Selects the top best recordings for each species. Reads species names from
stdin. Prints JSON for each recording to stdout.
'''

import json
import logging
import sys

from xenocanto import xenocanto
from xenocanto.readers import strip_comments_and_blank_lines


def _quality(metadata):
    quality = 100.0

    allowed_licenses = ['by-nc-nd', 'by-nc-sa', 'by-sa'] # All of them for now.
    if not any('/%s/' % license in metadata['lic'] for license in allowed_licenses):
        return -1

    quality *= {
        'A': 1.0,
        'B': 0.7,
        'C': 0.3,
        'D': 0.1,
        'E': 0.0,
    }.get(metadata['q'], 0.0)

    quality *= 1.0 / len(metadata['type'].split(','))

    if not 'call' in metadata['type'] and not 'song' in metadata['type']:
        quality *= 0.3

    length = metadata['length_s']
    min_length = 3
    min_optimal_length = 8
    max_optimal_length = 13
    max_length = 20
    if length < min_length:
        quality *= 0.0
    elif length < min_optimal_length:
        quality *= (length - min_length) / (min_optimal_length - min_length)
    elif length < max_optimal_length:
        quality *= 1.0
    elif length < max_length:
        quality *= (max_length - length) / (max_length  - max_optimal_length)
    else:
        quality *= 0.0

    return quality


def _main():
    logging.basicConfig(level=logging.INFO)

    for query in strip_comments_and_blank_lines(sys.stdin):
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

        metadatas.sort(key=_quality, reverse=True)
        picks = metadatas[:10]
        worst_quality = _quality(picks[-1])
        if worst_quality <= 10.0:
            logging.warning('Quality for %s goes down to %f', query, worst_quality)
        logging.info('Quality for %s goes down to %f', query, worst_quality)

        for pick in picks:
            print(json.dumps(pick, indent=2))
            print(xenocanto.download_recording_cached(pick['id'], pick['file']))

        print()

if __name__ == '__main__':
    _main()
