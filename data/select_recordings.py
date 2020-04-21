'''
Selects recordings to use for each selected species.
'''

import collections
import logging
import os.path

from sqlalchemy import text
from sqlalchemy.orm import joinedload

import analysis
import progress
from recordings import Recording, SelectedRecording
from species import Species, SelectedSpecies


_RECORDING_TYPES = ['call', 'song']


def add_args(parser):
    parser.add_argument(
        '--max_selected_recordings_per_species', type=int, default=8,
        help='Number of selected recordings for the most important species')
    parser.add_argument(
        '--min_selected_recordings_per_species', type=int, default=3,
        help='Minimum number of selected recordings for a species')
    parser.add_argument(
        '--recording_selection_decay', type=int, default=0.997,
        help='For each next species, multiply the number of selected recordings by this value')


def main(args, session):
    logging.info('Deleting all recording selections')
    session.query(SelectedRecording).delete()

    logging.info('Ordering selected species by importance')
    selected_species = session.query(Species)\
        .join(SelectedSpecies)\
        .order_by(text('''
            (
                select count(*)
                from recordings
                where recordings.scientific_name = species.scientific_name
            ) desc
        '''))\
        .all()

    logging.info('Loading recording blacklist')
    with open(os.path.join(os.path.dirname(__file__), 'recordings_blacklist.txt')) as f:
        blacklisted_recording_ids = list(filter(None, (line.partition('#')[0].strip() for line in f)))

    logging.info('Selecting best recordings for each species')
    # Not parallelized, because it's mostly database work.
    for index, species in progress.percent(enumerate(selected_species)):
        scientific_name = species.scientific_name

        num_selected_recordings = max(
            round(args.max_selected_recordings_per_species * args.recording_selection_decay**index),
            args.min_selected_recordings_per_species)

        logging.debug(f'Loading recordings and analyses for {scientific_name}')
        recordings = session.query(Recording)\
            .options(joinedload(Recording.sonogram_analysis))\
            .filter(Recording.scientific_name == scientific_name,
                    ~Recording.recording_id.in_(blacklisted_recording_ids),
                    Recording.url != None, # pylint: disable=singleton-comparison
                    Recording.url != '',
                    Recording.audio_url != None, # pylint: disable=singleton-comparison
                    Recording.audio_url != '',
                    Recording.sonogram_analysis.has())\
            .all()

        logging.debug(f'Sorting {len(recordings)} recordings of {scientific_name} by quality')
        recordings.sort(key=analysis.recording_quality)

        num_recordings_by_type = collections.defaultdict(int)
        for recording in recordings:
            for type_ in recording.types:
                num_recordings_by_type[type_] += 1
        types = list(num_recordings_by_type.keys())
        logging.debug(f'Most occurring types for {scientific_name}: '
                      f'{", ".join(f"{t}: {c}" for c, t in sorted(((c, t) for t, c in num_recordings_by_type.items()), reverse=True)[:10])}')

        selected_recordings = []
        num_selected_recordings_by_type = collections.defaultdict(int)
        def underrepresentation(type_):
            target_representation = num_recordings_by_type[type_] / len(recordings) * num_selected_recordings
            current_representation = num_selected_recordings_by_type[type_]
            underrepresentation = target_representation / max(1.0, current_representation)
            return underrepresentation

        while recordings and len(selected_recordings) < num_selected_recordings:
            # Find most underrepresented type.
            type_ = max(types, key=underrepresentation)

            # Find best recording of that type.
            recording = None
            for index in range(len(recordings) - 1, -1, -1):
                if type_ in recordings[index].types:
                    recording = recordings[index]
                    break
            
            # No more recordings of this type? Stop trying to represent it better.
            if not recording:
                types.remove(type_)
                continue

            # Select recording and update counters.
            selected_recordings.append(recording)
            recordings.pop(index)
            session.add(SelectedRecording(recording_id=recording.recording_id))
            for type_ in recording.types:
                num_selected_recordings_by_type[type_] += 1
        logging.debug(f'Selected {num_selected_recordings} of  {species.scientific_name} '
                      f'of types {", ".join(f"{t}: {c}" for c, t in sorted(((c, t) for t, c in num_selected_recordings_by_type.items() if c > 0), reverse=True))}')
