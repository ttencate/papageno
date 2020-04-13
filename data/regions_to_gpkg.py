'''
Exports the `regions` table to `qgis/regions.gpkg` for display and exploration
in QGIS. Open `qgis/regions.qgz` in QGIS to view it.
'''

import logging
import os.path

from osgeo import gdal, ogr, osr
from sqlalchemy.orm import joinedload

from regions import Region
from species import Species


def add_args(parser):
    parser.add_argument(
        '--gpkg_file', default=os.path.join(os.path.dirname(__file__), 'qgis', 'regions.gpkg'),
        help='Path to output .gpkg file')


def main(args, session):
    gdal.UseExceptions()

    logging.info(f'Loading common names')
    common_names = {
        species.scientific_name: {
            common_name.language_code: common_name.common_name
            for common_name in species.common_names
        }
        for species in session.query(Species)\
            .options(joinedload(Species.common_names))
    }

    try:
        os.remove(args.gpkg_file)
        logging.info(f'Deleted previous file {args.gpkg_file}')
    except FileNotFoundError:
        pass
    logging.info(f'Creating GeoPackage {args.gpkg_file}')
    wgs84 = osr.SpatialReference()
    wgs84.ImportFromEPSG(4326)
    data_source = ogr.GetDriverByName('GPKG').CreateDataSource(args.gpkg_file)
    layer = data_source.CreateLayer('regions', geom_type=ogr.wkbPolygon, srs=wgs84)
    layer.CreateField(ogr.FieldDefn('region_id', ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn('num_species', ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn('num_recordings', ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn('ranked_species_en', ogr.OFTString))
    layer.CreateField(ogr.FieldDefn('ranked_species_nl', ogr.OFTString))

    for region in session.query(Region):
        if region.num_recordings() > 0:
            feature = ogr.Feature(layer.GetLayerDefn())
            feature.SetGeometry(ogr.CreateGeometryFromWkt(region.to_wkt()))
            feature['region_id'] = region.region_id
            feature['num_species'] = region.num_species()
            feature['num_recordings'] = region.num_recordings()
            feature['ranked_species_en'] = ', '.join(
                common_names.get(scientific_name, {}).get('en') or '?'
                for scientific_name in region.ranked_scientific_names())
            feature['ranked_species_nl'] = ', '.join(
                common_names.get(scientific_name, {}).get('nl') or '?'
                for scientific_name in region.ranked_scientific_names())
            layer.CreateFeature(feature)
