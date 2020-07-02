'''
Fancy analysis algorithms.
'''

import hashlib
import logging

import imageio # TODO port to pillow
import numpy as np


_ALLOWED_TYPES = set([
    'song', 'dawn song', 'subsong', 'canto',
    'call', 'calls', 'flight call', 'flight calls', 'nocturnal flight call', 'alarm call',
    # 'begging call', 'drumming'
    'male', 'female', 'sex uncertain', 'adult',
])


def recording_quality(recording):
    '''
    The main quality metric used to select which recordings will go into the app.
    Returns a tuple that compares larger if the quality is better.
    '''
    quality_score = 'EDCBA'.find(recording.quality or 'E')
    allowed_types_score = -len(set(recording.types).difference(_ALLOWED_TYPES))
    background_species_score = -len(recording.background_species)
    sonogram_quality_score = recording.sonogram_analysis.sonogram_quality
    length_score = min(0, recording.length_seconds - 2)
    # Hash the recording_id for a stable pseudo-random tie breaker.
    hasher = hashlib.sha1()
    hasher.update(str(recording.recording_id).encode('utf-8'))
    recording_id_hash = hasher.digest()
    return (
        quality_score,
        allowed_types_score,
        background_species_score,
        sonogram_quality_score,
        length_score,
        recording_id_hash,
    )


def sonogram_quality(recording_id, sonogram):
    '''
    Determines sound quality on the basis of a small sonogram image. Higher is better.
    '''
    try:
        full_img = imageio.imread(sonogram, pilmode='L')
    except Exception as ex: # pylint: disable=broad-except
        logging.error(f'Error decoding sonogram of {len(sonogram)} bytes '
                      f'of recording {recording_id}: {ex}')
        return -999999
    img = _crop_white(full_img)
    inverted_img = 255 - img
    # For each row (frequency band), find the 30%ile level. So we assume that
    # the bird produces sound at this frequency no more than 70% of the time.
    # This gives an indication of the level of background noise on that
    # frequency band.
    row_level = np.percentile(inverted_img, 30, axis=1)
    # Find the maximum noise level across all frequency bands.
    noise_level = np.amax(row_level)
    noise_score = (255 - noise_level)**2
    # We want some signal too, not just absence of noise. Ideally we have some
    # loud and some quiet periods, so we take the average over columns, then
    # the standard deviation of those averages.
    signal_strength = np.amax(inverted_img, axis=0)
    signal_score = np.std(signal_strength)
    # Both scores need to be as high as possible, but they are not within the
    # same range, so we cannot use the maximum. Take the product instead.
    return signal_score * noise_score

def _crop_white(img):
    '''
    Sonograms shorter than 10 seconds are full white on the right side.
    '''
    last_nonwhite_col = 0
    for col in range(img.shape[1]):
        # Iterate backwards because usually non-white pixels are encountered at the bottom.
        col_is_white = all(
            img[row, col] == 255
            for row in range(img.shape[0] - 1, -1, -1)
        )
        if not col_is_white:
            last_nonwhite_col = col
    return img[:, :last_nonwhite_col + 1]
