import urllib.parse

from django import template


register = template.Library()


@register.filter
def translated_name(recording, language):
    return recording.translated_name(language)
