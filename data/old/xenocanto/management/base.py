import logging

from django.db import connection
from django.core.management.base import BaseCommand, CommandError


class LoggingCommand(BaseCommand):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def create_parser(self, prog_name, subcommand):
        parser = super().create_parser(prog_name, subcommand)
        # Hacky way to set default verbosity to 2 instead of 1.
        for action in parser._actions:
            if action.dest == 'verbosity':
                action.default = 2
        return parser

    def execute(self, *args, **options):
        # 0=minimal output, 1=normal output, 2=verbose output, 3=very verbose output
        verbosity = options['verbosity']
        logging.basicConfig(level={
            0: logging.ERROR,
            1: logging.WARNING,
            2: logging.INFO,
            3: logging.DEBUG,
        }[verbosity])
        super().execute(*args, **options)
