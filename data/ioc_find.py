#!/usr/bin/env python3

import difflib
import re
import sys

from ioc import ioc


def main():
    ioc_list = ioc.IOCList()
    for line in sys.stdin:
        name = re.sub(r'#.*', '', line).strip()
        if not name:
            continue
        species = ioc_list.find_by_name(name)
        suggested_names = None
        if not species:
            logging.warning('Could not find "%s", did you mean one of:\n%s',
                    name,
                    ', '.join(difflib.get_close_matches(name, ioc.by_name.keys())))
        char = ' '
        if not species:
            char = 'X'
        elif name != species.ioc_name:
            char = 'C'
        print('{found}{changed} {name} -> {species}'.format(
            found=' ' if species else 'X',
            changed=' ' if not species or name == species.ioc_name else 'C',
            name=name,
            species=species))


if __name__ == '__main__':
    main()
