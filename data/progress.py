'''
Functions for reporting progress.
'''

import datetime
import sys
import time


def percent(iterable, length=None):
    '''
    A generator wrapper that prints progress in %. If the iterable has no
    __len__ function, converts it into a list first.
    '''
    if length is None:
        try:
            length = len(iterable)
        except TypeError:
            iterable = list(iterable)
            length = len(iterable)
    last_update = 0
    start_time = time.monotonic()
    prev_pct = None
    output_length = 0
    for index, item in enumerate(iterable):
        yield item
        pct = (index + 1) * 1000 // length / 10
        now = time.monotonic()
        if now - last_update > 0.1:
            elapsed_time = datetime.timedelta(seconds=now - start_time)
            total_time = elapsed_time / (index + 1) * length
            remaining_time = total_time - elapsed_time
            prev_pct = pct
            output = f' {index}/{length}   {pct:.1f}%    {elapsed_time}/{total_time}    (ETA {remaining_time})'
            sys.stderr.write(output + (' ' * (output_length - len(output))) + '\r')
            sys.stderr.flush()
            output_length = len(output)
            last_update = now
    sys.stderr.write((' ' * output_length) + '\r')
    sys.stderr.flush()
