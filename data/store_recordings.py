'''
Copies trimmed recordings to the app's assets directory.
'''

import logging
import os
import os.path
import shutil

import progress
from recordings import Recording, SelectedRecording


def add_args(parser):
    # Arg added by trim_recordings stage.
    # parser.add_argument(
    #     '--trimmed_recordings_dir',
    #     default=os.path.join(os.path.dirname(__file__), 'cache', 'trimmed_recordings'),
    #     help='Where to find trimmed recording files')
    parser.add_argument(
        '--assets_recordings_dir',
        default=os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'sounds'),
        help='Output directory for recordings to be included in app assets')


_args = None


def main(args, session):
    logging.info('Loading selected recordings')
    selected_recordings = session.query(Recording).join(SelectedRecording).all()

    old_trimmed_recordings = os.listdir(args.assets_recordings_dir)
    logging.info(f'Deleting {len(old_trimmed_recordings)} old trimmed recordings')
    for old_trimmed_recording in old_trimmed_recordings:
        try:
            os.remove(os.path.join(args.assets_recordings_dir, old_trimmed_recording))
        except OSError as ex:
            logging.warning(f'Could not delete {old_trimmed_recording}: {ex}')

    logging.info('Copying trimmed recordings')
    for selected_recording in progress.percent(selected_recordings):
        input_file_name = os.path.join(
            args.trimmed_recordings_dir,
            f'{selected_recording.recording_id}.ogg')
        # Android hates colons in file names in a really nonobvious way:
        # https://stackoverflow.com/questions/52245654/failed-to-open-file-permission-denied
        output_file_name = os.path.join(
            args.assets_recordings_dir,
            f'{selected_recording.recording_id.replace(":", "_")}.ogg')
        shutil.copyfile(input_file_name, output_file_name)
