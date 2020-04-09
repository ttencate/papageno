'''
A set of helper functions to work with filesystem-based caches. Cache entries
are grouped by cache type, and grouped by cache key to prevent excessive
numbers of files in a single directory. The key may or may not match the file
name.
'''

import os
import os.path

import requests


SUBDIR_NAME_LENGTH = 2
SUBDIR_LEVELS = 2


class DownloadError(RuntimeError):
    '''
    Network, server or client error while downloading a file.
    '''
    pass


def _get_cache_root():
    return os.path.join(os.path.dirname(__file__), 'cache')


def get_cache_dir(cache_type, cache_key):
    '''
    Returns the path to the directory for the given cache type and key. The
    directory may not yet exist.
    '''
    cache_key = str(cache_key).replace('/', '_')
    missing_prefix_length = max(0, SUBDIR_LEVELS * SUBDIR_NAME_LENGTH - len(cache_key))
    cache_key = ('0' * missing_prefix_length) + cache_key
    key_subdirs = [
        cache_key[i:i+SUBDIR_NAME_LENGTH]
        for i in range(0, SUBDIR_LEVELS * SUBDIR_NAME_LENGTH, SUBDIR_NAME_LENGTH)
    ]
    return os.path.join(_get_cache_root(), cache_type, *key_subdirs)


def get_cache_file_name(cache_type, cache_key, file_name):
    '''
    Returns the path to the given file in the cache. Neither the file nor the
    directory necessarily exists.
    '''
    return os.path.join(get_cache_dir(cache_type, cache_key), file_name)


def open_cache_file(cache_file_name, mode):
    '''
    Opens the given file in the given mode, after creating any necessary
    directories.
    '''
    cache_dir = os.path.dirname(cache_file_name)
    os.makedirs(cache_dir, exist_ok=True)
    return open(cache_file_name, mode)


def get_response(url):
    '''
    Returns the response for the given URL as a requests.Response object.
    Raises DownloadError in case of failure.
    '''
    if url.startswith('//'):
        url = 'https:' + url
    response = requests.get(url)
    try:
        response.raise_for_status()
    except requests.exceptions.RequestException as ex:
        raise DownloadError('Error downloading %s' % url) from ex
    return response


def download_file(url):
    '''
    Downloads the given URL and returns a tuple of (content_type, content).
    '''
    response = get_response(url)
    return response.headers['content-type'], response.content
