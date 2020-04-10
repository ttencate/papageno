#!/usr/bin/env python

'''
Selects recordings that are suitable for our application.
'''

import argparse
import collections
import logging
import os.path
import sys

from recordings import RecordingsList
from species import SpeciesList


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--recordings_file', default=RecordingsList.DEFAULT_FILE_NAME,
        help='File containing recordings metadata')
    parser.add_argument(
        '--species_file',
        default=SpeciesList.DEFAULT_FILE_NAME,
        help='File containing species list')
    parser.add_argument(
        '--selected_recordings_file',
        default=os.path.join(os.path.dirname(__file__), 'sources', 'selected_recordings.csv'),
        help='File to write selected recordings to')
    parser.add_argument(
        '--selected_species_file',
        default=os.path.join(os.path.dirname(__file__), 'sources', 'selected_species.csv'),
        help='File to write selected species to')
    args = parser.parse_args()

    recordings_list = RecordingsList()
    recordings_list.load(args.recordings_file)

    species_list = SpeciesList()
    species_list.load(args.species_file)

    selected_recordings_list = RecordingsList()
    num_recordings_by_species_id = collections.defaultdict(int)

    for recording in recordings_list:
        try:
            species = species_list.get_species(recording.scientific_name)
        except KeyError:
            continue
        if (recording.quality == 'A' and
                5 <= recording.duration_seconds <= 20 and
                not recording.background_species):
            selected_recordings_list.add_recording(recording)
            num_recordings_by_species_id[species.species_id] += 1

    selected_species_list = SpeciesList()

    for species in species_list:
        if num_recordings_by_species_id[species.species_id] >= 5:
            selected_species_list.add_species(species)

    selected_recordings_list.save(args.selected_recordings_file)
    selected_species_list.save(args.selected_species_file)


if __name__ == '__main__':
    sys.exit(_main())
