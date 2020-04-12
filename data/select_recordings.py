#!/usr/bin/env python

'''
Selects recordings that are suitable for our application.
'''

import argparse
import collections
import hashlib
import logging
import os.path
import sys

from sqlalchemy.orm import defer, undefer

import db
import progress
from recordings import Recording, SelectedRecording
from species import Species, SelectedSpecies


_ALLOWED_TYPES = set([
    'song', 'dawn song', 'subsong', 'canto',
    'call', 'calls', 'flight call', 'flight calls', 'nocturnal flight call', 'alarm call',
    # 'begging call', 'drumming'
    'male', 'female', 'sex uncertain', 'adult',
])
_MIN_NUM_RECORDINGS = 5
_MAX_NUM_RECORDINGS = 10


def _sha1(value):
    hasher = hashlib.sha1()
    hasher.update(str(value).encode('utf-8'))
    return hasher.digest()


def _recording_quality(recording):
    # Hash the recording_id for a stable pseudo-random selection. Later, we can
    # base quality on the actual audio.
    return _sha1(recording.recording_id)


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    parser.parse_args()

    session = db.create_session()

    session.query(SelectedRecording).delete()
    session.query(SelectedSpecies).delete()

    candidate_recordings_by_species_id = collections.defaultdict(list)

    blacklist_file = os.path.join(os.path.dirname(__file__), 'recordings_blacklist.txt')
    logging.info(f'Loading blacklist {blacklist_file}')
    with open(blacklist_file, 'rt') as blacklist:
        blacklist_ids = set(filter(None, [
            line.partition('#')[0].strip()
            for line in blacklist
        ]))

    logging.info(f'Selecting candidate recordings')
    for recording in progress.percent(session.query(Recording)\
            .options(defer('*'), *map(undefer, ['recording_id', 'genus', 'species', 'type']))\
            .filter(
                    Recording.quality == 'A',
                    Recording.length_seconds >= 5,
                    Recording.length_seconds <= 20,
                    Recording.background_species == [])):
        if recording.recording_id in blacklist_ids:
            continue
        species = session.query(Species)\
            .filter(Species.scientific_name == recording.scientific_name)\
            .one_or_none()
        if not species:
            continue
        if not recording.type:
            continue
        types = map(str.strip, recording.type.lower().split(','))
        if set(types).difference(_ALLOWED_TYPES):
            continue
        candidate_recordings_by_species_id[species.species_id].append(recording)
    logging.info(f'Selected {session.query(SelectedRecording).count()} candidate recordings')

    logging.info(f'Filtering species and recordings')
    for species in progress.percent(session.query(Species)):
        candidate_recordings = candidate_recordings_by_species_id[species.species_id]
        if len(candidate_recordings) >= _MIN_NUM_RECORDINGS:
            candidate_recordings.sort(key=_recording_quality)
            for recording in candidate_recordings[:_MAX_NUM_RECORDINGS]:
                session.add(SelectedRecording(recording_id=recording.recording_id))
            session.add(SelectedSpecies(species_id=species.species_id))
    logging.info(f'Selected {session.query(SelectedSpecies).count()} species')
    logging.info(f'Selected {session.query(SelectedRecording).count()} recordings')

    logging.info('Committing transaction')
    session.commit()


if __name__ == '__main__':
    sys.exit(_main())
