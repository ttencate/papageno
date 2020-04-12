Papageno data
=============

This directory contains Python scripts to fetch and process input data, as well
as the resulting data files.

Pipeline description
--------------------

All scripts operate on `master.db`, which is an SQLite 3 database.

### `load_species.py`

This script parses the official [IOC World Bird
List](https://www.worldbirdnames.org/ioc-lists/master-list-2/) spreadsheet
(Multilingual Version). It outputs to the `species` table and the
`common_names` table. The `species` table tracks unique species ids, which are
small integers (16 bits) that uniquely identify a scientific name.

Note that what constitutes a "species" changes as scientific insight
progresses, which is why the IOC releases new lists every once in a while. For
our purposes, species = scientific name = species id.

xeno-canto also uses the sheets from IOC as their source; see [the Articles
section](https://www.xeno-canto.org/articles) on the site for updates about
which version they last updated to. For best results, we should use the same
version.

### `load_recordings.py`

This script fetches recording metadata through the [xeno-canto
API](https://www.xeno-canto.org/explore/api) and writes it to the `recordings`
table. It takes about an hour to run, but responses are cached, so if it fails
for some reason it can just be restarted.

Note that the xeno-canto API does pagination (returning 500 recordings at a
time), but does not order the results in any meaningful way, or offer anything
like page tokens. So if recordings are added while the script is running, the
pages might shuffle around. The result is that we may miss some recordings, or
get duplicates (which we filter out).

### `create_regions.py`

This ingests `xc.csv` and groups recordings by location into 1×1 degree
"squares" of latitude and longitude, writing the output to the `recordings`
table.

Of course, the farther you go from the equator, the more narrow and pointy
these become, but this is not really a problem for our purposes because most
birds don't live on the poles anyway.

For each square, it creates a ranking of which species were recorded, from most
to least. Basing this on the number of _recordings_, rather than some other
source like the number of _occurrences_ or _sightings_ of a species, makes
sense for this app; after all, what we most care about is which birds you're
likely to hear most.

### `regions_to_gpkg.sh`

This just converts `sources/regions.csv` to `sources/regions.gpkg` for faster
rendering in QGIS. Requires `ogr2ogr` from the GDAL package to be installed.

### `select_recordings.py`

Filters the recordings from `sources/xc.csv` down to the ones that are suitable
for our application: not too short, not too long, no background species, and of
decent quality. Then only those species are selected for which we have enough
good recordings. The output is written to `sources/selected_recordings.csv` and
`sources/selected_species.csv`.

Setting up
----------

Python 3.6 or higher is needed. Poetry is used to create and maintain a virtual
environment with all dependencies. This uses the supplied `pyproject.toml` file
to record dependencies and versions.

To create and enter such a virtual environment:

    poetry install
    poetry shell

Running
-------

All scripts can be run with `--help` to get a description of supported command
line arguments. Typically, running them without arguments will do the right
thing.

You may need to create a `cache` directory first, which is used to hold
intermediate results:

    mkdir cache

Developing
----------

Code is linted with `pylint`, which is configured through the supplied
`pylintrc`. Run like this to do the linting:

    pylint *.py
