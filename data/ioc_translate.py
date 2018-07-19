#!/usr/bin/env python3

import difflib
import logging
import re
import sys

from ioc import ioc


def main():
    logging.basicConfig(level=logging.INFO)

    language = 'Dutch'
    if len(sys.argv) >= 2:
        language = sys.argv[1]

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
            continue

        print(species.translations.get(language, None) or ('[%s]' % name))


if __name__ == '__main__':
    main()
