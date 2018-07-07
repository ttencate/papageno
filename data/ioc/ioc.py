import csv
import logging
import os.path
import re
import sys


class Species:
    '''
    Not strictly a species, could be a subspecies too.
    '''
    def __init__(self, ioc_id, ioc_name, alt_names):
        self.id = id
        self.ioc_name = ioc_name
        self.alt_names = alt_names

    def __str__(self):
        s = self.ioc_name
        if len(self.alt_names) > 1:
            s += ' (a.k.a. %s)' % ', '.join(alt_name for alt_name in sorted(self.alt_names) if alt_name != self.ioc_name)
        return s


class IOCSynonymsList:
    def __init__(self):
        logging.info('Loading IOC alt_names file...')

        self.species = []
        last_species = None
        with open(os.path.join(os.path.dirname(__file__), 'IOC_8.2_vs_other_lists.csv'), 'rt') as ioc_list:
            is_header = True
            for row in csv.reader(ioc_list):
                if is_header:
                    is_header = False
                    continue
                ioc_id = int(row[0])
                ioc_name = row[1].strip()
                alt_names = set()
                for column in 'FHJKLMNOP':
                    alt_name = row[ord(column) - ord('A')].strip()
                    if alt_name:
                        alt_names.add(alt_name)
                if ioc_name:
                    alt_names.add(ioc_name)
                    species = Species(ioc_id, ioc_name, alt_names)
                    self.species.append(species)
                    last_species = species
                else:
                    # Subspecies not recognised by IOC, map to main species instead
                    if last_species:
                        last_species.alt_names.update(alt_names)

        self.by_name = {}
        for species in self.species:
            for alt_name in species.alt_names:
                if alt_name == species.ioc_name:
                    continue
                if alt_name in self.by_name and alt_name != species.ioc_name:
                    logging.warning('"%s" maps to both "%s" and "%s"', alt_name, self.by_name[alt_name], species)
                self.by_name[alt_name] = species
        for species in self.species:
            self.by_name[species.ioc_name] = species

        logging.info('Synonyms loaded')

    def find_by_name(self, name):
        return self.by_name.get(name, None)


if __name__ == '__main__':
    ioc = IOCSynonymsList()
    for line in sys.stdin:
        name = re.sub(r'#.*', '', line).strip()
        if not name:
            continue
        species = ioc.find_by_name(name)
        char = ' '
        if not species:
            char = 'X'
        elif name != species.ioc_name:
            char = 'C'
        print('{found}{changed} {name} -> {species}'.format(
            found=' ' if species else 'X',
            changed=' ' if not species or name == species.ioc_name else 'C',
            name=name,
            species=species))
