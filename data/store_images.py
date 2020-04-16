'''
Fetches images from Wikipedia (WikiMedia Commons), then resizes and compresses
them for use in the app.
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


_fetcher = None


def _fetch_image(domain, image_page_name):
    image_info = _fetch_image_info(image_page_name)
    url = image_info['url']
    return _fetcher.fetch_cached(url)


def _process_image(image):
    '''
    Entry point for parallel processing.
    '''

    global _fetcher
    if not _fetcher:
        _fetcher = fetcher.Fetcher('wp_images', pool_size=1)

    full_output_file_name = os.path.join(_args.image_output_dir, image.output_file_name)
    if not os.path.exists(full_output_file_name) or _args.recreate_images:
        image_data = _fetcher.fetch_cached(image.image_file_url)

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


_args = None


def add_args(parser):
    parser.add_argument(
        '--image_output_dir',
        default=os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'images'),
        help='Target directory for resized and compressed images')
    parser.add_argument(
        '--image_process_jobs', type=int, default=8,
        help='Parallelism for fetching and resizing images')
    parser.add_argument(
        '--recreate_images', action='store_true',
        help='Do not assume that existing image files on disk are up to date; create them anew')
    parser.add_argument(
        '--image_size', default=1080,
        help='Maximum size in pixels of bird photos measured along the longest edge')
    parser.add_argument(
        '--image_quality', default=50,
        help='WebP quality level of bird photos')


def main(args, session):
    global _args
    _args = args

    logging.info('Fetching image records for selected species')
    images = session.query(Image)\
        .join(Species, Species.species_id == Image.species_id)\
        .join(SelectedSpecies)\
        .all()

    # https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python#35134329
    original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    with multiprocessing.pool.Pool(args.image_process_jobs) as pool:
        signal.signal(signal.SIGINT, original_sigint_handler)
        for image in progress.percent(
                pool.imap(_process_image, images),
                len(images)):
            pass
