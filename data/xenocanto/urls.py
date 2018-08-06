'''
URL configuration for the xenocanto app.
'''

from django.urls import path

from . import views

urlpatterns = [ # pylint: disable=invalid-name
    path('species', views.species_list, name='species_list'),
    path('species/<str:ioc_name>', views.species, name='species'),
]