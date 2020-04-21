'''
Classes related to geography.
'''

from sqlalchemy import Column, Integer, Float, JSON

from base import Base


class Region(Base):
    '''
    A region on the globe representing a "square" of a particular size, aligned
    along the latitude and longitude axes. Contains a weight by species, based
    on the number of observations of this species in this region.
    '''
    __tablename__ = 'regions'

    region_id = Column(Integer, primary_key=True, autoincrement=True, nullable=False)
    lat_start = Column(Float, nullable=False, index=True)
    lat_end = Column(Float, nullable=False, index=True)
    lon_start = Column(Float, nullable=False, index=True)
    lon_end = Column(Float, nullable=False, index=True)
    centroid_lat = Column(Float, nullable=False)
    centroid_lon = Column(Float, nullable=False)
    species_weight_by_scientific_name = Column(JSON)

    def total_weight(self):
        '''
        Returns the total number of recordings counted in this region.
        '''
        if not self.species_weight_by_scientific_name:
            return 0
        return sum(self.species_weight_by_scientific_name.values())

    def num_species(self):
        '''
        Returns the total number of distinct species counted in this region.
        '''
        if not self.species_weight_by_scientific_name:
            return 0
        return len(self.species_weight_by_scientific_name)

    @property
    def scientific_names(self):
        '''
        Returns a list of scientific names of all species occurring in this
        region.
        '''
        return list(self.species_weight_by_scientific_name.keys())

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
        Returns the list of scientific names of species recorded in this
        region, ordered from most to least recorded.
        '''
        if not self.species_weight_by_scientific_name:
            return []
        return [
            scientific_name
            for (weight, scientific_name)
            in sorted(
                ((v, k) for k, v in self.species_weight_by_scientific_name.items()),
                reverse=True)
        ]
