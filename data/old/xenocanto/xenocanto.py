'''
A set of functions to talk to the Xenocanto site.
'''

import glob
import json
import logging
import os
import os.path
import re
import urllib.parse

from bs4 import BeautifulSoup

from xenocanto.cache import get_response


# TODO replace by xenocanto.cache functions
def _get_cache_dir(subdir):
    cache_dir_name = os.path.join(os.path.dirname(__file__), 'cache', subdir)
    os.makedirs(cache_dir_name, exist_ok=True)
    return cache_dir_name


def _search_url(query_dict):
    scheme = 'https'
    hostname = 'www.xeno-canto.org'
    path = '/api/2/recordings'
    query = urllib.parse.urlencode(query_dict)
    return urllib.parse.urlunparse((scheme, hostname, path, None, query, None))


def find_recordings(query):
    '''
    Returns an iterable of JSON objects, one per recording, as returned by the
    XC API (https://www.xeno-canto.org/article/153). Handles pagination.

    See https://www.xeno-canto.org/help/search for query syntax.
    '''
    page = 1
    while True:
        url = _search_url({'query': query, 'page': str(page)})
        response = get_response(url).json()
        for recording in response['recordings']:
            yield recording
        if response['page'] >= response['numPages']:
            break
        page += 1


def find_recordings_cached(query):
    '''
    Gets search results for the given query as a list of JSON objects. Uses
    cached results if possible.
    '''
    cache_dir_name = _get_cache_dir('queries')
    cache_file_name = os.path.join(cache_dir_name, '%s.json' % query)
    try:
        with open(cache_file_name, 'rb') as cache_file:
            return json.load(cache_file)
    except FileNotFoundError:
        pass

    recordings = list(find_recordings(query))
    with open(cache_file_name, 'wt') as cache_file:
        json.dump(recordings, cache_file, indent=2)
    logging.info('Wrote %d recordings to %s', len(recordings), cache_file_name)
    return recordings


def _download_recording(recording_file):
    response = get_response(recording_file)
    return response.headers['content-type'], response.content


def download_recording_cached(recording_id, recording_file):
    '''
    Downloads the given recording if needed, and returns the file name on disk.
    '''
    cache_dir_name = _get_cache_dir('audio')
    cache_file_names = glob.glob(os.path.join(cache_dir_name,
                                              '%02d' % (int(recording_id) % 100),
                                              '%s.*' % recording_id))
    if len(cache_file_names) > 1:
        raise RuntimeError('Amgiguous cache for XC%s: %s' % (recording_id, ', '.join(cache_file_names)))
    elif len(cache_file_names) == 1:
        logging.info('Returning %s from cache', cache_file_names[0])
        return cache_file_names[0]
    else:
        content_type, data = _download_recording(recording_file)
        extension = {
            'audio/mpeg': 'mp3',
        }[content_type]
        cache_file_name = os.path.join(cache_dir_name, '%s.%s' % (recording_id, extension))
        logging.info('Downloaded %s (%d kB)', cache_file_name, round(len(data) / 1024))
        with open(cache_file_name, 'wb') as cache_file:
            cache_file.write(data)
        return cache_file_name


def fetch_metadata(recording_id):
    '''
    Fetches, parses and returns metadata about a given recording.
    '''
    url = 'https://www.xeno-canto.org/%s' % recording_id
    response = get_response(url)
    try:
        return _parse_metadata(url, response.content)
    except Exception as ex:
        raise RuntimeError('Failed to parse page at URL %s' % url) from ex


