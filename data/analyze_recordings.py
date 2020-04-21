'''
Analyzes sound quality of all recordings of selected species.
'''

import hashlib
import logging
import os.path
import multiprocessing.pool
import signal

from sqlalchemy.orm import joinedload

import analysis
import fetcher
import progress
from recordings import Recording, SonogramAnalysis, SelectedRecording
from species import Species, SelectedSpecies


_sonogram_fetcher = None
def _analyze(recording):
    # We pass a tuple because SQLAlchemy objects are not fully process-safe.
    # They can be pickled and unpickled, but they won't be bound to a Session
    # anymore. This means they can't refresh their attributes, which is
    # something they try to do after a commit() from inside the main process.
    recording_id, sonogram_url_small = recording
    try:
        # Create one fetcher per process.
        global _sonogram_fetcher
        if not _sonogram_fetcher:
            _sonogram_fetcher = fetcher.Fetcher(cache_group='xc_sonograms_small', pool_size=1)

        sonogram = None
        try:
            sonogram = _sonogram_fetcher.fetch_cached(sonogram_url_small)
        except fetcher.FetchError as ex:
            if ex.is_not_found():
                logging.warning(f'Sonogram for recording {recording_id} was not found')
            else:
                raise ex

        sonogram_quality = -999999
        if sonogram:
            sonogram_quality = analysis.sonogram_quality(recording_id, sonogram)

        return (recording_id, sonogram_quality)
    except Exception as ex:
        # Re-raise as something that's guaranteed to be pickleable.
        logging.error('Exception during analysis', exc_info=True)
        raise RuntimeError(f'Exception during analysis: {ex}')


def add_args(parser):
    parser.add_argument(
        '--reanalyze_recordings', action='store_true',
        help='Delete all sonogram analyses before starting')
    parser.add_argument(
        '--analysis_jobs', type=int, default=8,
        help='Number of parallel sonogram analysis jobs to run')


def main(args, session):
    if args.reanalyze_recordings:
        logging.info('Deleting all sonogram analyses')
        session.query(SonogramAnalysis).delete()

    logging.info('Fetching all recordings for selected species')
    recordings = session.query(Recording)\
        .join(Species, Species.scientific_name == Recording.scientific_name)\
        .join(SelectedSpecies)\
        .filter(Recording.sonogram_url_small != None,
                Recording.sonogram_url_small != '',
                ~Recording.sonogram_analysis.has())\
        .all()

    logging.info('Analyzing recordings')
    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.analysis_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)

        for recording_id, sonogram_quality in progress.percent(
                pool.imap(_analyze, [(r.recording_id, r.sonogram_url_small) for r in recordings]),
                len(recordings)):
            session.add(SonogramAnalysis(
                recording_id=recording_id,
                sonogram_quality=sonogram_quality))
            session.commit()
