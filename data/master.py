#!/usr/bin/env python3

'''
The control script to create and update the master database, master.db. The
process consists of several stages, which can be invoked individually using
subcommands.

One or more stage names must be given on the command line, indicating which
stages to run. They will always be run in the correct order, regardless of the
order given on the command line.
'''

import argparse
import datetime
import importlib
import logging
import sys
import time

from sqlalchemy.exc import InvalidRequestError

import db


# To add a new stage `foo`:
# - create a new module called `foo.py`
# - add a `main(args, session)` function
# - optionally, add an `add_args(parser)` function
# - add `foo` to the list below in the right place
_STAGES = [
    'load_species',
    'load_recordings',
    'create_regions',
    'regions_to_gpkg',
    'select_recordings',
    'fetch_audio_files',
]
_STAGE_MODULES = {stage: importlib.import_module(stage) for stage in _STAGES}


def _main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--log_level', default='info', choices=['debug', 'info', 'warning', 'error', 'critical'],
        help='Verbosity of logging')
    for stage, module in _STAGE_MODULES.items():
        parser.add_argument(stage, action='store_true', help=module.__doc__)
    for module in _STAGE_MODULES.values():
        add_args = getattr(module, 'add_args', None)
        if add_args:
            add_args(parser)

    args = parser.parse_args()

    log_level = getattr(logging, args.log_level.upper())
    logging.basicConfig(level=log_level)
    # urllib3 gets rather spammy at INFO level, reporting every redirect made.
    logging.getLogger('urllib3.poolmanager').setLevel(level=max(log_level, logging.WARNING))

    session = db.create_session()

    for stage, module in _STAGE_MODULES.items():
        if getattr(args, stage):
            logging.info(f'Starting stage {stage}')
            start_time = time.now()

            getattr(module, 'main')(args, session)
            logging.info('Committing transaction')
            try:
                session.commit()
            except InvalidRequestError:
                logging.info('Transaction is empty, nothing to commit')
                pass

            elapsed = datetime.timeinterval(seconds=time.now() - start_time)
            logging.info(f'Finished stage {stage} in {elapsed}')


if __name__ == '__main__':
    sys.exit(_main())
