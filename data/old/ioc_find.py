#!/usr/bin/env python3

'''
Finds species names in the IOC list, and maps them to their canonical IOC
names. Reads names from stdin, one per line. Prints original and canonical
names, and translations.
'''

import logging
import sys

from ioc import ioc
from xenocanto.readers import strip_comments_and_blank_lines


def _main():
    logging.basicConfig(level=logging.INFO)

    ioc_list = ioc.IOCList()
    for name in strip_comments_and_blank_lines(sys.stdin):
        species = ioc_list.find_by_name(name)
        if not species:
            logging.warning('Could not find "%s", did you mean one of:\n%s',
                            name, ', '.join(ioc_list.find_close_matches(name)))

        print('{found}{changed} {name} -> {species}'.format(
            found=' ' if species else 'X',
            changed=' ' if not species or name == species.ioc_name else 'C',
            name=name,
            species=species or '?'))


if __name__ == '__main__':
    _main()
