import collections
import json
import logging
import re
import urllib.parse

import requests


class Recording:
    '''
    Metadata for a single Xeno-Canto recording.

    id: the catalogue number of the recording on xeno-canto
    gen: the generic name of the species
    sp: the specific name of the species
    ssp: the subspecies name
    en: the English name of the species
    rec: the name of the recordist
    cnt: the country where the recording was made
    loc: the name of the locality
    lat: the latitude of the recording in decimal coordinates
    lng: the longitude of the recording in decimal coordinates
    type: the sound type of the recording (e.g. 'call', 'song', etc). This is generally a comma-separated list of sound types.
    file: the URL to the audio file
    lic: the URL describing the license of this recording
    url: the URL specifying the details of this recording
    q: the current quality rating for the recording
    time: the time of day that the recording was made
    date: the date that the recording was made
    '''

    def __init__(self, json):
        super().__init__()
        self.json = json

    def latin_name(self):
        return ' '.join(self.json[part] for part in ('gen', 'sp', 'ssp') if part in self.json and self.json[part])

    def types(self):
        return map(str.strip, self.json['type'].split(','))

    def quality(self):
        return {'A': 100, 'B': 80, 'C': 60, 'D': 40, 'E': 20, 'no score': None}[self.json['q']]

    def __str__(self):
        return '{url} ({name}: {types}, quality {quality})'.format(
                url=self.json['url'],
                name=self.latin_name(),
                types=', '.join(self.types()),
                quality=self.quality())


def make_url(query_dict):
    SCHEME = 'https'
    HOSTNAME = 'www.xeno-canto.org'
    PATH = '/api/2/recordings'
    query = urllib.parse.urlencode(query_dict)
    return urllib.parse.urlunparse((SCHEME, HOSTNAME, PATH, None, query, None))


def get_recordings(query):
    '''
    Returns a list of Recording objects matching the query. See
    https://www.xeno-canto.org/help/search
    for query syntax.
    '''
    page = 1
    num_pages = 'unknown'
    while True:
        url = make_url({'query': query, 'page': str(page)})
        response = requests.get(url)
        response.raise_for_status()
        json = response.json()
        for r in json['recordings']:
            yield Recording(r)
        num_pages = json['numPages']
        if json['page'] >= num_pages:
            break
        page += 1
