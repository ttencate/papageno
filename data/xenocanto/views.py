import re

from django.core.paginator import Paginator
from django.http import HttpResponse
from django.template import loader

from .models import Recording, Species


def species_list(request):
    page = request.GET.get('page', 1)

    all_species = Species.objects.order_by('ioc_name')

    paginator = Paginator(all_species, 100)

    template = loader.get_template('xenocanto/species_list.html')
    context = {
        'all_species': paginator.get_page(page),
    }
    return HttpResponse(template.render(context, request))


def species(request, ioc_name):
    species = Species.objects.get(ioc_name__iexact=ioc_name)
    species_alt_names = set(a.alt_name for a in species.alt_names.all())

    query = {
            'page': request.GET.get('page', 1),
            'type': request.GET.get('type', ''),
            'q': request.GET.get('q', ''),
            'min_length': request.GET.get('min_length', ''),
            'max_length': request.GET.get('max_length', ''),
    }

    recordings = Recording.objects.order_by('gen', 'sp', 'ssp', 'q', 'length_s')
    # TODO use species_alt_names to construct a bunch of Q objects instead
    parts = ioc_name.split()
    if len(parts) >= 1:
        recordings = recordings.filter(gen__iexact=parts[0])
    if len(parts) >= 2:
        recordings = recordings.filter(sp__iexact=parts[1])
    if len(parts) >= 3:
        recordings = recordings.filter(ssp__iexact=parts[2])
    if query['type']:
        recordings = recordings.filter(type__iregex=r'(^|,)\s*%s\s*(,|$)' % re.escape(query['type']))
    if query['q']:
        recordings = recordings.filter(q__iexact=query['q'])
    if query['min_length']:
        recordings = recordings.filter(length_s__gte=float(query['min_length']))
    if query['max_length']:
        recordings = recordings.filter(length_s__lte=float(query['max_length']))

    paginator = Paginator(recordings, 10)

    template = loader.get_template('xenocanto/species.html')
    context = {
            'species': species,
            'query': query,
            'recordings': paginator.get_page(query['page']),
    }
    return HttpResponse(template.render(context, request))
