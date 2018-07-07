#!/usr/bin/env python3

import logging
import re
import sys

from ioc import ioc
from xenocanto import xenocanto


def main():
    logging.basicConfig(level=logging.INFO)

    ioc_list = ioc.IOCList()

    queries = sys.stdin

    first = True
    for line in queries:
        query = re.sub(r'#.*', '', line).strip()
        if not query:
            continue

        recordings = xenocanto.find_recordings_cached(query)
        if not recordings:
            species = ioc_list.find_by_name(query)
            if species:
                alt_names = set(name for name in species.alt_names if name != query)
                found_names = set()
                for alt_name in alt_names:
                    if alt_name == query:
                        continue
                    recordings = xenocanto.find_recordings_cached(alt_name)
                    if recordings:
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
