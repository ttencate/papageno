from django.http import HttpResponse
from django.template import loader

from .models import Recording


def index(request):
    recordings = Recording.objects.order_by('gen', 'sp', 'ssp', 'q', 'length_s')
    template = loader.get_template('xenocanto/index.html')
    context = {
        'recordings': recordings,
    }
    return HttpResponse(template.render(context, request))
