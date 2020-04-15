'''
Fetches images from Wikipedia (WikiMedia Commons).
'''

import io
import json
import logging
import multiprocessing
import os.path
import re
import signal
import urllib.parse

from bs4 import BeautifulSoup
import PIL

import fetcher
import progress
from images import Image
from species import Species, SelectedSpecies


_fetcher = fetcher.Fetcher('wp_pages', pool_size=10)


class ParseError(RuntimeError):
    pass


def _page_url(domain, page_name):
    return f'https://{domain}/wiki/{urllib.parse.quote_plus(page_name.replace(" ", "_"))}'


def _fetch_wiki(domain, page_name, prop):
    '''
    prop is either 'text' (for HTML) or 'wikitext' (for original wikitext markup).
    '''
    # https://www.mediawiki.org/wiki/API:Get_the_contents_of_a_page
    url = (f'https://{domain}/w/api.php'
           '?action=parse'
           f'&page={urllib.parse.quote_plus(page_name)}'
           '&redirects'
           f'&prop={prop}'
           '&format=json'
           '&formatversion=2')
    response = _fetcher.fetch_cached(url)
    try:
        return json.loads(response)['parse'][prop]
    except KeyError as ex:
        raise ParseError(f'Key not found in response to {url}') from ex


def _fetch_image_info(page_name):
    # https://commons.wikimedia.org/wiki/File%3ASolitarysandpiper.jpg does not
    # exist; this file comes from Wikipedia directly!
    for domain in ['commons.wikimedia.org', 'en.wikipedia.org']:
        url = (f'https://{domain}/w/api.php'
               '?action=query'
               '&prop=imageinfo'
               f'&titles={urllib.parse.quote_plus(page_name)}'
               '&redirects'
               '&iiprop=url|extmetadata'
               '&formatversion=2'
               '&format=json')
        response = _fetcher.fetch_cached(url)
        try:
            page = json.loads(response)['query']['pages'][0]
            if page.get('missing'):
                continue
            return page['imageinfo'][0]
        except (KeyError, IndexError) as ex:
            raise ParseError(f'Key or index not found in response to {url}') from ex
    raise ParseError(f'{page_name} was not found')


def _fetch_image(domain, image_page_name):
    image_info = _fetch_image_info(image_page_name)
    url = image_info['url']
    return _fetcher.fetch_cached(url)


def _parse_speciesbox(wikitext):
    # I found out too late that there's a way to extract the parse tree as XML:
    # https://en.wikipedia.org/w/api.php?action=parse&prop=parsetree&page=Plain_antvireo&format=json
    # That would be more robust. But this regex approach seems to work fine too.
    def _extract_key(key):
        m = re.search(key + r'\s*=\s*(.*?)\s*[|}]', wikitext, re.IGNORECASE)
        if not m:
            return None
        return m.group(1)
    genus, species = _extract_key('genus'), _extract_key('species')
    if not genus or not species:
        genus, species = _extract_key('taxon').split()
    image_page_name = _extract_key('image')
    if image_page_name:
        # Looking at you, https://en.wikipedia.org/w/index.php?title=Setophaga_pensylvanica
        image_page_name = re.sub(r'<!--.*-->', '', image_page_name).strip()
        # Looking at you, https://en.wikipedia.org/wiki/Marmora%27s_warbler
        image_page_name = urllib.parse.unquote(image_page_name)
        # Looking at you, https://en.wikipedia.org/wiki/Kelp_gull with your {{CSS Image Crop}}
        if (genus, species) == ('Larus', 'dominicanus'):
            image_page_name = 'SouthShetland-2016-Livingston Island (Hannah Point)–Kelp gull (Larus dominicanus).jpg'
        # The prefix is usually omitted, but not always.
        if not image_page_name.startswith('File:'):
            image_page_name = 'File:' + image_page_name
    return (genus, species, image_page_name)


