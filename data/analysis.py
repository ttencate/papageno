'''
Fancy analysis algorithms.

References:

[1] 2018 Bird Audio Detection Challenge
    http://c4dm.eecs.qmul.ac.uk/events/badchallenge_results/

[2] Kahl, S. (2020). "Identifying Birds by Sound: Large-scale Acoustic Event
    Recognition for Avian Activity Monitoring." Dissertation. Chemnitz
    University of Technology, Chemnitz, Germany.
    https://monarch.qucosa.de/api/qucosa%3A36986/attachment/ATT-0/

[3] "Automatic identification of bird species based on sinusoidal modeling of
    syllables". Härmä, 2003.
    ../literature/harma_2003.pdf

[4] "Analyzing bird song syllables on the Self-Organizing Map". Somervuo and
    Härmä, 2003.
    ../literature/somervuo_2003.pdf

[5] "Bird song recognition based on syllable pair histograms". Somervuo and
    Härmä, 2004.
    ../literature/somervuo_2004.pdf

[6] "Automatic recognition of Bird Species by Their Sound". Fagerlund, Master's
    thesis, 2004.
    ../literature/fagerlund_2004.pdf
'''

import hashlib
import logging

import librosa
import librosa.feature
import numpy as np
import pydub
import scipy.signal

import lazy


'''
Sample rate used for analysis.
'''
SAMPLE_RATE = 44100

'''
Window size for FFTs, in samples.

Härmä [3] uses a size of 256 without arguing why. In section 2.4.3. "Adaption
to avian acoustic monitoring", page 58, Kahl [2] recommends a window size of
512 samples at 48 kHz with an overlap of 50% (256 samples) using a Hann window
function.
'''
FFT_WINDOW_SIZE = 512

'''
Length of the windowed signal for the FFT after padding with zeros.

Härmä [3] uses a size of 1024, which would result in twice as many frequency
bins as Kahl [2] for no obvious advantage.
'''
# N_FFT = 1024 # Härmä
N_FFT = 512

'''
Hop length for spectrogram FFTs. See above.

Härmä [3] uses a step of 64 samples (75% overlap on 256); Kahl [2] uses 256
(50% overlap on 512).
'''
# FFT_HOP_LENGTH = 64 # Härmä
FFT_HOP_LENGTH = 256

'''
Shape of the windowing function for FFT.

Kahl[2] uses a Hann window. Härmä [3] uses a Kaiser window with alpha = 8.
Scipy requires a parameter named `beta`, but according to the scipy docs, "some
authors use `alpha = beta / pi`"; hence, `beta = alpha * pi`.
'''
# FFT_WINDOW_SPEC = ('kaiser', 8 * np.pi) # Härmä
FFT_WINDOW_SHAPE = 'hann'

'''
RMS of the window shape. Used to correct RMS calculations from spectrograms, to
make the result independent of the window shape.
'''
WINDOW_RMS = np.sqrt(np.mean(scipy.signal.get_window(FFT_WINDOW_SHAPE, N_FFT)**2))

'''
Quantile of volume used to detect background noise. We assume that the bird
does not vocalize on any frequency for more than this fraction of time. If it
does: too bad, the recording will be discarded as being too noisy.
'''
NOISE_QUANTILE = 0.5

'''
Sigma (expressed in frames) of the Gaussian kernel used to smooth the
spectrogram along the time axis before noise subtraction.
'''
SPECTROGRAM_SMOOTHING_SIGMA = 10.0

'''
Weighting to use for perceptual loudness:
https://en.wikipedia.org/wiki/A-weighting. This weighting was empirically
determined (out of A, B, C, D, Z) to give the best ranking of perceived volume.
'''
PERCEPTUAL_WEIGHTING_KIND = 'A'

'''
Volume above which a consecutive audio segment must remain to be considered a
potential vocalization. In decibels relative to the peak level.
'''
VOCALIZATION_TRIGGER_THRESHOLD_DB = -30

'''
Volume above which a consecutive audio segment must peak at least once to be
considered a vocalization. In decibels relative to the peak level.
'''
VOCALIZATION_KEEP_THRESHOLD_DB = -15

'''
Vocalizations closer together than this amount will be merged into one.
'''
MIN_VOCALIZATION_SEPARATION_SECONDS = 0.3

'''
Vocalizations shorter than this will be discarded.
'''
MIN_VOCALIZATION_DURATION_SECONDS = 0.05


