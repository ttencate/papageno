import logging
import sys

from django.db import connection
from django.core.management.base import BaseCommand, CommandError

from xenocanto import xenocanto
from xenocanto.models import Recording
from xenocanto.readers import strip_comments_and_blank_lines
from xenocanto.selection import preselect_recordings


class Command(BaseCommand):

    help = '''
        Prefilters the list of recordings down to the suitable ones based only
        on their metadata. Reads species names from stdin. Prints recording IDs
        on stdout.
    '''

    def handle(self, *args, **options):
        for xc_species in strip_comments_and_blank_lines(sys.stdin):
            recordings = preselect_recordings(xc_species)
            if not recordings:
                logging.warning('No candidate recordings found for species %s', xc_species)
                continue
            logging.info('Found %s candidate recordings for species %s', xc_species)
            for recording in recordings:
                print(recording.id)
