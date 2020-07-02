'''
Stores all needed data in `app.db` for inclusion in the app.
'''

import logging
import os
import os.path
import re

from sqlalchemy import Table, Column, Integer, Float, String, LargeBinary, MetaData

import db
from images import Image
from recordings import Recording, SelectedRecording
from species import Species, SelectedSpecies, LANGUAGE_CODES
from regions import Region


def _license_url_to_name(url):
    m = re.search(r'creativecommons\.org/licenses/(.*?)/(\d\.\d)/?', url)
    if not m:
        raise ValueError(url)
    return f'CC {m.group(1).upper()} {m.group(2)}'


def _make_absolute(url):
    if not url:
        return url
    if url.startswith('//'):
        return 'https:' + url
    return url


def _encode_weights(weights_by_species_id):
    '''
    Encodes the map as a raw byte array of `key,value,key,value,...`, both keys
    and values being encoded as unsigned 16-bits integers in big-endian format.

    >>> _weights_to_bytes({5: 18, 2: 16}).hex()
    '0005001200020010'
    >>> _weights_to_bytes({1: 100000, 2: 10000}).hex()
    '0001ffff0002199a'
    '''
    max_weight = max(weights_by_species_id.values())
    scale = min(1, 65535 / max_weight)
    def encode(i):
        return i.to_bytes(2, byteorder='big', signed=False)
    return b''.join(
        encode(species_id) + encode(round(scale * weight))
        for species_id, weight in weights_by_species_id.items()
    )


def main(_args, session):
    app_db_file = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'app.db')
    try:
        os.remove(app_db_file)
    except FileNotFoundError:
        pass
    out = db.create_connection(app_db_file)

    logging.info('Creating tables')
    metadata = MetaData()
    out_species = Table(
        'species', metadata,
        Column('species_id', Integer, primary_key=True, nullable=False, index=True),
        Column('scientific_name', String, nullable=False, index=True),
        *(
            Column('common_name_' + language_code, String, index=True)
            for language_code in LANGUAGE_CODES
        ))
    out_recordings = Table(
        'recordings', metadata,
        Column('recording_id', String, primary_key=True, nullable=False, index=True),
        Column('species_id', Integer, nullable=False, index=True),
        Column('file_name', String, nullable=False),
        Column('source_url', String),
        Column('license_name', String),
        Column('license_url', String),
        Column('attribution', String))
    out_images = Table(
        'images', metadata,
        Column('species_id', Integer, primary_key=True, nullable=False, index=True),
        Column('file_name', String, nullable=False),
        Column('source_url', String),
        Column('license_name', String),
        Column('license_url', String),
        Column('attribution', String))
    out_regions = Table(
        'regions', metadata,
        Column('region_id', Integer, primary_key=True, nullable=False),
        Column('centroid_lat', Float, nullable=False),
        Column('centroid_lon', Float, nullable=False),
        Column('weight_by_species_id', LargeBinary, nullable=False))
    metadata.create_all(out.engine)

    selected_species_ids_by_scientific_name = {
        s.scientific_name: s.species_id
        for s in session.query(Species).join(SelectedSpecies)
    }

    logging.info('Inserting selected species')
    out.execute(out_species.insert(), [ # pylint: disable=no-value-for-parameter
        {
            'species_id': s.species_id,
            'scientific_name': s.scientific_name,
            **{
                'common_name_' + language_code: s.common_name(language_code)
                for language_code in LANGUAGE_CODES
            },
        }
        for s in session.query(Species).join(SelectedSpecies)
    ])

    logging.info('Inserting selected recordings')
    out.execute(out_recordings.insert(), [ # pylint: disable=no-value-for-parameter
        {
            'recording_id': r.recording_id,
            'species_id': s.species_id,
            'file_name': f'{r.recording_id.replace(":", "_")}.ogg',
            'source_url': _make_absolute(r.url),
            'license_name': _license_url_to_name(r.license_url),
            'license_url': _make_absolute(r.license_url),
            'attribution': r.recordist,
        }
        for (r, s) in session.query(Recording, Species)\
            .join(SelectedRecording)\
            .join(Species, Species.scientific_name == Recording.scientific_name)
    ])

    logging.info('Inserting images for selected species')
    out.execute(out_images.insert(), [ # pylint: disable=no-value-for-parameter
        {
            'species_id': i.species_id,
            'file_name': f'{s.scientific_name.replace(" ", "_")}.webp',
            'source_url': i.source_page_url,
            'license_name': i.license_name,
            'license_url': i.license_url,
            'attribution': i.attribution,
        }
        for (i, s) in session.query(Image, Species)\
            .join(Species, Image.species_id == Species.species_id)\
            .join(SelectedSpecies)
    ])

    logging.info('Inserting nonempty regions')
    out.execute(out_regions.insert(), [ # pylint: disable=no-value-for-parameter
        {
            'region_id': r.region_id,
            'centroid_lat': r.centroid_lat,
            'centroid_lon': r.centroid_lon,
            'weight_by_species_id': _encode_weights({
                selected_species_ids_by_scientific_name[scientific_name]: num_recordings
                for scientific_name, num_recordings in r.species_weight_by_scientific_name.items()
                if scientific_name in selected_species_ids_by_scientific_name
            }),
        }
        for r in session.query(Region)\
        .filter(Region.species_weight_by_scientific_name != None, # pylint: disable=singleton-comparison
                Region.species_weight_by_scientific_name != [])
        if any(
            scientific_name in selected_species_ids_by_scientific_name
            for scientific_name in r.species_weight_by_scientific_name)
    ])
