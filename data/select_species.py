'''
Selects those species for which there are enough recordings, and writes them to
the `selected_species` table.
'''

import logging

import progress
from species import SelectedSpecies


def add_args(parser):
    parser.add_argument(
        '--min_recordings_per_species', type=int, default=50,
        help='Minimum number of xeno-canto recordings needed for a species '
        'to be selected for inclusion in the app')


def main(args, session):
    session.query(SelectedSpecies).delete()

    logging.info('Filtering species by number of available recordings')
    selected_species_ids = session.execute(
        '''
        select species_id
        from species
        left join recordings using (scientific_name)
        where recordings.url is not null and recordings.url <> ''
        group by species_id
        having count(recording_id) >= :min_recordings
        ''',
        {'min_recordings': args.min_recordings_per_species})\
        .fetchall()
    for (species_id,) in progress.percent(selected_species_ids):
        session.add(SelectedSpecies(species_id=species_id))

    logging.info(f'Selected {session.query(SelectedSpecies).count()} species')
