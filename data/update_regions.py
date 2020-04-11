#!/usr/bin/env python

# TODO port to SQLite

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

import natsort

from recordings import RecordingsList
from species import SpeciesList


class Region:
    '''
    A region on the globe representing a "square" of a particular size, aligned
    along the latitude and longitude axes.
    '''

    def __init__(self, region_id, lat_start, lat_end, lon_start, lon_end): # pylint: disable=too-many-arguments
        '''
        Creates a new empty Region.
        '''
        self.region_id = region_id
        self.lat_start = lat_start
        self.lat_end = lat_end
        self.lon_start = lon_start
        self.lon_end = lon_end
        self._num_recordings_by_species_id = collections.defaultdict(int)

    def add_recording(self, species_id):
        '''
        Tallies the species id as having been recorded in this region.
        '''
        self._num_recordings_by_species_id[species_id] += 1

    def num_recordings(self):
        '''
        Returns the total number of recordings counted in this region.
        '''
        return sum(self._num_recordings_by_species_id.values())

    def num_species(self):
        '''
        Returns the total number of distinct species counted in this region.
        '''
        return len(self._num_recordings_by_species_id)

    def to_wkt(self):
        '''
        Returns a string representing this region's geography in WKT
        (Well-Known Text) format.
        '''
        corners = [
            (self.lon_start, self.lat_start),
            (self.lon_start, self.lat_end),
            (self.lon_end, self.lat_end),
            (self.lon_end, self.lat_start),
            (self.lon_start, self.lat_start),
        ]
        return f'POLYGON(({",".join(" ".join(map(str, corner)) for corner in corners)}))'

    def ranked_species_ids(self):
        '''
        Returns the list of species ids recorded in this region, ordered from
        most to least recorded.
        '''
        return [
            species_id
            for (num_recordings, species_id)
            in sorted(
                ((v, k) for k, v in self._num_recordings_by_species_id.items()),
                reverse=True)
        ]


class RegionsList:
    '''
    A list of Regions, with functionality to get the region within which a
    particular coordinate falls, and file reading and writing.
    '''

    DEFAULT_FILE_NAME = os.path.join(os.path.dirname(__file__), 'sources', 'regions.csv')

    def __init__(self, region_size=(1.0, 1.0)):
        self._lat_region_size, self._lon_region_size = region_size
        self._by_region_id = {}

    def get_region(self, lat_lon):
        '''
        Returns the region containing the given (lat, lon) coordinate (WGS84).
        '''
        lat, lon = lat_lon
        lat_start = math.floor(lat / self._lat_region_size) * self._lat_region_size
        lat_end = lat_start + self._lat_region_size
        lon_start = math.floor(lon / self._lon_region_size) * self._lon_region_size
        lon_end = lon_start + self._lon_region_size
        region_id = f'{lat_start}:{lon_start}'
        if region_id not in self._by_region_id:
            self._by_region_id[region_id] = Region(
                region_id, lat_start, lat_end, lon_start, lon_end)
        return self._by_region_id[region_id]

    def save(self, file_name):
        '''
        Saves the regions to a CSV file.
        '''
        logging.info(f'Saving regions to {file_name}')
        with open(file_name, 'wt') as output_file:
            writer = csv.DictWriter(
                output_file,
                ['region_id', 'geography', 'num_recordings', 'num_species', 'ranked_species_ids'])
            writer.writeheader()
            for region_id in natsort.natsorted(self._by_region_id.keys()):
                region = self._by_region_id[region_id]
                writer.writerow({
                    'region_id': region_id,
                    'geography': region.to_wkt(),
                    'num_recordings': region.num_recordings(),
                    'num_species': region.num_species(),
                    'ranked_species_ids': ';'.join(map(str, region.ranked_species_ids())),
                })


def _main():
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--recordings_file', default=RecordingsList.DEFAULT_FILE_NAME,
        help='File containing recordings metadata')
    parser.add_argument(
        '--selected_species_list_file',
        default=os.path.join(os.path.dirname(__file__), 'sources', 'selected_species.csv'),
        help='File containing species list')
    parser.add_argument(
        '--regions_file',
        default=RegionsList.DEFAULT_FILE_NAME,
        help='File to write regions to')
    args = parser.parse_args()

    recordings_list = RecordingsList()
    recordings_list.load(args.recordings_file)

    species_list = SpeciesList()
    species_list.load(args.species_list_file)

    regions_list = RegionsList()

    for recording in recordings_list:
        lat_lon = recording.lat_lon
        if not lat_lon:
            logging.debug(f'Recording {recording.recording_id} has no lat,lon')
            continue
        scientific_name = recording.scientific_name
        try:
            species = species_list.get_species(scientific_name)
        except KeyError:
            if scientific_name not in ['Mystery mystery', 'Sonus naturalis']:
                logging.info(f'Species {scientific_name} of recording {recording.recording_id} '
                             f'not found in species list')
            continue
        region = regions_list.get_region(recording.lat_lon)
        region.add_recording(species.species_id)

    regions_list.save(args.regions_file)


if __name__ == '__main__':
    sys.exit(_main())
