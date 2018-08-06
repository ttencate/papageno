import logging
import sys

from django.db import connection
from django.core.management.base import BaseCommand, CommandError

from xenocanto import xenocanto
from xenocanto.management.base import LoggingCommand
from xenocanto.models import Recording
from xenocanto.readers import strip_comments_and_blank_lines
from xenocanto.selection import preselect_recordings, order_recordings


class Command(LoggingCommand):

    help = '''
        Filters the list of recordings down to the top 10 suitable ones based
        on both their metadata and their audio analysis. Reads species names
        from stdin. Prints recording IDs on stdout.
    '''

    def add_arguments(self, parser):
        parser.add_argument('--recordings_per_species', type=int, default=10)

    def handle(self, *args, recordings_per_species=None, **options):
        for xc_species in strip_comments_and_blank_lines(sys.stdin):
            recordings = order_recordings(preselect_recordings(xc_species))[:recordings_per_species]
            if len(recordings) < recordings_per_species:
                logging.warning('Found only %d/%d suitable recordings for species %s',
                                len(recordings),
                                options.recordings_per_species,
                                xc_species)
                continue
            for recording in recordings:
                print(recording.id)
