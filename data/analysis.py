'''
Fancy analysis algorithms.
'''

import hashlib
import logging
import tempfile
import warnings

import imageio # TODO port to pillow
import librosa
import librosa.feature
import numpy as np
import pydub


# False positive lint. pylint: disable=pointless-string-statement
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
Sample rate used for analysis.
'''
SAMPLE_RATE = 44100

'''
Bits per sample used for analysis. Must be a multiple of 8.
'''
BITS_PER_SAMPLE = 16

'''
Window size for FFTs, in samples.

In section 2.4.3. "Adaption to avian acoustic monitoring", page 58, Kahl [1]
recommends a window size of 512 samples at 48 kHz with an overlap of 50% (256
samples) using a Hann window function. That is for a neural network, but we can
reasonably expect it to work here as well.

[1] Kahl, S. (2020). "Identifying Birds by Sound: Large-scale Acoustic Event
Recognition for Avian Activity Monitoring." Dissertation. Chemnitz University
of Technology, Chemnitz, Germany.
https://monarch.qucosa.de/api/qucosa%3A36986/attachment/ATT-0/
'''
FFT_WINDOW_SIZE = 512

'''
Hop length for spectrogram FFTs. See above.
'''
FFT_HOP_LENGTH = FFT_WINDOW_SIZE // 2

'''
Number of mel frequency buckets used when creating spectrogram.
'''
NUM_MELS = 64

'''
Quantile of volume used to detect background noise.
'''
NOISE_QUANTILE = 0.2

'''
Volume above which a consecutive audio segment must remain to be considered a
potential vocalization. In decibels relative to the background noise level.
'''
VOCALIZATION_TRIGGER_THRESHOLD_DB = 10

'''
Volume above which a consecutive audio segment must peak at least once to be
considered a vocalization. In decibels relative to the background noise level.
'''
VOCALIZATION_KEEP_THRESHOLD_DB = 20

'''
Vocalizations closer together than this amount will be merged into one.
'''
MIN_VOCALIZATION_SEPARATION_SECONDS = 0.3

'''
Vocalizations shorter than this will be discarded.
'''
MIN_VOCALIZATION_DURATION_SECONDS = 0.05


def recording_quality(recording):
    '''
    The main quality metric used to select which recordings will go into the app.
    Returns a tuple that compares larger if the quality is better.
    '''
    quality_score = 'EDCBA'.find(recording.quality or 'E')
    allowed_types_score = -len(set(recording.types).difference(ALLOWED_TYPES))
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


def load_sound(file_obj):
    '''
    Loads a sound from a file-like object representing MP3 data, and transforms
    it to a common format for further processing. Returns a numpy array of
    floating point samples with a rate of `SAMPLE_RATE`.
    '''
    # librosa knows how to load MP3 files too, but somehow it gives wrong
    # results! For example, loading https://www.xeno-canto.org/82572 gives a
    # clip that is indeed ~1 minute long, but has higher pitch than the
    # original.
    sound = pydub.AudioSegment.from_file(file_obj, format='mp3')
    sound = sound.set_channels(1).set_frame_rate(SAMPLE_RATE).set_sample_width(BITS_PER_SAMPLE // 8)
    return np.array(sound.get_array_of_samples()) / (2**(BITS_PER_SAMPLE - 1))


def mel_spectrogram(sound):
    '''
    Computes the spectrogram of the given sound (sample array), using a mel
    frequency scale. The resulting spectrogram is normalized so that its
    maximum value is 1 (unless it's all zero).

    We use a mel spectrogram because the winners of the 2018 Bird Audio
    Detection Challege [1] did so too. They got a lot fancier of course, with
    deep learning and such, but it shows that the necessary information is
    somehow contained in the mel spectrogram.

    [1] http://c4dm.eecs.qmul.ac.uk/events/badchallenge_results/
    '''
    power = librosa.feature.melspectrogram(
        sound,
        sr=SAMPLE_RATE,
        n_fft=FFT_WINDOW_SIZE,
        hop_length=FFT_HOP_LENGTH,
        n_mels=NUM_MELS)
    max_power = np.amax(power)
    return power / np.amax(power) if max_power > 0 else power


def noise_profile(mel_spectrogram):
    '''
    Computes the noise level along each frequency band by computing a
    low-quantile volume level for each band. For a spectrogram of shape `(freq,
    time)`, this returns an array of shape `(freq, 1)` so that it can easily be
    plotted and/or broadcast across the same spectrogram later.
    '''
    # TODO Account for fades. These often occur at the start and end of the recording,
    # but e.g. xc:130997 has fades in the middle! This makes the computed noise
    # level a bit lower than it should be.
    noise_profile = np.quantile(mel_spectrogram, q=NOISE_QUANTILE, axis=1)
    return np.reshape(noise_profile, (mel_spectrogram.shape[0], 1))


def noise_volume_db(noise_profile):
    '''
    Given a noise profile from the `noise_profile` function, returns the volume
    level in decibels. The reference (maximum) volume is assumed to be 1.0,
    which is mapped to 0 dB.
    '''
    return librosa.power_to_db(np.sum(noise_profile))


def time_to_frames(time):
    return librosa.time_to_frames(time, sr=SAMPLE_RATE, hop_length=FFT_HOP_LENGTH)


def frames_to_time(frames):
    return librosa.frames_to_time(frames, sr=SAMPLE_RATE, hop_length=FFT_HOP_LENGTH)


def filtered_volume_db(mel_spectrogram, noise_profile):
    '''
    Subtracts the given noise profile from the spectrogram, then computes and
    returns the remaining volume (as power, not dB) for each time slice.
    '''
    filtered_spectrogram = mel_spectrogram - noise_profile
    filtered_volume = np.sum(filtered_spectrogram, axis=0)
    filtered_volume_db = librosa.power_to_db(filtered_volume)
    return filtered_volume_db


def vocalizations(filtered_volume_db, noise_volume_db):
    '''
    Detects vocalizations in the given volume curve. A vocalization is a
    consecutive range of time slices in which the volume remains some minimum
    "trigger" threshold above the `noise_volume_db`, and exceeds some maximum
    "keep" threshold at least once.

    Vocalization are returned as a list of tuples `(start, end)` where `start`
    and `end` are in seconds.
    '''
    trigger_threshold_db = noise_volume_db + VOCALIZATION_TRIGGER_THRESHOLD_DB
    keep_threshold_db = noise_volume_db + VOCALIZATION_KEEP_THRESHOLD_DB

    vocalizations = []
    start = None
    keep = False
    for i, volume_db in enumerate(filtered_volume_db):
        if volume_db >= trigger_threshold_db:
            if start is None:
                start = i
            if volume_db >= keep_threshold_db:
                keep = True
        else:
            if start is not None:
                if keep:
                    vocalizations.append((start, i))
                start = None
                keep = False
    if start is not None and keep:
        vocalizations.append((start, len(filtered_volume_db)))

    return [
        (frames_to_time(start), frames_to_time(end))
        for (start, end) in vocalizations
    ]


def merge_vocalizations(vocalizations):
    '''
    Merges consecutive vocalizations if they are close together. Useful for
    rapid trills and such.
    '''
    merged_vocalizations = []
    for start, end in vocalizations:
        if merged_vocalizations and start <= merged_vocalizations[-1][1] + MIN_VOCALIZATION_SEPARATION_SECONDS:
            merged_vocalizations[-1] = (merged_vocalizations[-1][0], end)
        else:
            merged_vocalizations.append((start, end))
    return merged_vocalizations


def filter_vocalizations(vocalizations):
    '''
    Removes all vocalizations that are very short and probably artifacts.
    '''
    return [
        (start, end)
        for (start, end) in vocalizations
        if end - start >= MIN_VOCALIZATION_DURATION_SECONDS
    ]
