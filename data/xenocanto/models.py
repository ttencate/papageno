from django.db import models


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
        return ' '.join(filter(None, (self.gen, self.sp, self.ssp)))

    def types(self):
        return [t.strip() for t in self.type.split(',')]

    def translated_name(self, language):
        try:
            species_alt_name = SpeciesAltName.objects.get(alt_name__iexact=self.species())
        except SpeciesAltName.DoesNotExist:
            return None
        return species_alt_name.species.translated_name(language)


class Species(models.Model):
    '''
    Represents a single bird species.
    '''

    id = models.AutoField(primary_key=True)
    ioc_name = models.TextField(unique=True)

    def translated_name(self, language):
        try:
            return self.speciesnametranslation_set.get(language__exact=language).translated_name
        except SpeciesNameTranslation.DoesNotExist:
            return None


class SpeciesAltName(models.Model):
    '''
    Represents an alternative (or primary) name given to a species. In general,
    the same name might refer to multiple species, although this is rare.
    '''

    alt_name = models.TextField()
    species = models.ForeignKey('Species', on_delete=models.CASCADE)

    class Meta:
        unique_together = (('alt_name', 'species'),)


class SpeciesNameTranslation(models.Model):
    '''
    Represents the translation of a species name into a particular language.
    '''

    species = models.ForeignKey('Species', on_delete=models.CASCADE)
    language = models.TextField()
    translated_name = models.TextField()

    class Meta:
        unique_together = (('species', 'language'),)
