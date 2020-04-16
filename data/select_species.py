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
    parser.add_argument(
        '--min_image_size', type=int, default=512,
        help='Minimum image size for images (and thus species) '
        'to be selected for inclusion in the app')


def main(args, session):
    session.query(SelectedSpecies).delete()

    logging.info('Filtering species by number of available recordings and images')
    selected_species_ids = session.execute(
        '''
        select species_id
        from species
        where
            (
                select count(*)
                from recordings
                where
                    recordings.scientific_name = species.scientific_name
                    and recordings.url is not null
                    and recordings.url <> ''
            ) >= :min_recordings
            and
            exists (
                select *
                from images
                where
                    images.species_id = species.species_id
                    and output_file_name is not null
                    and output_file_name <> ''
                    and license_name is not null
                    and license_name <> ''
                    and image_width >= :min_image_size
                    and image_height >= :min_image_size
            )
        ''',
        {
            'min_recordings': args.min_recordings_per_species,
            'min_image_size': args.min_image_size,
        })\
        .fetchall()
    for (species_id,) in progress.percent(selected_species_ids):
        session.add(SelectedSpecies(species_id=species_id))

    logging.info(f'Selected {session.query(SelectedSpecies).count()} species')
