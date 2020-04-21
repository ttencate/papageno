'''
Classes that represent species and lists of species.
'''

from sqlalchemy import Column, Integer, String, Enum, ForeignKey, Boolean
from sqlalchemy.orm import relationship

from base import Base


LANGUAGE_CODES = [
    'en',
    'af',
    'ca',
    'zh_CN',
    'zh_TW',
    'ics',
    'da',
    'nl',
    'et',
    'fi',
    'fr',
    'de',
    'hu',
    'is',
    'id',
    'it',
    'ja',
    'lv',
    'lt',
    'se',
    'no',
    'pl',
    'pt',
    'ru',
    'sk',
    'sl',
    'es',
    'sv',
    'th',
    'uk',
]


class Species(Base):
    '''
    Represents a single species.
    '''
    __tablename__ = 'species'

    species_id = Column(Integer, primary_key=True, index=True, nullable=False, autoincrement=True)
    scientific_name = Column(String, unique=True, index=True, nullable=False)
    scientific_name_clements = Column(String, index=True)

    def common_name(self, language_code):
        for common_name in self.common_names:
            if common_name.language_code == language_code:
                return common_name.common_name
        return None


class CommonName(Base):
    '''
    Represents the common name of a particular species in a particular language.
    '''
    __tablename__ = 'common_names'

    species_id = Column(Integer, ForeignKey('species.species_id'), primary_key=True, index=True)
    language_code = Column(Enum(*LANGUAGE_CODES), primary_key=True)
    common_name = Column(String)

    species = relationship('Species', back_populates='common_names')


Species.common_names = relationship('CommonName', back_populates='species')


class SelectedSpecies(Base):
    '''
    A table of all species ids that were selected to be included in the app.
    '''
    __tablename__ = 'selected_species'

    species_id = Column(String, ForeignKey('species.species_id'),
                        primary_key=True, index=True, nullable=False)
    ranking = Column(Integer, nullable=False)
