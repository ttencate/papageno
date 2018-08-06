'''
Template tag for name translations.
'''

from django import template


register = template.Library() # pylint: disable=invalid-name


@register.filter
def translated_name(recording, language):
    '''
    Returns the species name of the given recording, translated to the given
    language, or None if not found.
    '''
    return recording.translated_name(language)
