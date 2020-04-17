'''
Selects recordings to use for each selected species.
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


_NUM_RECORDINGS_BY_TYPE = {
    'call': 3,
    'song': 5,
}
_FALLBACK_NUM_RECORDINGS = 5


_sonogram_fetcher = None
def _analyze(recording):
    try:
        # Create one fetcher per process.
        global _sonogram_fetcher
        if not _sonogram_fetcher:
            _sonogram_fetcher = fetcher.Fetcher(cache_group='xc_sonograms_small', pool_size=1)

        sonogram = None
        try:
            sonogram = _sonogram_fetcher.fetch_cached(recording.sonogram_url_small)
        except fetcher.FetchError as ex:
            if ex.is_not_found():
                logging.warning(f'Sonogram for recording {recording.recording_id} was not found')
            else:
                raise ex

        sonogram_quality = -999999
        if sonogram:
            sonogram_quality = analysis.sonogram_quality(recording.recording_id, sonogram)

        return SonogramAnalysis(recording_id=recording.recording_id,
                                sonogram_quality=sonogram_quality)
    except Exception as ex:
        # Re-raise as something that's guaranteed to be pickleable.
        logging.error('Exception during analysis', exc_info=True)
        raise RuntimeError(f'Exception during analysis: {ex}')


def add_args(parser):
    parser.add_argument(
        '--restart_analysis', action='store_true',
        help='Delete all sonogram analyses before starting')
    parser.add_argument(
        '--reselect_recordings', action='store_true',
        help='Re-run the recording selection even for species '
        'for which we already have selected recordings')
    parser.add_argument(
        '--analysis_jobs', default=8,
        help='Number of parallel sonogram analysis jobs to run')


def main(args, session):
    if args.restart_analysis:
        logging.info('Deleting all sonogram analyses')
        session.query(SonogramAnalysis).delete()
    if args.reselect_recordings:
        logging.info('Deleting all recording selections')
        session.query(SelectedRecording).delete()

    logging.info('Fetching selected species')
    selected_species = session.query(Species)\
        .join(SelectedSpecies)\
        .all()

    logging.info('Loading recording blacklist')
    with open(os.path.join(os.path.dirname(__file__), 'recordings_blacklist.txt')) as f:
        blacklisted_recording_ids = list(filter(None, (line.partition('#')[0].strip() for line in f)))

    recording_filter = [
        ~Recording.recording_id.in_(blacklisted_recording_ids),
        Recording.url != None,
        Recording.url != '',
        Recording.audio_url != None,
        Recording.audio_url != '',
        Recording.sonogram_url_small != None,
        Recording.sonogram_url_small != '',
    ]

    logging.info('Selecting best recordings for each species')
    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.analysis_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)

        for species in progress.percent(selected_species):
            scientific_name = species.scientific_name
            num_selected_recordings = session.execute(
                '''
                select count(recording_id)
                from selected_recordings
                inner join recordings using (recording_id)
                where scientific_name = :scientific_name
                ''',
                {'scientific_name': scientific_name})\
                .scalar()
            if num_selected_recordings > 0:
                logging.info(f'Already have {num_selected_recordings} selected recordings for {scientific_name}, skipping')
                continue

            logging.debug(f'Analyzing sonograms for {scientific_name}')
            recordings_to_be_analyzed = session.query(Recording)\
                .filter(Recording.scientific_name == scientific_name,
                        *recording_filter,
                        ~Recording.sonogram_analysis.has())\
                .all()
            for sonogram_analysis in progress.percent(
                    pool.imap(_analyze, recordings_to_be_analyzed),
                    len(recordings_to_be_analyzed)):
                session.add(sonogram_analysis)

            logging.debug(f'Loading recordings and analyses for {scientific_name}')
            recordings = session.query(Recording)\
                .options(joinedload(Recording.sonogram_analysis))\
                .filter(Recording.scientific_name == scientific_name,
                        *recording_filter)\
                .all()

            logging.debug(f'Sorting {len(recordings)} of {scientific_name} by quality')
            recordings.sort(key=analysis.recording_quality, reverse=True)

            recordings_by_type = {t: [] for t in _NUM_RECORDINGS_BY_TYPE}
            for recording in recordings:
                recording_types = []
                for recording_type in recording.types:
                    for t in _NUM_RECORDINGS_BY_TYPE:
                        if recording_type.startswith(t):
                            recording_types.append(t)
                if len(recording_types) == 1:
                    recordings_by_type[recording_types[0]].append(recording)

            selected_types = [
                t for t in _NUM_RECORDINGS_BY_TYPE
                if len(recordings_by_type[t]) >= 0.02 * len(recordings)
            ]
            if selected_types:
                for t in selected_types:
                    recordings_of_type = recordings_by_type[t]
                    num_recordings = _NUM_RECORDINGS_BY_TYPE[t]
                    logging.debug(f'Selecting best {num_recordings} recordings of type "{t}" '
                                  f'for {scientific_name}')
                    for recording in recordings_of_type[:num_recordings]:
                        session.add(SelectedRecording(recording_id=recording.recording_id))
            else:
                num_recordings = _FALLBACK_NUM_RECORDINGS
                logging.debug(f'No particular types selected for {scientific_name}, '
                              f'selecting best {num_recordings} overall')
                for recording in recordings[:num_recordings]:
                    session.add(SelectedRecording(recording_id=recording.recording_id))

            logging.debug(f'Committing transaction')
            session.commit()
