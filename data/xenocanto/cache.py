import logging
import os
import os.path

import requests


SUBDIR_NAME_LENGTH = 2
SUBDIR_LEVELS = 2


def get_cache_root():
    return os.path.join(os.path.dirname(__file__), 'cache')


def get_cache_dir(cache_type, cache_key):
    cache_key = str(cache_key).replace('/', '_')
    missing_prefix_length = max(0, SUBDIR_LEVELS * SUBDIR_NAME_LENGTH - len(cache_key))
    cache_key = ('0' * missing_prefix_length) + cache_key
    key_subdirs = [
            cache_key[i:i+SUBDIR_NAME_LENGTH]
            for i in range(0, SUBDIR_LEVELS * SUBDIR_NAME_LENGTH, SUBDIR_NAME_LENGTH)
    ]
    return os.path.join(get_cache_root(), cache_type, *key_subdirs)


def get_cache_file_name(cache_type, cache_key, file_name):
    return os.path.join(get_cache_dir(cache_type, cache_key), file_name)


def open_cache_file(cache_file_name, mode):
    cache_dir = os.path.dirname(cache_file_name)
    os.makedirs(cache_dir, exist_ok=True)
    return open(cache_file_name, mode)


def get_response(url):
    if url.startswith('//'):
        url = 'https:' + url
    response = requests.get(url)
    try:
        response.raise_for_status()
    except Exception as ex:
        raise RuntimeError('Error downloading %s' % url) from ex
    return response


def download_file(url):
    response = get_response(url)
    return response.headers['content-type'], response.content
