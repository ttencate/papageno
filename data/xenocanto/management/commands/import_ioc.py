import logging
import sys

from django.db import transaction
from django.core.management.base import BaseCommand, CommandError

from ioc import ioc
from xenocanto.models import Species, SpeciesAltName, SpeciesNameTranslation


class Command(BaseCommand):

    help = 'Imports IOC spreadsheets into the database'

    def handle(self, *args, **options):
        ioc_list = ioc.IOCList()
        with transaction.atomic():
            Species.objects.all().delete()
            SpeciesAltName.objects.all().delete()
            SpeciesNameTranslation.objects.all().delete()

            for ioc_species in ioc_list.species:
                species = Species(ioc_name=ioc_species.ioc_name)
                species.save()

                for alt_name in ioc_species.alt_names:
                    SpeciesAltName(alt_name=alt_name, species=species).save()

                for language, translated_name in ioc_species.translations.items():
                    if language and translated_name:
                        SpeciesNameTranslation(species=species, language=language, translated_name=translated_name).save()
