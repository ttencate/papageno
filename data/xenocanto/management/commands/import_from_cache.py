import logging
import sys

from django.db import connection
from django.core.management.base import BaseCommand, CommandError

from xenocanto import xenocanto
from xenocanto.models import Recording


class Command(BaseCommand):

    help = 'Imports JSON-based cache into the database (pipe in a list of IDs)'

    def handle(self, *args, **options):
        fields = [field.name for field in Recording._meta.get_fields()]
        with connection.cursor() as cursor:
            for line in sys.stdin:
                line = line.strip()

                try:
                    metadata = xenocanto.fetch_metadata_cached(int(line))
                except RuntimeError as ex:
                    logging.warning(ex)
                    continue

                # Recording(**metadata).save()
                cursor.execute(
                        'INSERT OR REPLACE INTO xenocanto_recording VALUES (%s)' % ','.join(['%s'] * len(fields)),
                        [metadata[f] for f in fields])
