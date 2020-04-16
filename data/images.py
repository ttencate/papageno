'''
Classes for bird photos.
'''

from sqlalchemy import Column, Integer, String, Enum, ForeignKey, Boolean
from sqlalchemy.orm import relationship

from base import Base


class Image(Base):
    '''
    Represents a photo.
    '''
    __tablename__ = 'images'

    species_id = Column(Integer, primary_key=True, index=True, nullable=False, autoincrement=True)
    source_page_url = Column(String)
    image_file_url = Column(String)
    image_width = Column(Integer)
    image_height = Column(Integer)
    output_file_name = Column(String)
    license_name = Column(String)
    license_url = Column(String)
    attribution = Column(String)
