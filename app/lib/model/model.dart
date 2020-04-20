import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';

import '../db/appdb.dart';

/// Language codes for all supported languages.
///
/// This is entirely separate from the rest of the app's localization.
/// Identifiers are prefixed with `language_` because `is` is a keyword.
enum LanguageCode {
  language_en,
  language_af,
  language_ca,
  language_zh_CN,
  language_zh_TW,
  language_ics,
  language_da,
  language_nl,
  language_et,
  language_fi,
  language_fr,
  language_de,
  language_hu,
  language_is,
  language_id,
  language_it,
  language_ja,
  language_lv,
  language_lt,
  language_se,
  language_no,
  language_pl,
  language_pt,
  language_ru,
  language_sk,
  language_sl,
  language_es,
  language_sv,
  language_th,
  language_uk,
}

LanguageCode languageCodeFromString(String s) {
  s = 'LanguageCode.language_' + s;
  return LanguageCode.values.firstWhere(
      (languageCode) => languageCode.toString() == s,
      orElse: () { throw Exception('No language code ${s}; have: ${LanguageCode.values}'); },
  );
}

@immutable
class Species {
  final int speciesId;
  final String scientificName;
  final BuiltMap<LanguageCode, String> commonNames;

  Species(this.speciesId, this.scientificName, this.commonNames) :
        assert(LanguageCode.values.every((language) => commonNames.containsKey(language)));

  String commonNameIn(LanguageCode language) {
    final commonName = commonNames[language];
    if (commonName == null || commonName.isEmpty) {
      return scientificName;
    }
    return commonName;
  }
}

@immutable
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

class Quiz {

  final int totalQuestionCount = 20;
  int currentQuestionIndex = 0;

  final _random = Random();
  final _answerCount = 4;
  final AppDb _appDb;

  Quiz(this._appDb);

  Future<Question> getNextQuestion() async {
    var ids = await _appDb.allSpeciesIds();
    assert(ids.length >= _answerCount);
    var choices = <Species>[];
    for (var i = 0; i < _answerCount; i++) {
      var index = _random.nextInt(ids.length);
      choices.add(await _appDb.species(ids[index]));
      ids[index] = ids.last;
      ids.removeLast();
    }
    var answer = choices[_random.nextInt(choices.length)];
    currentQuestionIndex++;
    return Question(Recording(answer, 'recordings/common_blackbird.mp3'), choices);
  }
}