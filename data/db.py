'''
Wrapper around the master database, master.sqlite, which contains all raw and
intermediate data.
'''

import logging
import os
import os.path

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
    engine = sqlalchemy.create_engine('sqlite:///' + file_name, echo=os.environ.get('ECHO_SQL') == '1')
    Base.metadata.create_all(engine)
    return engine


_session_factory = sqlalchemy.orm.sessionmaker(class_=ExtraSession)


def create_session(file_name=os.path.join(os.path.dirname(__file__), 'master.db')):
    return _session_factory(bind=_create_engine(file_name))