def _parse_metadata(url, content): # pylint: disable=too-many-locals
    soup = BeautifulSoup(content, 'html.parser')

    def get_table(title):
        for sibling in soup.find('h2', string=re.compile(title)).next_siblings:
            if hasattr(sibling, 'name') and sibling.name == 'table':
                return sibling
        return None
    def get_table_cell(table, key, regexp=None, convert=None):
        result = table.find('td', string=re.compile(key)).next_sibling.get_text(strip=True)
        if result == 'Not specified':
            return None
        if regexp:
            match = regexp.search(result)
            if not match:
                return None
            result = match.group(1)
        if convert:
            result = convert(result)
        return result
    def absolute_url(relative_url):
        return urllib.parse.urljoin(url, relative_url)

    recording_data = get_table('Recording data')
    audio_file_properties = get_table('Audio file properties')
    sound_characteristics = get_table('Sound characteristics')

    int_re = re.compile(r'(\d+)')
    float_re = re.compile(r'(\d+|\d*\.\d+|\d+\.\d*)')
    time_re = re.compile(r'(\d\d:\d\d)')
    date_re = re.compile(r'(\d\d\d\d-\d\d-\d\d)')

    name = soup.find(itemprop='name')
    species = soup.find(class_='sci-name').string.split()
    quality = soup.find(id=re.compile(r'^rating-.*$'), class_='selected')
    sonogram_link = soup.find('a', string=re.compile(r'Download full-length sonogram'))

    return {
        # Attributes from the API (https://www.xeno-canto.org/article/153)
        'id': re.match(r'XC(\d+)', name.contents[0]).group(1),
        'gen': species[0],
        'sp': species[1],
        'ssp': species[2] if len(species) >= 3 else None,
        'en': name.find('a').string.strip(),
        'rec': get_table_cell(recording_data, 'Recordist'),
        'cnt': get_table_cell(recording_data, 'Country'),
        'loc': get_table_cell(recording_data, 'Location'),
        'lat': get_table_cell(recording_data, 'Latitude', convert=float),
        'lng': get_table_cell(recording_data, 'Longitude', convert=float),
        'type': get_table_cell(sound_characteristics, 'Type'),
        'file': absolute_url(soup.find('a', string=re.compile(r'Download audio file'))['href']),
        'lic': absolute_url(soup.find(string=re.compile(r'^\s*Creative Commons')).parent['href']),
        'url': url,
        'q': quality.string if quality else None,
        'time': get_table_cell(recording_data, 'Time', regexp=time_re),
        'date': get_table_cell(recording_data, 'Date', regexp=date_re),

        # Attributes not present in the API.
        'sonogram_url': absolute_url(sonogram_link['href']) if sonogram_link else None,
        'elevation_m': get_table_cell(recording_data, 'Elevation', regexp=int_re, convert=int),
        'length_s': get_table_cell(audio_file_properties, 'Length', regexp=float_re, convert=float),
        'sampling_rate_hz': get_table_cell(audio_file_properties, 'Sampling rate', regexp=int_re, convert=int),
        'bitrate_bps': get_table_cell(audio_file_properties, 'Bitrate of mp3', regexp=int_re, convert=int),
        'channels': get_table_cell(audio_file_properties, 'Channels', regexp=int_re, convert=int),
        'volume': get_table_cell(sound_characteristics, 'Volume'),
        'speed': get_table_cell(sound_characteristics, 'Speed'),
        'pitch': get_table_cell(sound_characteristics, 'Pitch'),
        'sound_length': get_table_cell(sound_characteristics, 'Length'),
        'number_of_notes': get_table_cell(sound_characteristics, 'Number of notes'),
        'variable': get_table_cell(sound_characteristics, 'Variable'),
    }


def fetch_metadata_cached(recording_id):
    '''
    Returns a JSON object with metadata about the given recording. Downloads it
    only if it's not in the cache.
    '''
    cache_dir_name = _get_cache_dir('metadata')
    cache_file_name = os.path.join(cache_dir_name,
                                   '%02d' % (int(recording_id) % 100),
                                   '%s.json' % recording_id)
    try:
        with open(cache_file_name, 'rb') as cache_file:
            return json.load(cache_file)
    except FileNotFoundError:
        pass

    metadata = fetch_metadata(recording_id)
    with open(cache_file_name, 'wt') as cache_file:
        json.dump(metadata, cache_file, indent=2)
    logging.info('Wrote metadata for XC%s to %s', recording_id, cache_file_name)
    return metadata