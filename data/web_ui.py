'''
Launches a web server serving a UI through which recordings and species can be
manually selected.
'''

import hashlib
import logging

from flask import Flask, request, abort, render_template
from sqlalchemy.orm import joinedload
from sqlalchemy.sql.expression import text

from recordings import Recording, SelectedRecording
from species import Species, SelectedSpecies


_ALLOWED_TYPES = set([
    'song', 'dawn song', 'subsong', 'canto',
    'call', 'calls', 'flight call', 'flight calls', 'nocturnal flight call', 'alarm call',
    # 'begging call', 'drumming'
    'male', 'female', 'sex uncertain', 'adult',
])


def _recording_quality(recording):
    allowed_types_score = -len(set(recording.types).difference(_ALLOWED_TYPES))
    background_species_score = -len(recording.background_species)
    quality_score = 'EDCBA'.find(recording.quality or 'E')
    length_score = 5 - abs(5 - recording.length_seconds)
    # Hash the recording_id for a stable pseudo-random tie breaker.
    hasher = hashlib.sha1()
    hasher.update(str(recording.recording_id).encode('utf-8'))
    recording_id_hash = hasher.digest()
    # Higher is better.
    return (
        allowed_types_score,
        background_species_score,
        quality_score,
        length_score,
        recording_id_hash,
    )


app = Flask(__name__)
session = None


@app.route('/')
def _root_route():
    species_selected = session.query(Species, SelectedSpecies)\
        .outerjoin(SelectedSpecies)\
        .options(joinedload(Species.common_names))\
        .order_by(text('''
            (
                select count(*)
                from recordings
                where recordings.scientific_name == species_scientific_name
            ) DESC
            '''))\
        .all()
    selected_species = []
    unselected_species = []
    remaining_species = []
    for species, selected in species_selected:
        selected = selected and selected.selected
        if selected is True:
            selected_species.append(species)
        elif selected is False:
            unselected_species.append(species)
        else:
            remaining_species.append(species)
    return render_template(
        'root.html',
        selected_species=selected_species,
        unselected_species=unselected_species,
        remaining_species=remaining_species)


@app.route('/<string:scientific_name>')
def _species_route(scientific_name):
    species = session.query(Species)\
        .filter(Species.scientific_name == scientific_name)\
        .one_or_none()
    if not species:
        abort(404)
    recordings = session.query(Recording)\
        .filter(Recording.scientific_name == scientific_name)\
        .all()
    recordings.sort(key=_recording_quality, reverse=True)

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
