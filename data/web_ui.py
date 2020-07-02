#!/usr/bin/env python

'''
Launches a web server serving a UI through which recordings and species can be
manually selected.
'''

import argparse
import logging
import os.path
import sys

from flask import Flask, request, abort, render_template, send_file
from sqlalchemy import func
from sqlalchemy.orm import joinedload

import analysis
import db
from recordings import Recording, SelectedRecording, RecordingOverrides
from species import Species, SelectedSpecies
from select_recordings import select_recordings
from trim_recordings import trim_recording


app = Flask(__name__)
session = None
recording_overrides = None


@app.route('/')
def _root_route():
    recording_counts_subquery = session\
        .query(Species.species_id, func.count('*').label('num_recordings'))\
        .join(Recording, Species.scientific_name == Recording.scientific_name)\
        .group_by(Species.species_id)\
        .subquery()
    species_with_selection = session.query(Species, SelectedSpecies)\
        .outerjoin(SelectedSpecies, Species.species_id == SelectedSpecies.species_id)\
        .join(recording_counts_subquery, recording_counts_subquery.c.species_id == Species.species_id)\
        .options(joinedload(Species.common_names))\
        .order_by(SelectedSpecies.ranking, recording_counts_subquery.c.num_recordings.desc())\
        .all()
    selected_species = [species for (species, selected) in species_with_selection if selected]
    unselected_species = [species for (species, selected) in species_with_selection if not selected]
    recording_counts = dict(session\
        .query(Species.species_id, func.count('*').label('num_recordings'))\
        .join(Recording, Species.scientific_name == Recording.scientific_name)\
        .group_by(Species.species_id)\
        .all())
    selected_recording_counts = dict(session\
        .query(Species.species_id, func.count('*').label('num_recordings'))\
        .join(Recording, Species.scientific_name == Recording.scientific_name)\
        .join(SelectedRecording, SelectedRecording.recording_id == Recording.recording_id)\
        .group_by(Species.species_id)\
        .all())
    return render_template(
        'root.html',
        selected_species=selected_species,
        unselected_species=unselected_species,
        recording_counts=recording_counts,
        selected_recording_counts=selected_recording_counts)


@app.route('/<string:scientific_name>')
def _species_route(scientific_name):
    species = session.query(Species)\
        .filter(Species.scientific_name == scientific_name)\
        .one_or_none()
    if not species:
        abort(404)
    recordings = session.query(Recording)\
        .options(joinedload(Recording.sonogram_analysis))\
        .filter(Recording.scientific_name == scientific_name)\
        .all()
    recordings.sort(key=analysis.recording_quality, reverse=True)

    group_size_limit = int(request.args.get('group_size_limit', 30))
    groups = {
        'song': [],
        'call': [],
        'other': [],
    }
    group_sizes = {group: 0 for group in groups}
    for recording in recordings:
        types = recording.types
        song = any('song' in type for type in types)
        call = any('call' in type for type in types)
        if song and not call:
            groups['song'].append(recording)
        elif call and not song:
            groups['call'].append(recording)
        else:
            groups['other'].append(recording)
    for group in list(groups.keys()):
        group_sizes[group] = len(groups[group])
        groups[group] = groups[group][:group_size_limit]

    selected_recordings_by_id = {
        selected_recording.recording_id: selected_recording
        for selected_recording in session.query(SelectedRecording)\
            .join(Recording)\
            .filter(Recording.scientific_name == scientific_name)
    }

    return render_template(
        'species.html',
        species=species,
        groups=groups,
        group_sizes=group_sizes,
        group_size_limit=group_size_limit,
        selected_recordings_by_id=selected_recordings_by_id,
        recording_overrides=recording_overrides)


@app.route('/trimmed_recordings/<string:recording_id>')
def _trimmed_recording_route(recording_id):
    recording = session.query(Recording).filter(Recording.recording_id == recording_id).one()
    file_name = trim_recording(recording, skip_if_exists=True)
    return send_file(file_name, mimetype='audio/ogg')


@app.route('/recording_override/<string:recording_id>', methods=['POST'])
def _recording_override_route(recording_id):
    status = request.json['status']
    reason = request.json['reason']
    if not session.query(Recording).filter(Recording.recording_id == recording_id).one_or_none():
        abort(404)

    if status:
        logging.info(f'Setting override for {recording_id} to {status} ({reason})')
        recording_overrides.set(recording_id, status, reason)
    else:
        logging.info(f'Removing override for {recording_id}')
        recording_overrides.delete(recording_id)
    recording_overrides.save()

    recording = session.query(Recording).filter(Recording.recording_id == recording_id).one()
    species = session.query(Species).filter(Species.scientific_name == recording.scientific_name).one()
    select_recordings(session, species, recording_overrides)
    session.commit()

    return ''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--log_level', default='info', choices=['debug', 'info', 'warning', 'error', 'critical'],
        help='Verbosity of logging')
    parser.add_argument(
        '--watch', action='store_true',
        help='Automatically restart the server if source code or templates are changed')
    args = parser.parse_args()

    log_level = getattr(logging, args.log_level.upper())
    logging.basicConfig(level=log_level)

    global session # pylint: disable=global-statement
    global recording_overrides # pylint: disable=global-statement
    session = db.create_session(os.path.join(os.path.dirname(__file__), 'master.db'))
    recording_overrides = RecordingOverrides()

    host = 'localhost'
    port = 8080
    logging.info(f'Launching web server on http://{host}:{port}/')
    # Database session is not thread safe, so we need to disable threading here.
    app.run(host=host, port=port, debug=args.watch, threaded=False)


if __name__ == '__main__':
    sys.exit(main())
