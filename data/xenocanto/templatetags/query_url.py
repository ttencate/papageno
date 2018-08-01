import urllib.parse

from django import template


register = template.Library()


@register.simple_tag
def query_url(url, **kwargs):
    '''
    Returns the given URL, with any parameters in the query string replaced as
    specified by the kwargs. Set to None to remove the parameter entirely.
    '''

    scheme, netloc, path, params, query, fragment = urllib.parse.urlparse(url)

    qs = urllib.parse.parse_qs(query)
    for key, value in kwargs.items():
        if value is None:
            if key in qs:
                del qs[key]
        else:
            qs[key] = [value]
    query = urllib.parse.urlencode(qs, doseq=True)

    return urllib.parse.urlunparse((scheme, netloc, path, params, query, fragment))
