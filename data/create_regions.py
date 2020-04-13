'''
Ingests the `recordings` table and groups recordings by location into 1×1
degree "squares" of latitude and longitude, writing the output to the
`regions` table.

Of course, the farther you go from the equator, the more narrow and pointy
these become, but this is not really a problem for our purposes because most
birds don't live on the poles anyway.

For each square, it creates a ranking of which species were recorded, from most
to least. Basing this on the number of _recordings_, rather than some other
source like the number of _occurrences_ or _sightings_ of a species, makes
sense for this app; after all, what we most care about is which birds you're
likely to hear most.
'''

import logging
import math

import progress
from recordings import Recording
from species import Species
from regions import Region


_SIZE_LAT = 1.0
_SIZE_LON = 1.0


def _round_down(x, multiple_of):
    return math.floor(x / multiple_of) * multiple_of


def _create_regions(session):
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
    return regions


def _add_recordings_to_regions(session, recordings, regions):
    logging.info('Adding recordings to regions')
    for recording in progress.percent(recordings):
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


def main(unused_args, session):
    regions = _create_regions(session)
    _add_recordings_to_regions(session, session.query(Recording), regions)

    session.bulk_save_objects(regions.values())
