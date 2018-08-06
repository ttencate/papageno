'''
Models for the xenocanto app.
'''

import logging

from django.db import models

import xenocanto.cache


class Recording(models.Model):
    '''
    Represents a single Xeno-Canto recording, identified by a unique number (XC
    number).
    '''

    id = models.TextField(primary_key=True)
    gen = models.TextField(null=True, blank=True)
    sp = models.TextField(null=True, blank=True)
    ssp = models.TextField(null=True, blank=True)
    en = models.TextField(null=True, blank=True)
    rec = models.TextField(null=True, blank=True)
    cnt = models.TextField(null=True, blank=True)
    loc = models.TextField(null=True, blank=True)
    lat = models.FloatField(null=True, blank=True)
    lng = models.FloatField(null=True, blank=True)
    type = models.TextField(null=True, blank=True)
    file = models.TextField(null=True, blank=True)
    lic = models.TextField(null=True, blank=True)
    url = models.TextField(null=True, blank=True)
    q = models.TextField(null=True, blank=True)
    time = models.TextField(null=True, blank=True)
    date = models.TextField(null=True, blank=True)
    sonogram_url = models.TextField(null=True, blank=True)
    elevation_m = models.IntegerField(null=True, blank=True)
    length_s = models.FloatField(null=True, blank=True)
    sampling_rate_hz = models.IntegerField(null=True, blank=True)
    bitrate_bps = models.IntegerField(null=True, blank=True)
    channels = models.IntegerField(null=True, blank=True)
    volume = models.TextField(null=True, blank=True)
    speed = models.TextField(null=True, blank=True)
    pitch = models.TextField(null=True, blank=True)
    sound_length = models.TextField(null=True, blank=True)
    number_of_notes = models.TextField(null=True, blank=True)
    variable = models.TextField(null=True, blank=True)

    def species(self):
        '''
        Returns the full scientific species name.
        '''
        return ' '.join(filter(None, (self.gen, self.sp, self.ssp)))

    def types(self):
        '''
        Returns all types of this recording as a list of strings (e.g. ['call', 'song']).
        '''
        return [t.strip() for t in self.type.split(',')]

    def translated_name(self, language):
        '''
        Returns the name of this recording's species in the given language, or
        None if not found.
        '''
        try:
            species_alt_name = SpeciesAltName.objects.get(alt_name__iexact=self.species())
        except SpeciesAltName.DoesNotExist:
            return None
        return species_alt_name.species.translated_name(language)

    def get_or_download_audio_file(self):
        '''
        Returns the AudioFile corresponding to this Recording, downloading it if needed.
        '''
        try:
            audio_file = self.audio_file # pylint: disable=no-member,access-member-before-definition,attribute-defined-outside-init
        except AudioFile.DoesNotExist:
            audio_file = AudioFile.objects.download_and_save(self.id, self.file)
            self.audio_file = audio_file # pylint: disable=no-member,access-member-before-definition,attribute-defined-outside-init
        return audio_file


class Species(models.Model):
    '''
    Represents a single bird species.
    '''

    id = models.AutoField(primary_key=True)
    ioc_name = models.TextField(unique=True)

    def translated_name(self, language):
        '''
        Returns the species name in the given language, or None if not found.
        '''
        try:
            return self.name_translations.get(language__exact=language).translated_name
        except SpeciesNameTranslation.DoesNotExist:
            return None


class SpeciesAltName(models.Model):
    '''
    Represents an alternative (or primary) name given to a species. In general,
    the same name might refer to multiple species, although this is rare.
    '''

    alt_name = models.TextField()
    species = models.ForeignKey('Species',
                                related_name='alt_names',
                                on_delete=models.CASCADE)

    class Meta:
        unique_together = (('alt_name', 'species'),)


class SpeciesNameTranslation(models.Model):
    '''
    Represents the translation of a species name into a particular language.
    '''

    species = models.ForeignKey('Species',
                                related_name='name_translations',
                                on_delete=models.CASCADE)
    language = models.TextField()
    translated_name = models.TextField()

    class Meta:
        unique_together = (('species', 'language'),)


class AudioFileManager(models.Manager):
    '''
    Adds some helpers onto AudioFile.objects.
    '''

    FILE_NAME_EXTENSIONS = {
        'audio/mpeg': 'mp3',
    }

    @classmethod
    def download_and_save(cls, recording_id, url):
        '''
        Downloads the audio for the given recording, saves it to disk and
        creates an AudioFile object in the database. Returns that object.
        '''
        content_type, content = xenocanto.cache.download_file(url)
        extension = cls.FILE_NAME_EXTENSIONS[content_type]
        cache_file_name = xenocanto.cache.get_cache_file_name(
            'audio', recording_id, '%s.%s' % (recording_id, extension))
        with xenocanto.cache.open_cache_file(cache_file_name, 'wb') as cache_file:
            cache_file.write(content)
        logging.info('Downloaded %s (%d kB)', cache_file_name, round(len(content) / 1024))
        audio_file = AudioFile(recording_id=recording_id, file_name=cache_file_name)
        audio_file.save()
        return audio_file


class AudioFile(models.Model):
    '''
    Represents an audio file on disk, belonging to a certain recording.
    '''

    objects = AudioFileManager()

    recording = models.OneToOneField('Recording', related_name='audio_file', on_delete=models.CASCADE)
    file_name = models.TextField()
