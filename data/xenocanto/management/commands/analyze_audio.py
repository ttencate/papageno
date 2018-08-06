import logging
import sys

from django.db import connection
from django.core.management.base import BaseCommand, CommandError

from xenocanto import xenocanto
from xenocanto.audio import load_audio, preprocess_audio, compute_clarity
from xenocanto.cache import DownloadError
from xenocanto.models import Recording, AudioFileAnalysis
from xenocanto.readers import strip_comments_and_blank_lines


class Command(BaseCommand):

    help = '''
        Analyzes audio files and stores the results in the database. Reads a list of IDs from stdin.
    '''

    def handle(self, *args, **options):
        for recording_id in strip_comments_and_blank_lines(sys.stdin):
            try:
                recording = Recording.objects.get(id=recording_id)
            except Recording.DoesNotExist:
                logging.error('Recording %s was not found', recording_id)
                continue

            try:
                audio_file = recording.get_or_download_audio_file()
            except DownloadError:
                logging.error('Could not download audio for recording %s', recording_id, exc_info=True)

            try:
                audio_file.analysis.delete()
            except AudioFileAnalysis.DoesNotExist:
                pass
            
            analysis = audio_file.analyze()
            print('%6s: clarity=%5.2f' % (recording.id, analysis.clarity))
