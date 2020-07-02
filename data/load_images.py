'''
Fetches image metadata from Wikipedia (WikiMedia Commons).
'''

import json
import logging
import multiprocessing
import re
import signal
import urllib.parse

from bs4 import BeautifulSoup, NavigableString

import fetcher
import progress
from images import Image
from species import Species


_fetcher = None


class _ParseError(RuntimeError):
    pass


def _page_url(domain, page_name):
    return f'https://{domain}/wiki/{urllib.parse.quote_plus(page_name.replace(" ", "_"))}'


def _fetch_wiki(domain, page_name, prop):
    '''
    prop is 'text' (for HTML) or 'wikitext' (for original wikitext markup) or
    'parsetree' (for the parse tree in XML format).
    '''
    # https://www.mediawiki.org/wiki/API:Get_the_contents_of_a_page
    url = (f'https://{domain}/w/api.php'
           '?action=parse'
           f'&page={urllib.parse.quote_plus(page_name)}'
           '&redirects'
           f'&prop={prop}'
           '&format=json'
           '&formatversion=2')
    response = json.loads(_fetcher.fetch_cached(url))

    if 'error' in response and response['error']['code'] == 'missingtitle':
        return None

    return response['parse'][prop]


def _fetch_image_info(page_name):
    # https://commons.wikimedia.org/wiki/File%3ASolitarysandpiper.jpg does not
    # exist; this file comes from Wikipedia directly!
    for domain in ['commons.wikimedia.org', 'en.wikipedia.org']:
        url = (f'https://{domain}/w/api.php'
               '?action=query'
               '&prop=imageinfo'
               f'&titles={urllib.parse.quote_plus(page_name)}'
               '&redirects'
               '&iiprop=url|mime|size|bitdepth|sha1|extmetadata'
               '&formatversion=2'
               '&format=json')
        response = _fetcher.fetch_cached(url)
        page = json.loads(response)['query']['pages'][0]
        if page.get('missing'):
            continue
        return page['imageinfo'][0]
    return None


def _parse_wiki_page(parsetree):
    soup = BeautifulSoup(parsetree, 'lxml-xml')

    def _loose_match(text):
        return re.compile(r'^\s*' + re.escape(text) + r'\s*$', re.IGNORECASE)
    def _find_template(root, title):
        title_element = root.find('title', string=_loose_match(title))
        if not title_element:
            return None
        template = title_element.parent
        if template.name != 'template':
            raise _ParseError(f'Template title {title} found in tag {template.name}')
        return template
    def _key_value(template, key):
        name = template.find('name', string=_loose_match(key))
        if not name:
            return None
        part = name.parent
        if part.name != 'part':
            raise _ParseError(f'Part name {key} found in tag {part.name}')
        value = part.find('value')
        # https://en.wikipedia.org/wiki/Chestnut-sided_warbler
        for comment in value.find_all('comment'):
            comment.decompose()
        return value
    def _key_value_text(template, key):
        value = _key_value(template, key)
        if not value:
            return None
        return value.get_text().strip()

    speciesbox = (_find_template(soup, 'speciesbox')
                  # https://en.wikipedia.org/wiki/Hoogerwerf%27s_pheasant
                  or _find_template(soup, 'subspeciesbox')
                  # https://en.wikipedia.org/wiki/Barolo_shearwater
                  or _find_template(soup, 'Taxobox')
                  # https://en.wikipedia.org/wiki/Royal_flycatcher
                  or _find_template(soup, 'Automatic Taxobox'))

    genus = _key_value_text(speciesbox, 'genus')
    species = _key_value_text(speciesbox, 'species')
    if not genus or not species:
        genus, species = _key_value_text(speciesbox, 'taxon').split(maxsplit=1)

    image_value = _key_value(speciesbox, 'image')
    image_page_name = None
    if image_value:
        if all(isinstance(c, NavigableString) for c in image_value.contents):
            image_page_name = image_value.get_text().strip()
        else:
            # https://en.wikipedia.org/wiki/Kelp_gull
            css_image_crop = _find_template(image_value, 'css image crop')
            if not css_image_crop:
                raise _ParseError(f'Unexpected contents of speciesbox image attribute: {image_value}')
            image_page_name = _key_value_text(css_image_crop, 'image')
    if image_page_name:
        # https://en.wikipedia.org/wiki/Marmora%27s_warbler
        if '%' in image_page_name:
            image_page_name = urllib.parse.unquote(image_page_name)
        # The prefix is usually omitted, but not always[citation needed].
        if not image_page_name.startswith('File:'):
            image_page_name = 'File:' + image_page_name

    return (genus, species, image_page_name)


