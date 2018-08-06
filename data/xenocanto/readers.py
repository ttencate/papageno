'''
Utilities for reading files.
'''

import re


_COMMENT_RE = re.compile(r'#.*')


def strip_comments_and_blank_lines(file_obj):
    '''
    Strips comments (starting with #), as well as leading and trailing blanks,
    and yields all nonblank lines.
    '''
    for line in file_obj:
        line = _COMMENT_RE.sub('', line).strip()
        if not line:
            continue
        return line
