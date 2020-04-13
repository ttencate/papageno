'''
Fetches recording metadata through the [xeno-canto
API](https://www.xeno-canto.org/explore/api) and writes it to the `recordings`
table. It takes about an hour to run, but responses are cached, so if it fails
for some reason it can just be restarted.

Note that the xeno-canto API does pagination (returning 500 recordings at a
time), but does not order the results in any meaningful way, or offer anything
like page tokens. So if recordings are added while the script is running, the
pages might shuffle around. The result is that we may miss some recordings, or
get duplicates (which we filter out).
'''

import datetime
import itertools
import json
import logging
import os.path
import multiprocessing.pool

import diskcache
import tenacity
import urllib3

from recordings import Recording


class XcQuery:
    '''
    Wrapper around the XenoCanto API.
    '''

    def __init__(self, parts, pool_size, clear_cache=False):
        self._cache = diskcache.Index(os.path.join(os.path.dirname(__file__), 'cache', 'xc_api'))
        if clear_cache:
            self._cache.clear()
        self._http = urllib3.PoolManager(num_pools=1,
                                         maxsize=pool_size,
                                         timeout=urllib3.util.Timeout(total=300))
        self._query = '%20'.join(f'{k}:{v}' for k, v in parts.items())

    # Note that we even retry 400 errors (i.e. client side). These spuriously
    # happen, perhaps due to a bug in the API.
    @tenacity.retry(stop=tenacity.stop_after_attempt(5))
    def fetch_page(self, page_number):
        '''
        Fetches the given page (1-based) and returns the parsed JSON.
        '''
        url = f'https://www.xeno-canto.org/api/2/recordings?query={self._query}&page={page_number}'
        if url in self._cache:
            logging.info(f'Returning {url} from cache')
            return self._cache[url]
        logging.info(f'Fetching {url}')
        response = self._http.request('GET', url)
        if response.status != 200:
            raise RuntimeError(f'URL {url} returned status code {response.status} '
                               f'and said:\n{response.data}')
        parsed_response = json.loads(response.data)
        # Sanity check so we can retry before returning if needed.
        if 'recordings' not in parsed_response:
            raise RuntimeError(f'URL {url} returned JSON without "recordings":\n{response.data}')
        self._cache[url] = parsed_response
        return parsed_response


def _parse_float(f):
    if f is None or f == '':
        return None
    return float(f)


def _parse_duration(s):
    parts = s.split(':')
    seconds = int(parts.pop())
    if parts:
        seconds += 60 * int(parts.pop())
    if parts:
        seconds += 60 * 60 * int(parts.pop())
    assert not parts
    return seconds


def _parse_bool(s):
    return {'no': False, 'yes': True, 'unknown': None}[s]


def _parse_date_time(date, time):
    try:
        return datetime.datetime.strptime(date + 'T' + time, '%Y-%m-%dT%H:%M')
    except ValueError:
        return None


def _parse_recording(r):
    '''
    Creates a recording from the parsed JSON object as returned by the
    xeno-canto API.
    '''
    return Recording(
        recording_id='xc:' + r['id'],
        source='xc',
        genus=r['gen'],
        species=r['sp'],
        subspecies=r['ssp'],
        common_name_en=r['en'],
        recordist=r['rec'],
        country=r['cnt'],
        location=r['loc'],
        latitude=_parse_float(r['lat']),
        longitude=_parse_float(r['lng']),
        altitude=r['alt'],
        type=r['type'],
        url=r['url'],
        audio_url=r['file'],
        audio_file_name=r['file-name'],
        sonogram_url_small=r['sono']['small'],
        sonogram_url_medium=r['sono']['med'],
        sonogram_url_large=r['sono']['large'],
        sonogram_url_full=r['sono']['full'],
        license_url=r['lic'],
        quality=r['q'],
        length_seconds=_parse_duration(r['length']),
        date_time=_parse_date_time(r['date'], r['time']),
        upload_date=datetime.date.fromisoformat(r['uploaded']),
        background_species=list(filter(None, map(str.strip, r['also']))),
        remarks=r['rmk'],
        bird_seen=_parse_bool(r['bird-seen']),
        playback_used=_parse_bool(r['playback-used']),
    )


def add_args(parser):
    parser.add_argument(
        '--start_xc_id', type=int, default=1,
        help='First xeno-canto id to fetch')
    parser.add_argument(
        '--end_xc_id', type=int, default=999999999,
        help='Last xeno-canto id to fetch (inclusive)')
    parser.add_argument(
        '--clear_recordings_cache', action='store_true',
        help='Wipe the response cache and start from scratch')
    parser.add_argument(
        '--recording_load_jobs', type=int, default=10,
        help='Number of parallel fetches to run; do not set too high or else '
        'the XenoCanto server might get upset!')


def main(args, session):
    session.query(Recording).filter(Recording.source == 'xc').delete()

    query = XcQuery({'nr': f'{args.start_xc_id}-{args.end_xc_id}'},
                    pool_size=args.recording_load_jobs,
                    clear_cache=args.clear_recordings_cache)
    first_page = query.fetch_page(1)
    num_pages = first_page['numPages']
    num_recordings = int(first_page['numRecordings'])
    logging.info(f'Found {num_pages} pages, {num_recordings} recordings')
    pages_fetched = 0
    num_parsed_recordings = 0
    with multiprocessing.pool.ThreadPool(args.recording_load_jobs) as pool:
        for page in itertools.chain(
                [first_page],
                pool.imap(query.fetch_page, range(2, num_pages + 1))):
            try:
                # Allow replacements in case the API shifts pages around
                # (it seems to do that, probably when new recordings are
                # added during the run).
                recordings = [_parse_recording(r) for r in page['recordings']]
                session.bulk_save_objects_with_replace(recordings)
                pages_fetched += 1
                num_parsed_recordings += len(recordings)
                logging.info(f'Fetched {pages_fetched}/{num_pages} pages, '
                             f'parsed {num_parsed_recordings}/{num_recordings} recordings '
                             f'({pages_fetched / num_pages * 100:.1f}%)')
            except Exception:
                logging.error(f'Error parsing page:\n{json.dumps(page, indent="  ")}',
                              exc_info=True)
                raise

    logging.info('Committing transaction')
    session.commit()
