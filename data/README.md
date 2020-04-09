Papageno data
=============

This directory contains Python scripts to fetch and process input data, as well
as the resulting data files.

Pipeline description
--------------------

* `update_xc` fetches recording metadata through the [XenoCanto
  API](https://www.xeno-canto.org/explore/api) and writes it to
  `sources/xc.csv`.

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
