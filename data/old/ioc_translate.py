#!/usr/bin/env python3

'''
Translates species names to a given language. First command line argument is
the target language, which must match one of the column headers in the IOC
translations spreadsheet. Reads names from stdin.
'''

import logging
import sys

from ioc import ioc
from xenocanto.readers import strip_comments_and_blank_lines


def _main():
    logging.basicConfig(level=logging.INFO)

    language = 'Dutch'
    if len(sys.argv) >= 2:
        language = sys.argv[1]

    ioc_list = ioc.IOCList()
    for name in strip_comments_and_blank_lines(sys.stdin):
        species = ioc_list.find_by_name(name)
        if not species:
            logging.warning('Could not find "%s", skipping. Did you mean one of:\n%s',
                            name, ', '.join(ioc_list.find_close_matches(name)))
            continue

        print(species.translations.get(language, None) or ('[%s]' % name))


if __name__ == '__main__':
    _main()
