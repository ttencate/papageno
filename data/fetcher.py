'''
Network fetch helpers.
'''

import hashlib
import logging
import os
import os.path

import urllib3


class FetchError(RuntimeError):

    def __init__(self, url):
        super().__init__(f'Error fetching "{url}"')
        self.url = url


class Cache:
    '''
    Disk-based cache with atomic, thread-safe and process-safe operations apart
    from clearing.
    '''

    def __init__(self, path, levels=2):
        self._path = path
        self._levels = levels

    def clear(self):
        raise NotImplemented(f'Just remove {self._path} yourself for now')

    def __getitem__(self, key):
        try:
            with open(self.file_for_key(key), 'rb') as f:
                return f.read()
        except FileNotFoundError:
            raise KeyError(key)

    def __setitem__(self, key, value):
        file_name = self.file_for_key(key)
        os.makedirs(os.path.dirname(file_name), exist_ok=True)
        # Include PID in the file name to make concurrent writes process-safe.
        temp_file_name = f'{file_name}.{os.getpid()}.tmp'
        try:
            with open(temp_file_name, 'wb') as f:
                f.write(value)
            os.rename(temp_file_name, file_name)
        except: # pylint: disable=bare-except
            # Try to clean up, but propagate the original exception.
            try:
                os.remove(temp_file_name)
            except: # pylint: disable=bare-except
                pass
            raise

    def __contains__(self, key):
        return os.path.isfile(self.file_for_key(key))

    def file_for_key(self, key):
        hasher = hashlib.sha1()
        if isinstance(key, str):
            key = key.encode('utf-8')
        assert isinstance(key, bytes)
        hasher.update(key)
        basename = hasher.hexdigest()
        parts = []
        for _ in range(self._levels):
            parts.append(basename[:2])
            basename = basename[2:]
        parts.append(basename)
        return os.path.join(self._path, *parts)


class Fetcher:
    '''
    Cached, thread-safe HTTP fetcher.
    '''

    def __init__(self, cache_group, pool_size, clear_cache=False):
        self._cache_group = cache_group
        self._cache = Cache(os.path.join(os.path.dirname(__file__), 'cache', cache_group))
        if clear_cache:
            self._cache.clear()
        self._http = urllib3.PoolManager(num_pools=10,
                                         maxsize=pool_size,
                                         block=True,
                                         timeout=urllib3.util.Timeout(total=300))

    def fetch_cached(self, url):
        '''
        Returns the URL response body from cache if possible, fetching and
        storing it if needed.
        '''
        if url in self._cache:
            logging.debug(f'Returning {url} from {self._cache_group} cache')
            return self._cache[url]
        data = self.fetch_uncached(url)
        self._cache[url] = data
        return data

    def fetch_uncached(self, url):
        '''
        Fetches the URL response through a HTTP(S) GET request.
        '''
        # Save a redirect from http to https, which matters for performance,
        # because the server does not support keepalive.
        if url.startswith('//'):
            url = 'https:' + url
        logging.debug(f'Fetching {url}')
        try:
            response = self._http.request(
                'GET', url,
                timeout=urllib3.Timeout(
                    connect=20.0,
                    read=60.0),
                retries=urllib3.Retry(
                    total=7,
                    # Retry 400 errors (Bad Request). These spuriously happen in
                    # the xeno-canto API, perhaps due to a bug.
                    status_forcelist=[400] + list(range(500, 600)),
                    backoff_factor=0.1,
                    raise_on_status=True))
        except urllib3.exceptions.HTTPError as ex:
            raise FetchError(url) from ex
        return response.data

    def cache_file_name(self, url):
        return self._cache.file_for_key(url)
