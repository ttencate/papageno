#!/usr/bin/env python

'''
Selects recordings that are suitable for our application.
'''

import argparse
import collections
import logging
import sys

from recordings import Recording, SelectedRecording
from species import Species, SelectedSpecies

import db


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    args = parser.parse_args()

    session = db.create_session()

    session.query(SelectedRecording).delete()
    session.query(SelectedSpecies).delete()

    num_recordings_by_species_id = collections.defaultdict(int)

    logging.info(f'Filtering {session.query(Recording).count()} recordings')
    for recording in session.query(Recording)\
            .filter(
                Recording.quality == 'A',
                Recording.length_seconds >= 5,
                Recording.length_seconds <= 20,
                Recording.background_species == '[]'):
        species = session.query(Species)\
            .filter(Species.scientific_name == recording.scientific_name)\
            .one_or_none()
        if not species:
            continue
        session.add(SelectedRecording(recording_id=recording.recording_id))
        num_recordings_by_species_id[species.species_id] += 1
    logging.info(f'Selected {session.query(SelectedRecording).count()} recordings')

    logging.info(f'Filtering {session.query(Species).count()} species')
    for species in session.query(Species):
        if num_recordings_by_species_id[species.species_id] >= 5:
            session.add(SelectedSpecies(species_id=species.species_id))
    logging.info(f'Selected {session.query(SelectedSpecies).count()} species')

    logging.info('Committing transaction')
    session.commit()


if __name__ == '__main__':
    sys.exit(_main())
