#!/usr/bin/env python3

import logging
import sqlite3
import sys

from xenocanto import xenocanto


SQL_FIELD_DEFS = '''
    id TEXT PRIMARY KEY,
    gen TEXT,
    sp TEXT,
    ssp TEXT,
    en TEXT,
    rec TEXT,
    cnt TEXT,
    loc TEXT,
    lat REAL,
    lng REAL,
    type TEXT,
    file TEXT,
    lic TEXT,
    url TEXT,
    q TEXT,
    time TEXT,
    date TEXT,
    sonogram_url TEXT,
    elevation_m INTEGER,
    length_s REAL,
    sampling_rate_hz INTEGER,
    bitrate_bps INTEGER,
    channels INTEGER,
    volume TEXT,
    speed TEXT,
    pitch TEXT,
    sound_length TEXT,
    number_of_notes TEXT,
    variable TEXT
'''
FIELDS = [tuple(f.strip().split(None, 1)) for f in SQL_FIELD_DEFS.split(',')]


def main():
    logging.basicConfig(level=logging.INFO)

    conn = sqlite3.connect('data.db')

    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS xc_recordings (%s)''' % SQL_FIELD_DEFS)

    for line in sys.stdin:
        try:
            metadata = xenocanto.fetch_metadata_cached(int(line))
        except RuntimeError as ex:
            logging.warning(ex)
            continue
        cursor.execute(
                '''INSERT INTO xc_recordings VALUES (%s)''' % ','.join(['?'] * len(FIELDS)),
                [metadata[f[0]] for f in FIELDS])

    conn.commit()
    conn.close()


if __name__ == '__main__':
    main()
