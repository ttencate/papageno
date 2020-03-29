import 'dart:math';

enum Language {
  // scientific,
  english,
  // dutch,
}

class Species {
  final int id;
  final Map<Language, String> _names;

  Species(this.id, this._names) :
        assert(Language.values.every((language) => _names.containsKey(language)));

  String nameIn(Language language) => _names[language];
}

class SpeciesDb {
  final _species = <int, Species>{};

  SpeciesDb() {
    for (final species in [
      Species(1, {Language.english: 'great tit'}),
      Species(2, {Language.english: 'common chaffinch'}),
      Species(3, {Language.english: 'common blackbird'}),
      Species(4, {Language.english: 'common chiffchaff'}),
      Species(5, {Language.english: 'European robin'}),
      Species(6, {Language.english: 'willow warbler'}),
      Species(7, {Language.english: 'Eurasian blue tit'}),
      Species(8, {Language.english: 'Eurasian blackcap'}),
      Species(9, {Language.english: 'red crossbill'}),
      Species(10, {Language.english: 'song thrush'}),
    ]) {
      _addSpecies(species);
    }
  }

  List<int> get ids => _species.keys.toList();

  Species species(int id) => _species[id];

  void _addSpecies(Species species) {
    assert(!_species.containsKey(species.id));
    _species[species.id] = species;
  }
}

class Recording {
  final Species species;
  final String fileName;

  Recording(this.species, this.fileName);
}

class Question {
  final Recording recording;
  final List<Species> choices;

  Question(this.recording, this.choices) :
        assert(recording != null),
        assert(choices.isNotEmpty),
        assert(choices.contains(answer));

  Species get answer => recording.species;
}

class QuestionFactory {
  final _random = Random();
  final _answerCount = 4;
  final _speciesDb = SpeciesDb();

  Question createQuestion() {
    var ids = _speciesDb.ids;
    assert(ids.length >= _answerCount);
    var choices = <Species>[];
    for (var i = 0; i < _answerCount; i++) {
      var index = _random.nextInt(ids.length);
      choices.add(_speciesDb.species(ids[index]));
      ids[index] = ids.last;
      ids.removeLast();
    }
    var answer = choices[_random.nextInt(choices.length)];
    return Question(Recording(answer, 'recordings/cuckoo.mp3'), choices);
  }
}