'''
Classes that represent species and lists of species.
'''

import csv
import logging
import os.path

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


class Species:
    '''
    Represents a single species.
    '''

    def __init__(self, scientific_name, species_id=None, common_names=None):
        self.species_id = species_id
        self.scientific_name = scientific_name
        self.common_names = common_names or {key: None for key in LANGUAGE_CODES}


class SpeciesList:
    '''
    Contains an in-memory list of Species, with quick lookup by scientific
    name, and file reading and writing operations.
    '''

    DEFAULT_FILE_NAME = os.path.join(os.path.dirname(__file__), 'sources', 'species.csv')

    def __init__(self):
        '''
        Creates a new, empty list.
        '''
        self._by_species_id = {}
        self._by_scientific_name = {}
        self._next_species_id = 1

    def load(self, file_name):
        '''
        Loads the list from a CSV file. Raises FileNotFoundError if not found.
        '''
        logging.info(f'Loading species from {file_name}')
        with open(file_name, 'rt') as input_file:
            reader = csv.DictReader(input_file)
            for row in reader:
                species_id = int(row.pop('species_id'))
                scientific_name = row.pop('scientific_name')
                species = Species(scientific_name=scientific_name,
                                  species_id=species_id,
                                  common_names=row)
                self.add_species(species)
        logging.info(f'Loaded {len(self)} species')

    def __len__(self):
        return len(self._by_species_id)

    def __iter__(self):
        return iter(self._by_species_id.values())

    def get_species(self, scientific_name):
        '''
        Returns a species by scientific name. Raises KeyError if not found.
        '''
        return self._by_scientific_name[scientific_name]

    def add_species(self, species):
        '''
        Adds the given species. If its species_id is None, it will be assigned.
        If it's not None, the caller is responsible for not causing conflicts.
        '''
        if species.species_id is None:
            species.species_id = self._next_species_id
            self._next_species_id += 1
        elif species.species_id in self._by_species_id:
            raise ValueError(f'Species list already contains species id {species.species_id}')
        self._by_species_id[species.species_id] = species
        self._by_scientific_name[species.scientific_name] = species

    def save(self, file_name):
        '''
        Saves the list to a CSV file, ordered by species_id.
        '''
        logging.info(f'Saving {len(self)} species to {file_name}')
        with open(file_name, 'wt') as output_file:
            writer = csv.DictWriter(output_file,
                                    ['species_id', 'scientific_name'] + LANGUAGE_CODES)
            writer.writeheader()
            for species_id in sorted(self._by_species_id.keys()):
                species = self._by_species_id[species_id]
                row = {'species_id': species.species_id, 'scientific_name': species.scientific_name}
                row.update(species.common_names)
                writer.writerow(row)
