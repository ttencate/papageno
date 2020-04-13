Papageno data
=============

This directory contains Python scripts to fetch and process input data. Its
output is a SQLite3 database called `master.db`.

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

To get a description of the pipeline stages, run:

    ./master.py --help

Typically, none of the optional arguments are needed; the defaults are set to
the values used to produce the "official" `master.db`.

You may need to create a `cache` directory first, which is used to hold
intermediate results:

    mkdir cache

Developing
----------

Code is linted with `pylint`, which is configured through the supplied
`pylintrc`. Run like this to do the linting:

    pylint *.py
