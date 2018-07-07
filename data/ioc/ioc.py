import csv
import logging
import os.path


class Species:
    '''
    Not strictly a species, could be a subspecies too.
    '''
    def __init__(self, ioc_id, ioc_name, alt_names):
        self.id = id
        self.ioc_name = ioc_name
        self.alt_names = alt_names
        self.translations = {}

    def __str__(self):
        s = self.ioc_name
        if len(self.alt_names) > 1:
            s += ' (a.k.a. %s)' % ', '.join(alt_name for alt_name in sorted(self.alt_names) if alt_name != self.ioc_name)
        for language, translation in self.translations.items():
            s += '\n\t%s: %s' % (language, translation)
        return s


class IOCList:
    def __init__(self):
        self.species = []
        self.by_name = {}
        self.load_synonyms('IOC_8.2_vs_other_lists.csv')
        self.load_translations('Multiling IOC 8.2.csv')

    def load_synonyms(self, file_name):
        logging.info('Loading IOC synonyms file...')

        last_species = None
        with open(os.path.join(os.path.dirname(__file__), file_name), 'rt') as ioc_list:
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
                    last_species = Species(ioc_id, ioc_name, alt_names)
                    self.species.append(last_species)
                else:
                    # Subspecies not recognised by IOC, map to main species instead
                    if last_species:
                        last_species.alt_names.update(alt_names)

        for species in self.species:
            for alt_name in species.alt_names:
                if alt_name == species.ioc_name:
                    continue
                if alt_name in self.by_name and alt_name != species.ioc_name:
                    logging.warning('"%s" maps to both "%s" and "%s"', alt_name, self.by_name[alt_name], species)
                self.by_name[alt_name] = species
        for species in self.species:
            self.by_name[species.ioc_name] = species

    def load_translations(self, file_name):
        logging.info('Loading IOC multilingual file...')

        def squash_rows(iterable):
            row_number = 0
            output_row = None
            row_count = 0
            for row in iterable:
                row_number += 1
                row = row[3:]
                for i in range(len(row)):
                    row[i] = row[i].strip()
                if row_count == 0:
                    if not any(row):
                        continue
                    output_row = row
                else:
                    for i in range(len(output_row)):
                        if row[i]:
                            if output_row[i]:
                                raise RuntimeError('Overlapping rows in cell %d%s' % (row_number, chr(ord('A') + i + 3)))
                            output_row[i] = row[i]
                row_count += 1
                if row_count == 3:
                    yield output_row
                    row_count = 0
                    output_row = None

        with open(os.path.join(os.path.dirname(__file__), file_name), 'rt') as ioc_list:
            header = None
            for row in squash_rows(csv.reader(ioc_list)):
                if not header:
                    header = row
                    continue
                ioc_name = row[0]
                for i in range(1, len(row)):
                    self.by_name[ioc_name].translations[header[i]] = row[i]

    def find_by_name(self, name):
        return self.by_name.get(name, None)
