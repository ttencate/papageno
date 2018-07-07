import collections
import glob
import json
import logging
import os
import os.path
import re
import urllib.parse

import requests


def make_url(query_dict):
    SCHEME = 'https'
    HOSTNAME = 'www.xeno-canto.org'
    PATH = '/api/2/recordings'
    query = urllib.parse.urlencode(query_dict)
    return urllib.parse.urlunparse((SCHEME, HOSTNAME, PATH, None, query, None))


def find_recordings(query):
    '''
    Returns an iterable of JSON objects, one per recording, as returned by the
    XC API (https://www.xeno-canto.org/article/153). Handles pagination.

    See https://www.xeno-canto.org/help/search for query syntax.
    '''
    page = 1
    while True:
        url = make_url({'query': query, 'page': str(page)})
        response = requests.get(url)
        response.raise_for_status()
        json = response.json()
        for recording in json['recordings']:
            yield recording
        if json['page'] >= json['numPages']:
            break
        page += 1


def get_cache_dir(subdir):
    cache_dir_name = os.path.join(os.path.dirname(__file__), 'cache', subdir)
    os.makedirs(cache_dir_name, exist_ok=True)
    return cache_dir_name


def find_recordings_cached(query):
    cache_dir_name = get_cache_dir('queries')
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


def download_recording(recording):
    url = recording['file']
    if url.startswith('//'):
        url = 'https:' + url
    response = requests.get(url)
    try:
        response.raise_for_status()
    except Exception as ex:
        raise RuntimeError('Error downloading %s' % url) from ex
    return response.headers['content-type'], response.content


def download_recording_cached(recording):
    cache_dir_name = get_cache_dir('recordings')
    cache_file_names = glob.glob(os.path.join(cache_dir_name, '%s.*' % recording['id']))
    if len(cache_file_names) > 1:
        raise RuntimeError('Amgiguous cache for XC%s: %s' % (recording['id'], ', '.join(cache_file_names)))
    elif len(cache_file_names) == 1:
        return cache_file_names[0]
    else:
        content_type, data = download_recording(recording)
        extension = {
                'audio/mpeg': 'mp3',
        }[content_type]
        cache_file_name = os.path.join(cache_dir_name, '%s.%s' % (recording['id'], extension))
        logging.info('Downloaded %s (%d kB)',
                cache_file_name,
                round(len(data) / 1024))
        with open(cache_file_name, 'wb') as cache_file:
            cache_file.write(data)
        return cache_file_name
