import 'dart:math';

enum Language {
  // scientific,
  english,
  dutch,
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
      Species(1, {Language.english: 'great tit', Language.dutch: 'koolmees'}),
      Species(2, {Language.english: 'common chaffinch', Language.dutch: 'vink'}),
      Species(3, {Language.english: 'common blackbird', Language.dutch: 'merel'}),
      Species(4, {Language.english: 'common chiffchaff', Language.dutch: 'tjiftjaf'}),
      Species(5, {Language.english: 'European robin', Language.dutch: 'roodborst'}),
      Species(6, {Language.english: 'willow warbler', Language.dutch: 'fitis'}),
      Species(7, {Language.english: 'Eurasian blue tit', Language.dutch: 'pimpelmees'}),
      Species(8, {Language.english: 'Eurasian blackcap', Language.dutch: 'zwartkop'}),
      Species(9, {Language.english: 'red crossbill', Language.dutch: 'witbandkruisbek'}),
      Species(10, {Language.english: 'song thrush', Language.dutch: 'zanglijster'}),
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
        assert(choices.contains(recording.species));

  Species get answer => recording.species;

  bool isCorrect(Species species) => species == answer;
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
    return Question(Recording(answer, 'recordings/common_blackbird.mp3'), choices);
  }
}