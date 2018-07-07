#!/usr/bin/env python3

import argparse
import json
import logging
import re
import urllib.parse
import sys

import requests

from ioc import ioc
from xenocanto import xenocanto


def main():
    ioc_list = ioc.IOCList()

    queries = sys.stdin

    first = True
    for line in queries:
        query = re.sub(r'#.*', '', line).strip()
        if not query:
            continue

        json = xenocanto.find_cached_recordings(query)
        if not json['recordings']:
            species = ioc_list.find_by_name(query)
            if species:
                alt_names = set(name for name in species.alt_names if name != query)
                found_names = set()
                for alt_name in alt_names:
                    if alt_name == query:
                        continue
                    json = xenocanto.find_cached_recordings(alt_name)
                    if json['recordings']:
                        found_names.add(alt_name)
                if found_names:
                    logging.warning('No results for query "%s", but results exist for %s',
                            query,
                            ', '.join("%s" % name for name in found_names))
                else:
                    logging.warning('No results for query "%s", nor for synonyms %s',
                            query,
                            ', '.join("%s" % name for name in alt_names))
            else:
                logging.warning('No results for query "%s", and no synonyms found in IOC list', query)
                continue


if __name__ == '__main__':
    main()
