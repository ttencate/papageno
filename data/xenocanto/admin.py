'''
Admin site configuration for the xenocanto app.
'''

from django.contrib import admin

from .models import Recording

admin.site.register(Recording)
