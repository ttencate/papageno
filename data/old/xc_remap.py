#!/usr/bin/env python3

'''
Maps IOC species names to alternative names that result in hits on Xenocanto.
Reads names from stdin, prints matched names on stdout.
'''

import logging
import sys

from ioc import ioc
from xenocanto import xenocanto
from xenocanto.readers import strip_comments_and_blank_lines


def _main():
    logging.basicConfig(level=logging.INFO)

    ioc_list = ioc.IOCList()

    for query in strip_comments_and_blank_lines(sys.stdin):
        recordings = xenocanto.find_recordings_cached(query)
        if recordings:
            print(query)
        else:
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
                if not found_names:
                    logging.error('No results for query "%s", nor for synonyms %s',
                                  query,
                                  ', '.join("%s" % name for name in alt_names))
                else:
                    logging.info('No results for query "%s", but results exist for %s',
                                 query,
                                 ', '.join("%s" % name for name in found_names))
                    for name in sorted(found_names):
                        print(name)
            else:
                logging.error('No results for query "%s", and no synonyms found in IOC list', query)
                continue


if __name__ == '__main__':
    _main()
