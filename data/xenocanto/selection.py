'''
Implements automatic selection of suitable recordings for the bird app.
'''

from xenocanto.models import Recording, AudioFile, AudioFileAnalysis


MIN_LENGTH = 3
MAX_LENGTH = 15


def is_candidate(recording):
    '''
    Returns whether the recording is potentially suitable based on its metadata.
    '''

    # Long enough?
    if recording.length_s < MIN_LENGTH:
        return False
    # Short enough?
    if recording.length_s > MAX_LENGTH:
        return False
    types = recording.types()
    # Has at least 'call' or 'song'?
    if not set(('call', 'song')).intersection(types):
        return False
    # Is not a baby?
    if 'juvenile' in types:
        return False

    return True


def preselect_recordings(xc_species):
    '''
    Select all recordings that meet our quality criteria purely based on metadata.
    '''
    recordings = Recording.objects.for_species(xc_species).order_by('id')
    return list(filter(is_candidate, recordings))


def suitability(recording):
    '''
    Returns a floating-point suitability score for the given recording (higher
    is better). Requires an audio file analysis to be available.
    '''
    suitability = 100.0
    # Clarity is not strictly between 0 and 100, but 100 works well here.
    suitability *= recording.audio_file.analysis.clarity / 100.0
    return suitability


def order_recordings(recordings):
    '''
    Orders recordings by descending suitability.
    '''
    return sorted(recordings, key=suitability, reverse=True)
