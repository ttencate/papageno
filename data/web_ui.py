'''
Launches a web server serving a UI through which recordings and species can be
manually selected.
'''

import logging

from flask import Flask, request, abort, render_template
from sqlalchemy import func
from sqlalchemy.orm import joinedload
from sqlalchemy.sql.expression import text

import analysis
from recordings import Recording, SelectedRecording
from species import Species, SelectedSpecies


app = Flask(__name__)
session = None


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
        .order_by(recording_counts_subquery.c.num_recordings.desc())\
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
        if any('song' in type for type in types):
            groups['song'].append(recording)
        elif any('call' in type for type in types):
            groups['call'].append(recording)
        else:
            groups['other'].append(recording)
    for group in list(groups.keys()):
        group_sizes[group] = len(groups[group])
        groups[group] = groups[group][:group_size_limit]

    selected_recording_ids = [
        selected_recording.recording_id
        for selected_recording in session.query(SelectedRecording)\
            .join(Recording)\
            .filter(Recording.scientific_name == scientific_name)
    ]

    return render_template(
        'species.html',
        species=species,
        groups=groups,
        group_sizes=group_sizes,
        group_size_limit=group_size_limit,
        selected_recording_ids=selected_recording_ids)


@app.route('/select_recording/<string:recording_id>/<int:selected>', methods=['POST'])
def _select_recording_route(recording_id, selected):
    if not session.query(Recording).filter(Recording.recording_id == recording_id).one_or_none():
        abort(404)
    was_selected = session.query(SelectedRecording).filter(SelectedRecording.recording_id == recording_id).one_or_none()
    if selected and not was_selected:
        logging.info(f'Selecting {recording_id}')
        session.add(SelectedRecording(recording_id=recording_id))
        session.commit()
    elif was_selected and not selected:
        logging.info(f'Deselecting {recording_id}')
        session.delete(was_selected)
        session.commit()
    return ''


def main(unused_args, session_):
    global session # pylint: disable=global-statement
    session = session_

    host = 'localhost'
    port = 8080
    logging.info(f'Launching web server on http://{host}:{port}/')
    # Database session is not thread safe, so we need to disable threading here.
    app.run(host=host, port=port, threaded=False)
