'''
Selection and trimming of recordings.
'''

import hashlib
import io
import logging

from sqlalchemy import or_

from analysis import Analysis, load_sound
import lazy
from recordings import Recording


'''
Types of recordings that we allow. Any other type tag will cause the recording
to be rejected.
'''
ALLOWED_TYPES = set([
    'song', 'dawn song', 'subsong', 'canto',
    'call', 'calls', 'flight call', 'flight calls', 'nocturnal flight call', 'alarm call',
    # 'begging call', 'drumming'
    'male', 'female', 'sex uncertain', 'adult',
])

'''
Maximum volume level of background noise (in dB, where the maximum is 0 dB) for
a recording to be considered suitable.
'''
MAXIMUM_NOISE_VOLUME_DB = -25.0


class RecordingSelection:
    '''
    Selects recordings for inclusion in the app, for a single species.
    '''

    def __init__(self, species, session, recordings_fetcher, recording_overrides):
        self.species = species
        self._session = session
        self._recordings_fetcher = recordings_fetcher
        self._recording_overrides = recording_overrides

    @property
    @lazy.cached
    def candidate_recordings(self):
        '''
        Returns a list of `Recording` objects that are potentially suitable for
        inclusion in the app: no background species listed, not too long, not
        too short, and not blacklisted.

        They are returned in pseudo-random, reproducible order.
        '''
        scientific_name = self.species.scientific_name
        logging.debug(f'Loading recordings for {scientific_name}')
        recordings = [
            recording
            for recording in self._session.query(Recording).filter(
                Recording.scientific_name == scientific_name,
                Recording.url != None, # pylint: disable=singleton-comparison
                Recording.url != '',
                Recording.audio_url != None, # pylint: disable=singleton-comparison
                Recording.audio_url != '',
                or_(
                    Recording.background_species == None, # pylint: disable=singleton-comparison
                    Recording.background_species == '',
                    Recording.background_species == '[]',
                ),
                Recording.length_seconds >= 5,
                Recording.length_seconds <= 120,
            )
            if self._recording_overrides[recording.recording_id].status != 'blacklist' and
                set(recording.types).issubset(ALLOWED_TYPES)
        ]
        recordings.sort(key=lambda r: md5(r.recording_id))
        return recordings

    def analyze_recordings(self):
        '''
        Generator that returns `Analysis` objects.
        '''
        recordings = sorted(self.candidate_recordings, key=lambda r: md5(r.recording_id))
        for recording in recordings:
            sound = load_recording(recording, self._recordings_fetcher)
            yield Analysis(recording, sound)

    def rejection_reasons(self, analysis):
        '''
        Returns a list of human-readable reasons why a recording should be
        rejected, based on its analysis. Empty if suitable.
        '''
        reasons = []
        if analysis.perceptual_noise_volume_db > MAXIMUM_NOISE_VOLUME_DB:
            reasons.append(f'noise volume {analysis.perceptual_noise_volume_db:.1f} > {MAXIMUM_NOISE_VOLUME_DB:.1f}')
        return reasons

    def suitable_recordings(self):
        '''
        Generator that returns tuples of `(Recording, Analysis)` objects for
        recordings that are suitable for inclusion.
        '''
        for analysis in self.analyze_recordings():
            rejection_reasons = self.rejection_reasons(analysis)
            if rejection_reasons:
                logging.debug(f'Rejecting {analysis.recording.recording_id}: {", ".join(rejection_reasons)}')
            else:
                yield analysis


def load_recording(recording, recordings_fetcher):
    '''
    Fetches and decodes the audio data for a single `Recording`. Returns a
    numpy array of samples.
    '''
    data = recordings_fetcher.fetch_cached(recording.audio_url)
    sound = load_sound(io.BytesIO(data))
    return sound


def md5(string):
    '''
    Computes the MD5 hash of a string.
    '''
    m = hashlib.md5()
    m.update(string.encode('utf-8'))
    return m.digest()
