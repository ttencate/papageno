'''
Network fetch helpers.
'''

import logging
import os.path

import diskcache
import tenacity
import urllib3


class Fetcher:
    '''
    Cached, thread-safe HTTP fetcher.
    '''

    def __init__(self, cache_group, pool_size, clear_cache=False):
        self._cache_group = cache_group
        self._cache = diskcache.Index(os.path.join(os.path.dirname(__file__), 'cache', cache_group))
        if clear_cache:
            self._cache.clear()
        self._http = urllib3.PoolManager(num_pools=10,
                                         maxsize=pool_size,
                                         block=True,
                                         timeout=urllib3.util.Timeout(total=300))


    # Note that we even retry 400 errors (i.e. client side). These spuriously
    # happen, perhaps due to a bug in the API.
    def fetch_cached(self, url):
        '''
        Returns the URL response body from cache if possible, fetching and
        storing it if needed.
        '''
        if url in self._cache:
            logging.info(f'Returning {url} from {self._cache_group} cache')
            return self._cache[url]
        data = self.fetch_uncached(url)
        self._cache[url] = data
        return data

    @tenacity.retry(stop=tenacity.stop_after_attempt(5))
    def fetch_uncached(self, url):
        '''
        Fetches the URL response through a HTTP(S) GET request.
        '''
        logging.info(f'Fetching {url}')
        response = self._http.request('GET', url)
        if response.status != 200:
            raise RuntimeError(f'URL {url} returned status code {response.status} '
                               f'and said:\n{response.data}')
        data = response.data