class Analysis:
    '''
    Contains analysis functions for a single recording. Cheap to create,
    because every field is lazily evaluated.
    '''

    def __init__(self, sound):
        '''
        Creates a new `Analysis` from an array of samples, as returned by the
        `load_sound` function.
        '''
        self.sound = sound

    @property
    @lazy.cached
    def spectrogram(self):
        '''
        Computes the amplitude spectrogram of the sound on a linear frequency scale
        (straight STFT). The result is an _amplitude_ spectrogram; to get a
        _power_ spectrogram the values need to be squared.

        The winners of the 2018 Bird Audio Detection Challenge [1] used a mel
        frequency scale, but Härmä et al [3, 4, 5] use a linear scale. We
        return a linear spectrogram here and convert as needed (but to a log
        scale, not a mel scale).
        '''
        return np.abs(librosa.stft(
            self.sound,
            n_fft=N_FFT,
            win_length=FFT_WINDOW_SIZE,
            hop_length=FFT_HOP_LENGTH,
            window=FFT_WINDOW_SHAPE))

    # TODO remove if unused
    @property
    @lazy.cached
    def frequency_bins(self):
        '''
        Center frequencies corresponding to the rows (frequency bins) in the
        `spectrogram`. Contrast this with `librosa.fft_frequencies`, which
        returns the bottom of each bin (giving 0 for the first bin, which can
        be problematic in functions like `librosa.perceptual_weighting`).
        '''
        num_bins = 1 + N_FFT // 2
        return (np.arange(0, num_bins) + 0.5) / (num_bins - 1) * SAMPLE_RATE / 2

    @property
    @lazy.cached
    def noise_profile(self):
        '''
        Computes the noise level along each frequency band by computing a
        low-quantile volume level for each band. For a spectrogram of shape `(freq,
        time)`, this returns an array of shape `(freq, 1)` so that it can easily be
        plotted and/or broadcast across the same spectrogram later.
        '''
        # TODO Account for fades? These often occur at the start and end of the recording,
        # but e.g. xc:130997 has fades in the middle! This makes the computed noise
        # level a bit lower than it should be.
        noise_profile = np.quantile(self.spectrogram, q=NOISE_QUANTILE, axis=1)
        return np.reshape(noise_profile, (self.spectrogram.shape[0], 1))

    @property
    @lazy.cached
    def perceptual_noise_volume_db(self):
        '''
        Returns the perceptual volume of noise in decibels. The reference
        (maximum) volume is assumed to be 1.0, which is mapped to 0 dB.

        This is used to determine the suitability of the recording for
        inclusion in the app.
        '''
        # We need to square the noise profile because `perceptual_weighting`
        # expects a power spectrum, not an amplitude spectrum.
        weighted_noise_profile_db = librosa.perceptual_weighting(
            self.noise_profile**2, self.frequency_bins, kind=PERCEPTUAL_WEIGHTING_KIND)
        weighted_noise_profile = librosa.db_to_amplitude(weighted_noise_profile_db)
        amplitude = rms_amplitude(weighted_noise_profile)
        return np.asscalar(librosa.amplitude_to_db(amplitude))

    @property
    @lazy.cached
    def volume_db(self):
        '''
        Returns the volume in dB for each frame.
        '''
        amplitude = rms_amplitude(self.spectrogram)
        return librosa.amplitude_to_db(amplitude)

    @property
    @lazy.cached
    def filtered_spectrogram(self):
        '''
        Returns the spectrogram smoothed over the time axis, with the noise
        profile subtracted. The smoothing is useful because the noise itself
        tends to be noisy, so some frames will peak above the noise profile
        while some are below.
        '''
        smoothed_spectrogram = self.spectrogram
        for i in range(smoothed_spectrogram.shape[0]):
            smoothed_spectrogram[i] = scipy.ndimage.gaussian_filter(
                smoothed_spectrogram[i], SPECTROGRAM_SMOOTHING_SIGMA)
        # Not sure if we need to square and then sqrt here, but it intuitively
        # makes more sense to subtract powers than amplitudes.
        return np.sqrt(np.maximum(0, smoothed_spectrogram**2 - self.noise_profile**2))

    @property
    @lazy.cached
    def perceptual_filtered_volume_db(self):
        '''
        Returns the perceptual volume in dB for each frame, normalized so that
        the peak is at 0 dB.
        '''
        weighted_spectrogram_db = librosa.perceptual_weighting(
            self.filtered_spectrogram**2, self.frequency_bins, kind=PERCEPTUAL_WEIGHTING_KIND)
        weighted_spectrogram = librosa.db_to_amplitude(weighted_spectrogram_db)
        weighted_amplitude = rms_amplitude(weighted_spectrogram)
        weighted_amplitude_db = librosa.amplitude_to_db(weighted_amplitude)
        return weighted_amplitude_db - np.amax(weighted_amplitude_db)

    @property
    @lazy.cached
    def raw_vocalizations(self):
        '''
        Detects vocalizations in the volume curve. A vocalization is a
        consecutive range of time slices in which the volume remains some
        minimum "trigger" threshold above the `perceptual_noise_volume_db`, and
        exceeds some maximum "keep" threshold at least once.

        Vocalization are returned as a list of tuples `(start, end)` where `start`
        and `end` are in seconds.
        '''
        trigger_threshold_db = VOCALIZATION_TRIGGER_THRESHOLD_DB
        keep_threshold_db = VOCALIZATION_KEEP_THRESHOLD_DB

        vocalizations = []
        start = None
        keep = False
        volumes_db = self.perceptual_filtered_volume_db
        for i, volume_db in enumerate(volumes_db):
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
            vocalizations.append((start, len(volumes_db)))

        return [
            (frames_to_time(start), frames_to_time(end))
            for (start, end) in vocalizations
        ]

    @property
    @lazy.cached
    def vocalizations(self):
        '''
        Merges consecutive vocalizations if they are close together. Useful for
        rapid trills and such. Then removes all vocalizations that are very
        short and probably artifacts, and returns the result.
        '''
        merged_vocalizations = []
        for start, end in self.raw_vocalizations:
            if merged_vocalizations and start <= merged_vocalizations[-1][1] + MIN_VOCALIZATION_SEPARATION_SECONDS:
                merged_vocalizations[-1] = (merged_vocalizations[-1][0], end)
            else:
                merged_vocalizations.append((start, end))

        return [
            Vocalization(self, start, end)
            for (start, end) in merged_vocalizations
            if end - start >= MIN_VOCALIZATION_DURATION_SECONDS
        ]


