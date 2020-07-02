'''
Classes representing metadata about audio recordings.
'''

import collections
import csv
import logging
import os.path

from sqlalchemy import Column, Integer, Float, String, Boolean, DateTime, Date, Enum, JSON, ForeignKey
from sqlalchemy.orm import relationship

from base import Base


class Recording(Base):
    '''
    Metadata about a single recording.
    '''
    __tablename__ = 'recordings'

    recording_id = Column(String, primary_key=True, index=True, nullable=False)
    source = Column(Enum('xc'), nullable=False)
    scientific_name = Column(String, index=True) # genus + species, for joining the species table
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

    selected_recording = relationship('SelectedRecording', back_populates='recording', uselist=False)
    sonogram_analysis = relationship('SonogramAnalysis', back_populates='recording', uselist=False)

    @property
    def types(self):
        return list(filter(None, map(str.strip, self.type.lower().split(','))))


class SonogramAnalysis(Base):
    '''
    Data derived from a recording's sonogram, stored for quicker calculations.
    '''
    __tablename__ = 'sonogram_analyses'

    recording_id = Column(String, ForeignKey('recordings.recording_id'),
                          primary_key=True, index=True, nullable=False)
    sonogram_quality = Column(Float, nullable=False)

    recording = relationship('Recording', back_populates='sonogram_analysis', uselist=False)


class SelectedRecording(Base):
    '''
    A table of all recording ids that were selected to be included in the app.
    '''
    __tablename__ = 'selected_recordings'

    recording_id = Column(String, ForeignKey('recordings.recording_id'),
                          primary_key=True, index=True, nullable=False)

    recording = relationship('Recording', back_populates='selected_recording', uselist=False)


class RecordingOverrides:
    '''
    Wrapper around recording_overrides.csv, which specifies manual overrides on
    top of the automatic recording selection algorithm.
    '''

    FILE_NAME = os.path.join(os.path.dirname(__file__), 'recording_overrides.csv')

    def __init__(self):
        self._overrides = {}
        with open(RecordingOverrides.FILE_NAME, 'rt') as f:
            for row in csv.DictReader(f):
                override = RecordingOverride(**row)
                self._overrides[override.recording_id] = override
        logging.info(f'Loaded {len(self._overrides)} recording overrides')

    def __iter__(self):
        return iter(self._overrides.values())

    def __getitem__(self, recording_id):
        return self._overrides.get(recording_id, RecordingOverride(recording_id, '', ''))

    def set(self, recording_id, status, reason):
        self._overrides[recording_id] = RecordingOverride(recording_id, status, reason)

    def delete(self, recording_id):
        if recording_id in self._overrides:
            del self._overrides[recording_id]

    def save(self):
        with open(RecordingOverrides.FILE_NAME, 'wt') as f:
            w = csv.DictWriter(f, RecordingOverride.fields())
            w.writeheader()
            # Always write sorted to make order reproducible.
            for key in sorted(self._overrides.keys()):
                w.writerow(self._overrides[key].to_dict())


class RecordingOverride(collections.namedtuple('RecordingOverride', ('recording_id', 'status', 'reason'))):
    @classmethod
    def fields(cls):
        return RecordingOverride._fields

    def to_dict(self):
        return self._asdict()
