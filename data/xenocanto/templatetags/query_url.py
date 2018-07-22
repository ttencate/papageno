import urllib.parse

from django import template


register = template.Library()


@register.simple_tag
def query_url(url, **kwargs):
    scheme, netloc, path, params, query, fragment = urllib.parse.urlparse(url)

    qs = urllib.parse.parse_qs(query)
    for key, value in kwargs.items():
        if value is None:
            del qs[key]
        else:
            qs[key] = [value]
    query = urllib.parse.urlencode(qs, doseq=True)

    return urllib.parse.urlunparse((scheme, netloc, path, params, query, fragment))
