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
        parser.add_argument('--reanalyze', action='store_true')
        parser.add_argument('--play', action='store_true')

    def handle(self, *args, recordings_per_species=None, reanalyze=None, play=None, **options):
        for xc_species in strip_comments_and_blank_lines(sys.stdin):
            logging.info('Downloading and analyzing audio recordings for %s', xc_species)
            candidates = preselect_recordings(xc_species)
            for recording in candidates:
                audio_file = recording.get_or_download_audio_file()
                if reanalyze:
                    audio_file.analyze()
                else:
                    audio_file.get_or_compute_analysis()

            recordings = order_recordings(candidates)[:recordings_per_species]

            if len(recordings) < recordings_per_species:
                logging.warning('Found only %d/%d suitable recordings for species %s',
                                len(recordings),
                                options.recordings_per_species,
                                xc_species)
                continue

            for recording in recordings:
                print(recording.id)
                if play:
                    logging.info('Playing %s...' % recording)
                    recording.audio_file.play()
