#!/usr/bin/env bash

cd "$(dirname "$0")"
ogr2ogr -oo GEOM_POSSIBLE_NAMES=geography -s_srs EPSG:4326 -t_srs EPSG:4326 sources/regions.gpkg sources/regions.csv
