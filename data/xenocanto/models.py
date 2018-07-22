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
