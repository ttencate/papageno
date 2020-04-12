'''
Classes representing metadata about audio recordings.
'''

import logging
import os.path

from sqlalchemy import Column, Integer, Float, String, Boolean, DateTime, Date, Enum, JSON, ForeignKey
from sqlalchemy.schema import Index

from base import Base


class Recording(Base):
    '''
    Metadata about a single recording.
    '''
    __tablename__ = 'recordings'

    recording_id = Column(String, primary_key=True, index=True, nullable=False)
    source = Column(Enum('xc'), nullable=False)
    genus = Column(String)
    species = Column(String)
    subspecies = Column(String)
    common_name_en = Column(String)
    recordist = Column(String)
    country = Column(String)
    location = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    altitude = Column(String) # Seen values like: '?', '250m', '50 - 300'
    type = Column(String)
    url = Column(String)
    audio_url = Column(String)
    audio_file_name = Column(String)
    sonogram_url_small = Column(String)
    sonogram_url_medium = Column(String)
    sonogram_url_large = Column(String)
    sonogram_url_full = Column(String)
    license_url = Column(String)
    quality = Column(String)
    length_seconds = Column(Integer)
    date_time = Column(DateTime)
    upload_date = Column(Date)
    background_species = Column(JSON)
    remarks = Column(String)
    bird_seen = Column(Boolean)
    playback_used = Column(Boolean)

    @property
    def scientific_name(self):
        '''
        Returns the scientific name of the recorded species, without the
        subspecies (if any).
        '''
        return self.genus + ' ' + self.species


Index('recordings_scientific_name', Recording.genus, Recording.species)


class SelectedRecording(Base):
    '''
    A table of all recording ids that were selected to be included in the app.
    '''
    __tablename__ = 'selected_recordings'

    recording_id = Column(String, ForeignKey('recordings.recording_id'),
                          primary_key=True, index=True, nullable=False)
