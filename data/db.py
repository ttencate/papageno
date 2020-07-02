'''
Wrapper around the master database, master.sqlite, which contains all raw and
intermediate data.
'''

import logging
import os

import sqlalchemy

from sqlalchemy.ext.compiler import compiles, deregister
from sqlalchemy.orm.session import Session
from sqlalchemy.sql.expression import Insert

from base import Base


session = None


class ExtraSession(Session):
    '''
    Simply an SQLAlchemy Session class, with some extra goodies thrown in.
    '''

    def bulk_save_objects_with_replace(self, objects):
        '''
        Like Session.bulk_save_objects, but replaces any whose primary key is
        already present. Only works on SQLite.
        '''
        # https://stackoverflow.com/questions/2218304/sqlalchemy-insert-ignore
        # This is a bit hacky, because the deregister call will remove *all*
        # visitors, not the one we just registered. But I don't see a better
        # way right now.
        def _prefix_insert_with_replace(insert, compiler, **kw):
            return compiler.visit_insert(insert.prefix_with('OR REPLACE'), **kw)
        compiles(Insert)(_prefix_insert_with_replace)
        try:
            self.bulk_save_objects(objects)
        finally:
            deregister(Insert)


def _create_engine(file_name):
    logging.info(f'Opening database {file_name}')
    return sqlalchemy.create_engine('sqlite:///' + file_name,
                                    echo=os.environ.get('ECHO_SQL') == '1')


def create_connection(file_name):
    '''
    Creates a connecting (no ORM session) to an arbitrary database.
    '''
    return _create_engine(file_name).connect()


_session_factory = sqlalchemy.orm.sessionmaker(class_=ExtraSession)


def create_session(file_name):
    '''
    Creates and returns a new session and populates it with the tables of the
    master database.
    '''
    return _session_factory(bind=_create_engine(file_name))


def create_master_schema(session): # pylint: disable=redefined-outer-name
    Base.metadata.create_all(session.connection().engine)