def _fetch_license(domain, image_page_name):
    image_info = _fetch_image_info(image_page_name)
    def info_field(key):
        return image_info['extmetadata'].get(key, {}).get('value', None)
    
    license_name = info_field('LicenseShortName')
    if license_name == 'PD':
        license_name = 'Public domain'
    if license_name:
        # Sometimes we get "CC BY-SA 3.0", sometimes "CC-BY-SA-3.0".
        license_name = re.sub(r'^CC[- ](.*)[- ](\d\.\d)$', r'CC \1 \2', license_name)
    if not license_name:
        raise ParseError('No license found')

    license_url = info_field('LicenseUrl')
    if license_url and license_url.startswith('//'):
        license_url = 'https:' + license_url

    attribution = info_field('Attribution') or info_field('Artist')
    if attribution:
        soup = BeautifulSoup(attribution, 'html.parser')
        attribution = soup.get_text().strip()
    attribution_required = info_field('AttributionRequired') == 'true'
    if attribution_required and not attribution:
        logging.error(f'Attribution required for {image_page_name} but no author found')

    return license_name, license_url, attribution


def _process_image(species):
    '''
    Entry point for parallel processing.
    '''

    species_id, scientific_name = species

    try:
        page_url = _page_url('en.wikipedia.org', scientific_name)
        wikitext = _fetch_wiki('en.wikipedia.org', scientific_name, 'wikitext')
        genus, species, image_page_name = _parse_speciesbox(wikitext)
        # Sometimes we get stuff like genus = "Acrocephalus (bird)" so a
        # simple match is too simple.
        if scientific_name.split()[0] not in genus or \
                scientific_name.split()[1] not in species:
            # Logging at debug level is enough; this happens regularly and
            # was always benign in the cases that I checked (all
            # disagreements or changes in taxonomy).
            logging.info(f'Page {page_url} is actually about {genus} {species}')
    except Exception as ex:
        raise ParseError(f'Error getting image page URL for {scientific_name} '
                         f'from <{page_url}>: {ex!r}')

    if not image_page_name:
        logging.warning(f'Page {page_url} for {scientific_name} contains no image')
        return None

    try:
        image_page_url = _page_url('commons.wikimedia.org', image_page_name)
        license_name, license_url, attribution = _fetch_license('commons.wikimedia.org', image_page_name)
        # print(f'{image_page_url}\n  {license}\n  {license_url}\n  {attribution}\n')
    except Exception as ex:
        raise ParseError(f'Error getting image license for {scientific_name} '
                         f'from <{image_page_url}>: {ex!r}')

    output_dir = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'photos')
    output_file_name = scientific_name.replace(' ', '_') + '.webp'
    full_output_file_name = os.path.join(output_dir, output_file_name)
    if _args.recreate_images or not os.path.exists(full_output_file_name):
        image_data = _fetch_image('commons.wikimedia.org', image_page_name)

        image = PIL.Image.open(io.BytesIO(image_data))

        if image.width > _args.image_size or image.height > _args.image_size:
            if image.width >= image.height:
                output_width = _args.image_size
                output_height = round(output_width / image.width * image.height)
            else:
                output_height = _args.image_size
                output_width = round(output_height / image.height * image.width)
            image = image.resize((output_width, output_height), resample=PIL.Image.LANCZOS)

        image.save(full_output_file_name,
                   format='WebP', quality=_args.image_quality)

    return Image(species_id=species_id,
                 file_name=output_file_name,
                 license_name=license_name,
                 license_url=license_url,
                 attribution=attribution)


_args = None


def add_args(parser):
    parser.add_argument(
        '--image_process_jobs', default=8,
        help='Parallelism for loading and resizing images')
    parser.add_argument(
        '--image_size', default=1080,
        help='Maximum size in pixels of bird photos measured along the longest edge')
    parser.add_argument(
        '--image_quality', default=50,
        help='WebP quality level of bird photos')
    parser.add_argument(
        '--recreate_images', action='store_true',
        help='Do not assume that existing image files on disk are up to date; create them anew')


def main(args, session):
    global _args
    _args = args

    logging.info('Ordering selected species from most to least recorded')
    selected_species = session.execute(
        '''
        select species_id, scientific_name
        from selected_species
        inner join species using (species_id)
        left join recordings using (scientific_name)
        group by species_id
        order by count(*) desc
        ''')\
        .fetchall()

    logging.info('Deleting existing image records')
    session.query(Image).delete()

    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.image_process_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)
        for image in progress.percent(
                pool.imap(_process_image, selected_species),
                len(selected_species)):
            if image:
                session.add(image)
