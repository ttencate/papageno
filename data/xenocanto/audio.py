'''
Functions for analyzing audio files.
'''

import os.path

import numpy as np

from pydub import AudioSegment


def load_audio(file_name):
    '''
    Loads the given file as a pydub AudioSegment and returns it.
    '''
    return AudioSegment.from_file(file_name, os.path.splitext(file_name)[1][1:])


def preprocess_audio(segment):
    '''
    Returns a cleaned-up copy of the given AudioSegment.
    '''
    return segment.set_channels(1).remove_dc_offset().normalize()


def compute_clarity(segment):
    '''
    Returns a clarity score for the given AudioSegment, which is computed as
    the negation of the 5th percentile of dB volumes of 100ms segments. This
    assumes that the audio consists of background noise for at least 5% of the
    time.
    '''

    duration_ms = len(segment)
    slice_duration_ms = 100
    slice_volumes = []
    for i in range(0, duration_ms, slice_duration_ms):
        segment_slice = segment[i : i + slice_duration_ms]
        slice_db = segment_slice.dBFS
        slice_volumes.append(slice_db)
        # print('%6.02f  %s' % (slice_db, '#' * max(0, int(slice_db + 90))))
    slice_volumes = np.array(slice_volumes)
    slice_volumes.sort()
    clarity = -np.percentile(slice_volumes, 5)
    return clarity
