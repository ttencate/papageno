'''
Loads city names and locations, and selects those to be included in the app.

It selects those cities that don't have a nearby city that is bigger. "Bigger"
is defined as having greater population. "Nearby" is defined as within a fixed
distance (in km) as the crow flies.
'''

import io
import logging
import math
import os
import zipfile

import rtree

from cities import City
import progress


_EARTH_RADIUS_KM = 6371.0


def _deg2rad(deg):
    return deg * (math.pi / 180.0)


def _lat_lon_to_point(lat, lon):
    '''
    Converts lat/lon (degrees) to a 3D point in km, where (0, 0, 0) is the
    center of the Earth.
    Assumes that Earth is a perfect sphere. Good enough for our purposes.
    '''
    cos_lat = math.cos(_deg2rad(lat))
    sin_lat = math.sin(_deg2rad(lat))
    cos_lon = math.cos(_deg2rad(lon))
    sin_lon = math.sin(_deg2rad(lon))
    return (
        _EARTH_RADIUS_KM * cos_lat * cos_lon,
        _EARTH_RADIUS_KM * cos_lat * sin_lon,
        _EARTH_RADIUS_KM * sin_lat,
    )


def _great_circle_to_cartesian_distance(great_circle_distance_km):
    angle = great_circle_distance_km / _EARTH_RADIUS_KM
    return 2.0 * _EARTH_RADIUS_KM * math.sin(0.5 * angle)


def _cartesian_distance(a, b):
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    return math.sqrt(dx*dx + dy*dy + dz*dz)


def _box_around(point, r):
    x, y, z = point
    return (x - r, y - r, z - r, x + r, y + r, z + r)


def add_args(parser):
    parser.add_argument(
        '--reselect_cities',
        action='store_true',
        help='Select cities anew, even if some are already in the database')
    parser.add_argument(
        '--cities_file',
        default=os.path.join(os.path.dirname(__file__), 'sources', 'cities500.zip'),
        help='Path to zip file with cities from GeoNames')
    parser.add_argument(
        '--cities_to_select',
        type=int, default=25000,
        help='How many cities to select')
    parser.add_argument(
        '--cities_select_population_sigma_km',
        type=float, default=20.0,
        help='Standard deviation of Gaussian used for city population weight calculations')


def main(args, session):
    if session.query(City).count() and not args.reselect_cities:
        logging.info('Selected cities exist and reselection not requested')
        return

    logging.info('Deleting existing cities')
    session.query(City).delete()

    cities = []
    cities_by_id = {}
    points = {}
    with zipfile.ZipFile(args.cities_file, 'r') as zip_file:
        file_name = zip_file.namelist()[0]
        logging.info(f'Loading {file_name} from {args.cities_file}')
        with zip_file.open(file_name, 'r') as tsv_file:
            for line in io.TextIOWrapper(tsv_file):
                row = line.rstrip('\n').split('\t')
                city = City(
                    city_id=int(row[0]),
                    name=row[1],
                    lat=float(row[4]),
                    lon=float(row[5]),
                    population=int(row[14]))
                if city.population <= 0:
                    continue
                cities.append(city)
                cities_by_id[city.city_id] = city
                points[city.city_id] = _lat_lon_to_point(city.lat, city.lon)
                #if len(cities) >= 10000:
                #   break
    max_population = max(city.population for city in cities)
    logging.info(f'Loaded {len(cities)} cities; maximum population is {max_population}')

    logging.info('Indexing cities')
    prop = rtree.index.Property()
    prop.dimension = 3
    index = rtree.index.Index(properties=prop)
    for city in progress.percent(cities):
        city_point = points[city.city_id]
        index.insert(city.city_id, (*city_point, *city_point))

    logging.info('Computing city weights')
    sigma = args.cities_select_population_sigma_km
    max_distance = _great_circle_to_cartesian_distance(3.0 * sigma)
    weights = {}
    for city in progress.percent(cities):
        city_point = points[city.city_id]
        region_population = 0
        for nearby_id in index.intersection(_box_around(city_point, max_distance)):
            nearby_distance = _cartesian_distance(points[nearby_id], city_point)
            if nearby_distance <= max_distance:
                d = nearby_distance / sigma
                population = cities_by_id[nearby_id].population * math.exp(-0.5 * d*d)
                region_population += population
        weights[city.city_id] = city.population / region_population

    logging.info(f'Selecting {args.cities_to_select} cities')
    cities.sort(key=lambda city: weights[city.city_id], reverse=True)
    selected_cities = cities[:args.cities_to_select]

    logging.info(f'Storing {len(selected_cities)} selected cities')
    session.bulk_save_objects(selected_cities)
