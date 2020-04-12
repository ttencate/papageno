#!/usr/bin/env python

'''
Groups recordings by geographical regions, and ranks them by species from most
to least occurring.
'''

import argparse
import collections
import csv
import logging
import os.path
import math
import sys

import db
from recordings import Recording
from species import Species
from regions import Region


_SIZE_LAT = 1.0
_SIZE_LON = 1.0


def _round_down(x, multiple_of):
    return math.floor(x / multiple_of) * multiple_of


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    args = parser.parse_args()

    session = db.create_session()

    logging.info('Creating regions')
    session.query(Region).delete()
    regions = {}
    lat = -90.0
    while lat < 90.0:
        lon = -180.0
        while lon < 180.0:
            lat_start = lat
            lon_start = lon
            lat_end = lat_start + _SIZE_LAT
            lon_end = lon_start + _SIZE_LON
            centroid_lat = (lat_start + lat_end) / 2
            centroid_lon = (lon_start + lon_end) / 2
            region = Region(
                lat_start=lat_start,
                lat_end=lat_end,
                lon_start=lon_start,
                lon_end=lon_end,
                centroid_lat=centroid_lat,
                centroid_lon=centroid_lon)
            regions[(lat_start, lon_start)] = region
            lon += _SIZE_LON
        lat += _SIZE_LAT

    logging.info('Adding recordings to regions')
    prev_progress_percent = 0
    num_recordings = session.query(Recording).count()
    for i, recording in enumerate(session.query(Recording)):
        progress_percent = i * 100 // num_recordings
        if progress_percent != prev_progress_percent:
            logging.info(f'Processed {i} recordings ({progress_percent}%)')
            prev_progress_percent = progress_percent

        if not recording.latitude or not recording.longitude:
            continue

        scientific_name = recording.scientific_name
        species = session.query(Species)\
            .filter(Species.scientific_name == scientific_name)\
            .one_or_none()
        if not species:
            if scientific_name not in ['Mystery mystery', 'Sonus naturalis']:
                logging.warning(f'Species {scientific_name} of recording {recording.recording_id} '
                                f'not found in species list')
            continue

        region = regions[(
            _round_down(recording.latitude, _SIZE_LAT),
            _round_down(recording.longitude, _SIZE_LON))]
        region.add_recording(species.scientific_name)

    logging.info('Committing transaction')
    session.bulk_save_objects(regions.values())
    session.commit()


if __name__ == '__main__':
    sys.exit(_main())
