'''
Loads species observations from `ebd_regions.csv` which was produces by
the `ebd_aggregator` program. These are regions of 1×1 degree latitude and
longitude, and for each region we have a count of how often the species was
observed there.

Of course, the farther you go from the equator, the more narrow and pointy
these become, but this is not really a problem for our purposes because most
birds don't live on the poles anyway.

A complication is that eBird uses the Clemens taxonomy, whereas xeno-canto uses
IOC. Fortunately IOC publishes a mapping between the two, which is applied
here.
'''

import csv
import json
import logging
import os.path
import math

import progress
from recordings import Recording
from species import Species
from regions import Region


_SIZE_LAT = 1.0
_SIZE_LON = 1.0


def _round_down(x, multiple_of):
    return math.floor(x / multiple_of) * multiple_of


def add_args(parser):
    parser.add_argument(
        '--ebd_regions_file',
        default=os.path.join(os.path.dirname(__file__), 'sources', 'ebd_regions.csv'),
        help='Path to CSV file containing eBird observation data by region')


def main(args, session):
    logging.info('Deleting existing regions')
    session.query(Region).delete()

    logging.info('Loading species')
    clements_to_ioc = {
        species.scientific_name_clements: species.scientific_name
        for species in session.query(Species)
        if species.scientific_name_clements
    }

    logging.info('Processing regions')
    regions = []
    warned_scientific_names = set()
    with open(args.ebd_regions_file, 'rt') as input_file:
        # Hardcoding the CSV length here is awful but it's just for progress reporting anyway.
        for row in progress.percent(csv.DictReader(input_file), 14835):
            region_id = int(row['region_id'])
            centroid_lat = float(row['centroid_lat'])
            centroid_lon = float(row['centroid_lon'])
            observations_by_scientific_name = json.loads(row['observations_by_scientific_name'])
            species_weight_by_scientific_name = {}
            for scientific_name_clements, num_observations in observations_by_scientific_name.items():
                scientific_name = clements_to_ioc.get(scientific_name_clements)
                if not scientific_name:
                    if (scientific_name_clements not in warned_scientific_names
                            and '/' not in scientific_name_clements # Uncertainties.
                            and 'sp.' not in scientific_name_clements.split(' ') # Only genus, not species.
                            and 'x' not in scientific_name_clements.split(' ') # Hybrids.
                            and 'undescribed' not in scientific_name_clements # Undescribed forms.
                            ):
                        # This happens a fair bit; in the "IOC vs other lists"
                        # these rows are typically reddish brown, indicating
                        # "species not recognized by IOC".
                        logging.warning(f'Scientific name {scientific_name_clements} not found (probably recognized by Clements but not IOC)')
                        warned_scientific_names.add(scientific_name_clements)
                    continue
                species_weight_by_scientific_name[scientific_name] = num_observations
            regions.append(Region(
                region_id=region_id,
                lat_start=centroid_lat - _SIZE_LAT / 2,
                lat_end=centroid_lat + _SIZE_LAT / 2,
                lon_start=centroid_lon - _SIZE_LON / 2,
                lon_end=centroid_lon + _SIZE_LON / 2,
                centroid_lat=centroid_lat,
                centroid_lon=centroid_lon,
                species_weight_by_scientific_name=species_weight_by_scientific_name))

    session.bulk_save_objects(regions)