class Vocalization:
    '''
    Represents a single vocalization, extracted from a full recording.
    '''

    def __init__(self, analysis, start, end):
        self.analysis = analysis
        start_sample, end_sample = librosa.time_to_samples([start, end], sr=SAMPLE_RATE)
        self.sound = analysis.sound[start_sample:end_sample]
        self.start = start
        self.end = end
        self.duration = end - start

    @property
    @lazy.cached
    def spectrogram(self):
        '''
        Extract of `Analysis.spectrogram`.
        '''
        start_frame, end_frame = time_to_frames([self.start, self.end])
        return self.analysis.spectrogram[:, start_frame:end_frame]


def load_sound(file_obj):
    '''
    Loads a sound from a file-like object representing MP3 data, transforms it
    to a common format for further processing, and normalizes it. Returns a
    numpy array of floating point samples in the range [-1, 1] with a rate of
    `SAMPLE_RATE`.

    Note that we assume that the DC component is zero.
    '''
    # librosa knows how to load MP3 files too, but somehow it gives wrong
    # results! For example, loading https://www.xeno-canto.org/82572 gives a
    # clip that is indeed ~1 minute long, but has higher pitch than the
    # original.
    sound = pydub.AudioSegment.from_file(file_obj, format='mp3')
    sound = sound.set_channels(1).set_frame_rate(SAMPLE_RATE)
    samples = np.array(sound.get_array_of_samples())
    return samples / np.amax(np.abs(samples))


def rms_amplitude(spectrogram):
    '''
    Computes the RMS amplitude from an amplitude spectrogram. This function
    (unlike `librosa.feature.rms`) compensates for the window shape that was
    used when creating the STFT, so the result does not depend on the choice of
    window shape.

    To get _power_, the returned value needs to be squared.
    '''
    spectrogram_rms = librosa.feature.rms(S=spectrogram, frame_length=N_FFT, hop_length=FFT_HOP_LENGTH)
    return spectrogram_rms[0] / WINDOW_RMS


def time_to_frames(time):
    return librosa.time_to_frames(time, sr=SAMPLE_RATE, hop_length=FFT_HOP_LENGTH)


def frames_to_time(frames):
    return librosa.frames_to_time(frames, sr=SAMPLE_RATE, hop_length=FFT_HOP_LENGTH)


def time_to_samples(time):
    return librosa.time_to_samples(time, sr=SAMPLE_RATE)


def samples_to_time(samples):
    return librosa.samples_to_time(samples, sr=SAMPLE_RATE)
