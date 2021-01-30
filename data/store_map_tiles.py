'''
Fetches the lowest couple zoom levels from OpenStreetMap for offline
availability inside the app.

Info about the tile format and URL structure:
https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
'''

import logging
import os
import os.path
import shutil
import subprocess

from fetcher import Fetcher
import progress


def add_args(parser):
    parser.add_argument(
        '--map_tiles_output_dir', 
        default=os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'map'),
        help='Target directory for offline map tiles')
    parser.add_argument(
        '--map_tiles_url_format',
        default='https://b.tile.openstreetmap.org/{z}/{x}/{y}.png', # Subdomains: a, b, c
        help='URL format for OpenStreetMap tile server')
    parser.add_argument(
        '--max_zoom_level', type=int, default=4,
        help='Maximum zoom level to fetch; level 0 is 256×256'
        ' and each subsequent level is twice the scale')


def main(args, _session):
    output_dir = args.map_tiles_output_dir

    logging.info('Deleting existing map tiles')
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)

    tiles = []
    for z in range(0, args.max_zoom_level + 1):
        n = 2**z
        for x in range(n):
            for y in range(n):
                tiles.append({'z': z, 'x': x, 'y': y})

    logging.info(f'Largest zoom level: {args.max_zoom_level} ({256 * 2**args.max_zoom_level} pixels)')
    logging.info(f'Fetching and optimizing {len(tiles)} map tiles')
    fetcher = Fetcher('map_tiles', pool_size=1)

    tile_format = '{z}_{x}_{y}.png'
    orig_data_size = 0
    opt_data_size = 0
    os.makedirs(output_dir, exist_ok=True)
    for tile in progress.percent(tiles):
        data = fetcher.fetch_cached(args.map_tiles_url_format.format(**tile))
        output_file = os.path.join(output_dir, tile_format.format(**tile))
        with open(output_file, 'wb') as f:
            f.write(data)
        subprocess.run(['optipng', '-quiet', output_file], check=True)
        orig_data_size += len(data)
        opt_data_size += os.path.getsize(output_file)

    side = 256 * 2**args.max_zoom_level
    logging.info(f'Total size of map tiles: {orig_data_size} bytes originally, {opt_data_size} bytes after optipng')
