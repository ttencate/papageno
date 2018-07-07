import collections
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
    Returns a JSON object as returned by the XC API
    (https://www.xeno-canto.org/article/153) but not paginated anymore.

    See https://www.xeno-canto.org/help/search for query syntax.
    '''

    merged_json = {
        'numRecordings': 0,
        'numSpecies': 0,
        'recordings': [],
    }

    page = 1
    while True:
        url = make_url({'query': query, 'page': str(page)})
        response = requests.get(url)
        response.raise_for_status()
        json = response.json()
        merged_json['numRecordings'] = json['numRecordings']
        merged_json['numSpecies'] = json['numSpecies']
        merged_json['recordings'].extend(json['recordings'])
        if json['page'] >= json['numPages']:
            break
        page += 1

    return merged_json


def find_cached_recordings(query):
    cache_dir_name = os.path.join(os.path.dirname(__file__), 'cache')
    os.makedirs(cache_dir_name, exist_ok=True)

    cache_file_name = os.path.join(cache_dir_name, '%s.json' % query)
    try:
        with open(cache_file_name, 'rb') as cache_file:
            return json.load(cache_file)
    except FileNotFoundError:
        pass

    result = get_recordings(query)
    with open(cache_file_name, 'wt') as cache_file:
        json.dump(result, cache_file, indent=2)
    logging.info('Wrote %d recordings to %s', len(result['recordings']), cache_file_name)
    return result
