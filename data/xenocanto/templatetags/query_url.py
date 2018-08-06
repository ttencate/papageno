'''
Template tag for URL query string manipulation.
'''

import urllib.parse

from django import template


register = template.Library() # pylint: disable=invalid-name


@register.simple_tag
def query_url(url, **kwargs):
    '''
    Returns the given URL, with any parameters in the query string replaced as
    specified by the kwargs. Set to None to remove the parameter entirely.
    '''

    scheme, netloc, path, params, query, fragment = urllib.parse.urlparse(url)

    query_dict = urllib.parse.parse_qs(query)
    for key, value in kwargs.items():
        if value is None:
            if key in query_dict:
                del query_dict[key]
        else:
            query_dict[key] = [value]
    query = urllib.parse.urlencode(query_dict, doseq=True)

    return urllib.parse.urlunparse((scheme, netloc, path, params, query, fragment))
