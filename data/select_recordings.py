'''
Selects recordings to use for each selected species.
'''

import collections
import logging

from sqlalchemy.orm import joinedload

import analysis
import progress
from recordings import Recording, SelectedRecording, RecordingOverrides
from species import Species, SelectedSpecies


_RECORDING_TYPES = ['call', 'song']
_MAX_SELECTED_RECORDINGS_PER_SPECIES = 7
_MIN_SELECTED_RECORDINGS_PER_SPECIES = 3
_RECORDING_SELECTION_DECAY = 0.996


def select_recordings(session, species, recording_overrides, assume_deleted=False):
    if not assume_deleted:
        selected_recordings = session.query(SelectedRecording)\
            .join(Recording)\
            .filter(Recording.scientific_name == species.scientific_name)\
            .all()
        for selected_recording in selected_recordings:
            session.delete(selected_recording)

    scientific_name = species.scientific_name

    ranking = species.selected_species.ranking
    num_selected_recordings = max(
        round(_MAX_SELECTED_RECORDINGS_PER_SPECIES * _RECORDING_SELECTION_DECAY**ranking),
        _MIN_SELECTED_RECORDINGS_PER_SPECIES)

    logging.debug(f'Loading recordings and analyses for {scientific_name}')
    recordings = session.query(Recording)\
        .options(joinedload(Recording.sonogram_analysis))\
        .filter(Recording.scientific_name == scientific_name,
                Recording.url != None, # pylint: disable=singleton-comparison
                Recording.url != '',
                Recording.audio_url != None, # pylint: disable=singleton-comparison
                Recording.audio_url != '',
                Recording.sonogram_analysis.has())\
        .all()
    recordings = [
        recording for recording in recordings
        if recording_overrides[recording.recording_id].status != 'blacklist'
    ]

    logging.debug(f'Sorting {len(recordings)} recordings of {scientific_name} by quality')
    recordings.sort(key=analysis.recording_quality)

    num_recordings_by_type = collections.defaultdict(int)
    for recording in recordings:
        for type_ in recording.types:
            num_recordings_by_type[type_] += 1
    types = list(num_recordings_by_type.keys())
    logging.debug('Most occurring types for {scientific_name}: %s',
                  ', '.join(f'{t}: {c}' for c, t in sorted(
                      ((c, t) for t, c in num_recordings_by_type.items()),
                      reverse=True)[:10]))

    selected_recordings = []
    num_selected_recordings_by_type = collections.defaultdict(int)
    def underrepresentation(type_):
        target_representation = num_recordings_by_type[type_] / len(recordings) * num_selected_recordings
        current_representation = num_selected_recordings_by_type[type_]
        underrepresentation = target_representation / max(1.0, current_representation)
        return underrepresentation

    def select_recording(recording):
        selected_recordings.append(recording)
        recordings.remove(recording)
        session.add(SelectedRecording(recording_id=recording.recording_id))
        for type_ in recording.types:
            num_selected_recordings_by_type[type_] += 1

    for recording in recordings[:]:
        if recording_overrides[recording.recording_id].status == 'goldlist':
            select_recording(recording)

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
        select_recording(recording)

    logging.debug('Selected %d recordings of %s of types %s',
                  num_selected_recordings,
                  species.scientific_name,
                  ', '.join(f'{t}: {c}' for c, t in sorted(
                      ((c, t) for t, c in num_selected_recordings_by_type.items() if c > 0),
                      reverse=True)))


def add_args(_parser):
    pass


def main(_args, session):
    logging.info('Deleting all recording selections')
    session.query(SelectedRecording).delete()

    logging.info('Ordering selected species by importance')
    selected_species = session.query(Species)\
        .join(SelectedSpecies)\
        .order_by(SelectedSpecies.ranking)\
        .all()

    logging.info('Loading recording overrides')
    recording_overrides = RecordingOverrides()

    logging.info('Selecting best recordings for each species')
    # Not parallelized, because it's mostly database work.
    for species in progress.percent(selected_species):
        select_recordings(session, species, recording_overrides, assume_deleted=True)
