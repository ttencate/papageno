import re

from django.core.paginator import Paginator
from django.http import HttpResponse
from django.template import loader

from .models import Recording


def index(request):
    query = {
            'page': request.GET.get('page', 1),
            'species': request.GET.get('species', ''),
            'type': request.GET.get('type', ''),
            'q': request.GET.get('q', ''),
            'min_length': request.GET.get('min_length', ''),
            'max_length': request.GET.get('max_length', ''),
    }

    recordings = Recording.objects.order_by('gen', 'sp', 'ssp', 'q', 'length_s')
    if query['species']:
        parts = query['species'].split()
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

    template = loader.get_template('xenocanto/index.html')
    context = {
            'query': query,
            'recordings': paginator.get_page(query['page']),
    }
    return HttpResponse(template.render(context, request))
