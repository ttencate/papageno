'''
Classes that represent species and lists of species.
'''

import csv
import os.path


class Species:
    '''
    Represents a single species.
    '''

    def __init__(self, scientific_name, species_id=None, common_names=None):
        self.species_id = species_id
        self.scientific_name = scientific_name
        self.common_names = common_names or {}


class SpeciesList:
    '''
    Contains an in-memory list of Species, with quick lookup by scientific
    name, and file reading and writing operations.
    '''

    DEFAULT_FILE_NAME = os.path.join(os.path.dirname(__file__), 'sources', 'xc.csv')

    def __init__(self):
        '''
        Creates a new, empty list.
        '''
        self._by_species_id = {}
        self._by_scientific_name = {}
        self._next_species_id = 1
        self.language_codes = []

    def load(self, file_name):
        '''
        Loads the list from a CSV file. Raises FileNotFoundError if not found.
        '''
        with open(file_name, 'rt') as input_file:
            reader = csv.DictReader(input_file)
            for field in reader.fieldnames:
                if field not in ['species_id', 'scientific_name']:
                    self.add_language_code(field)
            for row in reader:
                species_id = int(row.pop('species_id'))
                scientific_name = row.pop('scientific_name')
                species = Species(scientific_name=scientific_name,
                                  species_id=species_id,
                                  common_names=row)
                self.add_species(species)

    def __len__(self):
        return len(self._by_species_id)

    def add_language_code(self, language_code):
        '''
        Adds the given language code to the common names of all species
        recorded in this list.
        '''
        assert language_code not in self.language_codes
        self.language_codes.append(language_code)
        for species in self._by_species_id:
            species.common_names[language_code] = None

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
        with open(file_name, 'wt') as output_file:
            writer = csv.DictWriter(output_file,
                                    ['species_id', 'scientific_name'] + self.language_codes)
            writer.writeheader()
            for species_id in sorted(self._by_species_id.keys()):
                species = self._by_species_id[species_id]
                row = {'species_id': species.species_id, 'scientific_name': species.scientific_name}
                row.update(species.common_names)
                writer.writerow(row)