def _parse_license(image_info):
    def info_field(key):
        return image_info['extmetadata'].get(key, {}).get('value', None)

    license_name = info_field('LicenseShortName')
    if license_name == 'PD':
        license_name = 'Public domain'
    if license_name:
        # Sometimes we get "CC BY-SA 3.0", sometimes "CC-BY-SA-3.0".
        license_name = re.sub(r'^CC[- ](.*)[- ](\d\.\d)$', r'CC \1 \2', license_name)

    license_url = info_field('LicenseUrl')
    if license_url and license_url.startswith('//'):
        license_url = 'https:' + license_url

    attribution = info_field('Attribution') or info_field('Artist')
    if attribution:
        soup = BeautifulSoup(attribution, 'html.parser')
        attribution = soup.get_text().strip()
    attribution_required = info_field('AttributionRequired') == 'true'

    return license_name, license_url, attribution_required, attribution


def _process_image(species):
    '''
    Entry point for parallel processing.
    '''

    global _fetcher # pylint: disable=global-statement
    if not _fetcher:
        _fetcher = fetcher.Fetcher('wp_pages', pool_size=1)

    scientific_name = species.scientific_name

    page_url = _page_url('en.wikipedia.org', scientific_name)
    parsetree = _fetch_wiki('en.wikipedia.org', scientific_name, 'parsetree')
    if not parsetree:
        logging.warning(f'Page does not exist: {page_url}')
        return None

    gen, sp, image_page_name = _parse_wiki_page(parsetree)
    if gen is None or sp is None:
        logging.warning(f'Unknown genus or species: {page_url}')
        return None

    # Sometimes we get stuff like genus = "Acrocephalus (bird)" so a
    # simple match is too simple.
    if scientific_name.split()[0] not in gen or \
            scientific_name.split()[1] not in sp:
        # Logging at debug level is enough; this happens regularly and
        # was always benign in the cases that I checked (all
        # disagreements or changes in taxonomy).
        logging.info(f'Page is actually about {gen} {sp}: {page_url}')

    if not image_page_name:
        logging.info(f'Page for {scientific_name} contains no image: {page_url}')
        return None

    image_page_url = _page_url('commons.wikimedia.org', image_page_name)
    image_info = _fetch_image_info(image_page_name)
    if not image_info:
        logging.warning(f'Image page does not exist: {image_page_url}')
        return None

    image_file_url = image_info['url']
    image_width = image_info['width']
    image_height = image_info['height']

    license_name, license_url, attribution_required, attribution = _parse_license(image_info)
    # print(f'{image_page_url}\n  {license}\n  {license_url}\n  {attribution}\n')
    if not license_name:
        logging.warning(f'No license found: {image_page_url}')
    if attribution_required and not attribution:
        # TODO ensure that we link back to the Wikimedia Commons page for these cases!
        logging.warning(f'Attribution required but no author found: {image_page_url}')

    output_file_name = scientific_name.replace(' ', '_') + '.webp'

    return Image(species_id=species.species_id,
                 source_page_url=image_page_url,
                 image_file_url=image_file_url,
                 image_width=image_width,
                 image_height=image_height,
                 output_file_name=output_file_name,
                 license_name=license_name,
                 license_url=license_url,
                 attribution=attribution)


_args = None


def add_args(parser):
    parser.add_argument(
        '--image_load_jobs', type=int, default=8,
        help='Parallelism for loading and resizing images; '
        'too high may make the Wikipedia servers angry!')


def main(args, session):
    global _args # pylint: disable=global-statement
    _args = args

    logging.info('Deleting existing image records')
    session.query(Image).delete()

    logging.info('Loading species list')
    species_list = session.query(Species).all()

    logging.info('Fetching image metadata')
    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.image_load_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)
        for image in progress.percent(
                pool.imap(_process_image, species_list),
                len(species_list)):
            if image:
                session.add(image)
