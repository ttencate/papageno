'''
Functions for reporting progress.
'''

import datetime
import sys
import time


def percent(iterable, message_format='{}'):
    '''
    A generator wrapper that prints progress in %.
    '''
    try:
        total = len(iterable)
    except TypeError:
        iterable = list(iterable)
        total = len(iterable)
    start_time = time.monotonic()
    prev_pct = None
    output_length = 0
    for index, item in enumerate(iterable):
        yield item
        pct = (index + 1) * 1000 // total / 10
        if pct != prev_pct:
            elapsed_time = datetime.timedelta(seconds=time.monotonic() - start_time)
            total_time = elapsed_time / (index + 1) * total
            remaining_time = total_time - elapsed_time
            prev_pct = pct
            output = f' {pct: 5.1f}%    {elapsed_time}/{total_time}    (ETA {remaining_time})'
            sys.stderr.write(output + (' ' * (output_length - len(output))) + '\r')
            sys.stderr.flush()
            output_length = len(output)
    sys.stderr.write((' ' * output_length) + '\r')
    sys.stderr.flush()
