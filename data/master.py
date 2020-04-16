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
import progress


# To add a new stage `foo`:
# - create a new module called `foo.py`
# - add a `main(args, session)` function
# - optionally, add an `add_args(parser)` function
# - add `foo` to the list below in the right place
_STAGES = [
    'load_species',
    'load_recordings',
    'load_images',
    'create_regions',
    'regions_to_gpkg',
    'select_species',
    'select_recordings',
    'web_ui',
    'store_audio_files',
    'store_images',
]
_STAGE_MODULES = {stage: importlib.import_module(stage) for stage in _STAGES}


def _main():
    parser = argparse.ArgumentParser(description=__doc__)

    common_args = parser.add_argument_group('common arguments')
    common_args.add_argument(
        '--log_level', default='info', choices=['debug', 'info', 'warning', 'error', 'critical'],
        help='Verbosity of logging')
    common_args.add_argument(
        '--no_progress', action='store_true',
        help='Disable progress reporting even if stderr is connected to a tty')

    stage_args = parser.add_argument_group('stage selection arguments')
    for stage, module in _STAGE_MODULES.items():
        stage_args.add_argument(f'--{stage}', action='store_true', help=module.__doc__)

    module_args = parser.add_argument_group('stage-specific configuration arguments')
    for module in _STAGE_MODULES.values():
        add_args = getattr(module, 'add_args', None)
        if add_args:
            add_args(module_args)

    args = parser.parse_args()

    log_level = getattr(logging, args.log_level.upper())
    logging.basicConfig(level=log_level)
    # urllib3 gets rather spammy at INFO level, reporting every redirect made.
    logging.getLogger('urllib3.poolmanager').setLevel(level=max(log_level, logging.WARNING))
    # PIL gets spammy at DEBUG level.
    logging.getLogger('PIL.Image').setLevel(level=max(log_level, logging.INFO))
    logging.getLogger('PIL.PngImagePlugin').setLevel(level=max(log_level, logging.INFO))

    if args.no_progress:
        progress.disable()

    session = db.create_session()

    for stage, module in _STAGE_MODULES.items():
        if getattr(args, stage):
            logging.info(f'Starting stage {stage}')
            start_time = time.monotonic()

            getattr(module, 'main')(args, session)
            logging.info('Committing transaction')
            try:
                session.commit()
            except InvalidRequestError:
                logging.info('Transaction is empty, nothing to commit')

            elapsed = datetime.timedelta(seconds=time.monotonic() - start_time)
            logging.info(f'Finished stage {stage} in {elapsed}')


if __name__ == '__main__':
    sys.exit(_main())
