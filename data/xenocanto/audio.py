'''
Functions for analyzing audio files.
'''

import os.path
import subprocess
import tempfile

import numpy as np

from pydub import AudioSegment
import pydub.playback


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


def compute_clarity(segment, percentile=10, ignore=1000):
    '''
    Returns a clarity score for the given AudioSegment, which is computed as
    the negation of the 10th percentile of dB volumes of 100ms segments. This
    assumes that the audio consists of background noise for at least 10% of the
    time. It disregards the first and last 1s of audio to deal with fades.
    '''

    duration_ms = len(segment)
    if duration_ms < 2 * ignore:
        ignore = duration_ms // 3
    slice_duration_ms = 100
    slice_volumes = []
    for i in range(ignore, duration_ms - ignore, slice_duration_ms):
        segment_slice = segment[i : i + slice_duration_ms]
        slice_db = segment_slice.dBFS
        # Ignore perfect silence, which was probably added in software.
        if slice_db >= -150.0:
            slice_volumes.append(slice_db)
        # print('%6.02f  %s' % (slice_db, '#' * max(0, int(slice_db + 90))))
    slice_volumes = np.array(slice_volumes)
    slice_volumes.sort()
    clarity = -np.percentile(slice_volumes, percentile)
    return clarity


def play(segment):
    '''
    Plays the given segment, blocking until done. Q will stop playback.
    '''
    # Copied from pydub.playback.play so we could use mplayer instead of
    # ffplay, for additional quietness.
    with tempfile.NamedTemporaryFile('w+b', suffix='.wav') as f:
        segment.export(f.name, 'wav')
        subprocess.call(['mplayer', '-really-quiet', f.name])
