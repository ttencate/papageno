'''
Selects which species to include in the app, and writes them to the
`selected_species` table.
'''

import collections
import logging

from sqlalchemy.sql.expression import text

import progress
from regions import Region
from species import Species, SelectedSpecies


def add_args(parser):
    parser.add_argument(
        '--num_selected_species', type=int, default=1200,
        help='Number of species to select for inclusion in the app')
    parser.add_argument(
        '--min_image_size', type=int, default=512,
        help='Minimum image size for images (and thus species) '
        'to be selected for inclusion in the app')


def main(args, session):
    logging.info('Deleting existing species selections')
    session.query(SelectedSpecies).delete()

    logging.info('Filtering species by sufficient available recordings and images')
    candidate_species = session.query(Species)\
        .filter(text(
            '''
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
            '''))\
        .params(
            num_selected_species=args.num_selected_species,
            min_image_size=args.min_image_size)\
        .all()

    logging.info('Counting number of regions in which species occur')
    num_regions_by_species = collections.defaultdict(int)
    for region in progress.percent(session.query(Region).all()):
        for scientific_name in region.scientific_names:
            num_regions_by_species[scientific_name] += 1

    logging.info('Sorting candidate species by number of regions')
    candidate_species.sort(
        key=lambda s: num_regions_by_species.get(s.scientific_name, 0),
        reverse=True)

    logging.info('Selecting top species')
    selected_species = candidate_species[:args.num_selected_species]
    for index, species in enumerate(progress.percent(selected_species)):
        session.add(SelectedSpecies(
            species_id=species.species_id,
            ranking=index + 1))

    logging.info(f'Selected {session.query(SelectedSpecies).count()} species; top 10: '
                 f'{", ".join(s.scientific_name for s in selected_species[:10])}')
