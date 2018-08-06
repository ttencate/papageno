import logging
import sys

from django.db import connection
from django.core.management.base import BaseCommand, CommandError

from xenocanto import xenocanto
from xenocanto.management.base import LoggingCommand
from xenocanto.models import Recording, AudioFileAnalysis
from xenocanto.readers import strip_comments_and_blank_lines
from xenocanto.selection import preselect_recordings, order_recordings


class Command(LoggingCommand):

    help = '''
        Plays all recording IDs from stdin sequentially, downloading them if needed.
    '''

    def handle(self, *args, recordings_per_species=None, **options):
        for recording_id in strip_comments_and_blank_lines(sys.stdin):
            recording = Recording.objects.get(id=recording_id)
            audio_file = recording.get_or_download_audio_file()
            try:
                analysis = audio_file.analysis
            except AudioFileAnalysis.NotFound:
                analysis = None
            self.stdout.write('Playing recording %s (%s, %s, %.1ds, clarity %s)...' % (
                recording.url,
                recording.species(),
                ', '.join(recording.types()),
                recording.length_s,
                ('%.1f' % analysis.clarity) if analysis else 'unknown'))
            audio_file.play()
