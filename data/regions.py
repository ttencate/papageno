'''
Classes related to geography.
'''

import logging
import os.path

from sqlalchemy import Column, Integer, String, Float, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.schema import Index

from base import Base


class Region(Base):
    '''
    A region on the globe representing a "square" of a particular size, aligned
    along the latitude and longitude axes. Contains a count by species of the
    number of recordings created in this region.
    '''
    __tablename__ = 'regions'

    region_id = Column(Integer, primary_key=True, autoincrement=True, nullable=False)
    lat_start = Column(Float, nullable=False, index=True)
    lat_end = Column(Float, nullable=False, index=True)
    lon_start = Column(Float, nullable=False, index=True)
    lon_end = Column(Float, nullable=False, index=True)
    centroid_lat = Column(Float, nullable=False)
    centroid_lon = Column(Float, nullable=False)
    num_recordings_by_scientific_name = Column(JSON)

    def add_recording(self, scientific_name):
        '''
        Tallies the species id as having been recorded in this region.
        '''
        if not self.num_recordings_by_scientific_name:
            self.num_recordings_by_scientific_name = {}
        self.num_recordings_by_scientific_name[scientific_name] = \
            self.num_recordings_by_scientific_name.get(scientific_name, 0) + 1

    def num_recordings(self):
        '''
        Returns the total number of recordings counted in this region.
        '''
        return sum(self.num_recordings_by_scientific_name.values())

    def num_species(self):
        '''
        Returns the total number of distinct species counted in this region.
        '''
        return len(self.num_recordings_by_scientific_name)

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

    def ranked_scientific_names(self):
        '''
        Returns the list of species ids recorded in this region, ordered from
        most to least recorded.
        '''
        return [
            scientific_name
            for (num_recordings, scientific_name)
            in sorted(
                ((v, k) for k, v in self.num_recordings_by_scientific_name.items()),
                reverse=True)
        ]
