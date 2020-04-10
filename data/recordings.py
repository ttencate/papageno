'''
Classes representing metadata about audio recordings.
'''

import csv
import logging
import os.path

import natsort


class Recording:
    '''
    Metadata about a single recording. Stored internally as a flat dict for
    ease of serializing and deserializing.
    '''

    FIELD_NAMES = [
        'recording_id', 'gen', 'sp', 'ssp', 'en', 'rec', 'cnt', 'loc', 'lat',
        'lng', 'alt', 'type', 'url', 'file', 'file-name', 'sono-small',
        'sono-med', 'sono-large', 'sono-full', 'lic', 'q', 'length', 'time',
        'date', 'uploaded', 'also', 'rmk', 'bird-seen', 'playback-used'
    ]

    def __init__(self, internal_dict=None):
        '''
        Creates a new empty recording. If internal_dict is given, adopts that
        as its internal storage.
        '''
        self._dict = internal_dict or {field: None for field in Recording.FIELD_NAMES}

    @staticmethod
    def from_xc_json(json):
        '''
        Creates a recording from the parsed JSON object as returned by the
        xeno-canto API. Consumes the object passed to it!
        '''
        recording_dict = json

        recording_dict['recording_id'] = 'xc:' + recording_dict['id']
        recording_dict.pop('id')

        for sono_size, sono_url in recording_dict['sono'].items():
            recording_dict['sono-' + sono_size] = sono_url
        recording_dict.pop('sono')

        recording_dict['also'] = ';'.join(recording_dict['also'])

        return Recording(recording_dict)

    @property
    def recording_id(self):
        '''
        A unique identifier of the recording. Derived from from the xeno-canto
        catalogue number.
        '''
        return self._dict['recording_id']

    @property
    def scientific_name(self):
        '''
        Returns the scientific name of the recorded species, without the
        subspecies (if any).
        '''
        return f'{self._dict["gen"]} {self._dict["sp"]}'

    @property
    def lat_lon(self):
        '''
        A (latitude, longitude) tuple in WGS84 coordinates.
        '''
        try:
            return (float(self._dict['lat']), float(self._dict['lng']))
        except ValueError:
            return None

    @property
    def quality(self):
        '''
        Recording quality from 'A' to 'E'.
        '''
        return self._dict['q']

    @property
    def duration_seconds(self):
        '''
        The length of the recording in seconds.
        '''
        parts = self._dict['length'].split(':')
        seconds = int(parts.pop())
        if parts:
            seconds += 60 * int(parts.pop())
        if parts:
            seconds += 60 * 60 * int(parts.pop())
        assert not parts
        return seconds

    @property
    def background_species(self):
        '''
        A list of scientific names of background species present in the recording.
        '''
        return list(filter(None, self._dict['also'].split(';')))

    def as_dict(self):
        '''
        Returns the internal dictionary backing this Recording. Do not modify.
        '''
        return self._dict


class RecordingsList:
    '''
    A in-memory list of Recording objects, with file reading and writing
    functions.
    '''

    DEFAULT_FILE_NAME = os.path.join(os.path.dirname(__file__), 'sources', 'xc.csv')

    def __init__(self):
        '''
        Creates a new, empty list.
        '''
        self._by_recording_id = {}

    def load(self, file_name):
        '''
        Adds recordings from a CSV file into this list. There must not be any
        id conflicts. Raises FileNotFoundError if not found.
        '''
        logging.info(f'Loading recordings from {file_name}')
        with open(file_name, 'rt') as input_file:
            reader = csv.DictReader(input_file)
            for row in reader:
                recording = Recording(row)
                self.add_recording(recording)
        logging.info(f'Loaded {len(self)} recordings')

    def __len__(self):
        return len(self._by_recording_id)

    def __iter__(self):
        return iter(self._by_recording_id.values())

    def add_recording(self, recording, allow_replace=False):
        '''
        Adds a new recording to the list. Its id must not already be present.
        '''
        if not allow_replace and recording.recording_id in self._by_recording_id:
            raise ValueError(f'Recording with id {recording.recording_id} already present')
        self._by_recording_id[recording.recording_id] = recording

    def save(self, file_name):
        '''
        Saves the list to a CSV file.
        '''
        logging.info(f'Saving {len(self)} recordings to {file_name}')
        with open(file_name, 'wt') as output_file:
            writer = csv.DictWriter(output_file, Recording.FIELD_NAMES)
            writer.writeheader()
            for recording_id in natsort.natsorted(self._by_recording_id.keys()):
                recording = self._by_recording_id[recording_id]
                writer.writerow(recording.as_dict())
