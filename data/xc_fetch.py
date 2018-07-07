#!/usr/bin/env python3

import argparse
import collections
import json
import logging
import re
import traceback
import urllib.parse
import sys

import requests

from xenocanto import xenocanto


def main():
    queries = sys.stdin
    output = sys.stdout

    output.write('[')
    first = True
    for line in queries:
        query = re.sub(r'#.*', '', line).strip()
        if not query:
            continue
        logging.info('Querying "%s"...', query)
        count = 0
        for recording in xenocanto.get_recordings(query):
            count += 1
            if not first:
                output.write(',')
            first = False
            output.write('\n')
            output.write(json.dumps(recording.json, indent=2))
        if count:
            logging.info('Fetched %d recordings for "%s"', count, query)
        else:
            logging.warning('No results for query "%s"', query)
    output.write(']\n')


if __name__ == '__main__':
    main()
