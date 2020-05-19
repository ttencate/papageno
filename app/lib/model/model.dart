import 'dart:math';
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:papageno/utils/angle_utils.dart';

/// An ISO-639-1 two-letter language code with an optional ISO-3166-1 country
/// code.
///
/// This is used only for translations of bird species names, and is entirely
/// separate from the rest of the app's localization.
///
/// We don't use Flutter's [Locale] class, which is similar, because it does
/// more checking than we need to, which might come to bite us later.
@immutable
class LanguageCode {
  final String languageCode;
  final String countryCode;

  const LanguageCode(this.languageCode, [this.countryCode = '']);

  factory LanguageCode.fromString(String string) {
    final parts = string.split('_');
    assert(parts.length <= 2);
    final languageCode = parts[0];
    final countryCode = parts.length >= 2 ? parts[1] : '';
    assert(languageCode.length == 2);
    assert(countryCode.isEmpty || countryCode.length == 2);
    return LanguageCode(languageCode, countryCode);
  }

  @override
  String toString() {
    if (countryCode.isEmpty) {
      return languageCode;
    } else {
      return '${languageCode}_${countryCode}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LanguageCode && languageCode == other.languageCode && countryCode == other.countryCode;

  @override
  int get hashCode => languageCode.hashCode ^ countryCode.hashCode;

  /// All languages that we support for bird species names.
  static const allSupported = <LanguageCode>[
    LanguageCode('en'),
    LanguageCode('af'),
    LanguageCode('ca'),
    // https://stackoverflow.com/questions/4892372/language-codes-for-simplified-chinese-and-traditional-chinese
    LanguageCode('zh', 'CN'),
    LanguageCode('zh', 'TW'),
    LanguageCode('cs'),
    LanguageCode('da'),
    LanguageCode('nl'),
    LanguageCode('et'),
    LanguageCode('fi'),
    LanguageCode('fr'),
    LanguageCode('de'),
    LanguageCode('hu'),
    LanguageCode('is'),
    LanguageCode('id'),
    LanguageCode('it'),
    LanguageCode('ja'),
    LanguageCode('lv'),
    LanguageCode('lt'),
    LanguageCode('se'),
    LanguageCode('no'),
    LanguageCode('pl'),
    LanguageCode('pt'),
    LanguageCode('ru'),
    LanguageCode('sk'),
    LanguageCode('sl'),
    LanguageCode('es'),
    LanguageCode('sv'),
    LanguageCode('th'),
    LanguageCode('uk'),
  ];
  /// Used if a language was requested that is not supported.
  static const fallback = LanguageCode('en');
}

@immutable
class Species {
  final int speciesId;
  final String scientificName;
  final BuiltMap<LanguageCode, String> commonNames;

  Species(this.speciesId, this.scientificName, this.commonNames) :
        assert(LanguageCode.allSupported.every((language) => commonNames.containsKey(language)));

  Species.fromMap(Map<String, dynamic> map) :
      speciesId = map['species_id'] as int,
      scientificName = map['scientific_name'] as String,
      commonNames = BuiltMap<LanguageCode, String>.build((builder) {
        builder.addEntries(map.entries
            .where((e) => e.key.startsWith('common_name_'))
            .map((e) => MapEntry(LanguageCode.fromString(e.key.substring(12)), e.value as String)));
        });

  String commonNameIn(LanguageCode language) {
    if (language == null) {
      return '';
    }
    final commonName = commonNames[language];
    if (commonName == null || commonName.isEmpty) {
      return '(${scientificName})';
    }
    return commonName;
  }

  @override
  String toString() => scientificName;

  @override
  int get hashCode => speciesId.hashCode;
}

@immutable
class Recording {
  final String recordingId;
  final int speciesId;
  final String fileName;
  final String sourceUrl;
  final String licenseName;
  final String licenseUrl;
  final String attribution;

  Recording.fromMap(Map<String, dynamic> map) :
      recordingId = map['recording_id'] as String,
      speciesId = map['species_id'] as int,
      fileName = map['file_name'] as String,
      sourceUrl = map['source_url'] as String,
      licenseName = map['license_name'] as String,
      licenseUrl = map['license_url'] as String,
      attribution = map['attribution'] as String;
}

@immutable
class Image {
  final int speciesId;
  final String fileName;
  final String sourceUrl;
  final String licenseName;
  final String licenseUrl;
  final String attribution;

  Image.fromMap(Map<String, dynamic> map) :
      speciesId = map['species_id'] as int,
      fileName = map['file_name'] as String,
      sourceUrl = map['source_url'] as String,
      licenseName = map['license_name'] as String,
      licenseUrl = map['license_url'] as String,
      attribution = map['attribution'] as String;
}

@immutable
class LatLon {
  final double lat;
  final double lon;

  LatLon(this.lat, this.lon);

  double distanceInKmTo(LatLon other) {
    // https://en.wikipedia.org/wiki/Great-circle_distance#Formulae
    const earthRadius = 6371.0;
    final angle = acos(
        sin(lat.degToRad()) * sin(other.lat.degToRad()) +
        cos(lat.degToRad()) * cos(other.lat.degToRad()) * cos(lon.degToRad() - other.lon.degToRad()));
    return angle * earthRadius;
  }

  @override
  String toString([int fractionDigits = 3]) =>
      '${lat.toStringAsFixed(fractionDigits)}, ${lon.toStringAsFixed(fractionDigits)}';
}

@immutable
class Region {
  final int regionId;
  final LatLon centroid;
  final Uint8List _weightBySpeciesId;

  BuiltMap<int, double> get weightBySpeciesId => BuiltMap.build((builder) {
    // The map is encoded as key,value,key,value,... where both keys and values
    // are big-endian unsigned 16-bits integers. Decoding it on demand saves
    // memory and time while getting Regions from the database, because the
    // weight map is often not needed.
    final bytes = _weightBySpeciesId.buffer.asByteData();
    var totalWeight = 0.0;
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      totalWeight += bytes.getUint16(i + 2, Endian.big);
    }
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      final speciesId = bytes.getUint16(i, Endian.big);
      final weight = bytes.getUint16(i + 2, Endian.big).toDouble();
      builder[speciesId] = weight / totalWeight;
    }
  });

  Region.fromMap(Map<String, dynamic> map) :
      regionId = map['region_id'] as int,
      centroid = LatLon(map['centroid_lat'] as double, map['centroid_lon'] as double),
      _weightBySpeciesId = Uint8List.fromList(map['weight_by_species_id'] as Uint8List); // Make a copy because the passed Uint8List is a view into a larger buffer.
}

@immutable
class RankedSpecies {
  final LatLon location;
  // Suffix "List" used for clarity because "species" is both singular and plural.
  final BuiltList<Species> speciesList;
  final double usedRadiusKm;

  RankedSpecies(this.location, this.speciesList, this.usedRadiusKm);
  
  int get length => speciesList.length;
}

/// A [Profile] represents a single user of the app.
/// Pretty much all other data (courses, settings, ...) is scoped to a single profile.
@immutable
class Profile {
  final int profileId;
  final String name;

  Profile(this.profileId, this.name);

  Profile.fromMap(Map<String, dynamic> map) :
      profileId = map['profile_id'] as int,
      name = map['name'] as String;
}

@immutable
class Course {
  final LatLon location;
  final BuiltList<Lesson> lessons;

  Course(this.location, this.lessons);

  int get speciesCount => lessons.map((lesson) => lesson.species.length).fold(0, (a, b) => a + b);
}

@immutable
class Lesson {
  final int index;
  final BuiltList<Species> species;

  Lesson(this.index, this.species);

  int get number => index + 1;
}

class Quiz {
  final BuiltList<Question> questions;
  int _currentQuestionIndex = 0;

  Quiz(this.questions);

  int get questionCount => questions.length;

  bool get isComplete => _currentQuestionIndex >= questionCount;

  int get currentQuestionIndex => _currentQuestionIndex;
  int get currentQuestionNumber => _currentQuestionIndex + 1;

  Question get currentQuestion => isComplete ? null : questions[_currentQuestionIndex];

  void proceedToNextQuestion() {
    assert(!isComplete);
    _currentQuestionIndex++;
  }

  int get correctAnswerCount => questions.where((question) => question.isCorrect == true).length;

  int get scorePercent => correctAnswerCount * 100 ~/ questionCount;

  Set<Species> get fullyCorrectSpecies =>
      questions
      .map((question) => question.correctAnswer)
      .toSet()
      ..removeAll(incorrectQuestions.map((question) => question.correctAnswer))
      ..removeAll(incorrectQuestions.map((question) => question.givenAnswer));

  List<Question> get correctQuestions => questions.where((question) => question.isCorrect == true).toList();
  List<Question> get incorrectQuestions => questions.where((question) => question.isCorrect == false).toList();
}

class Question {
  final Recording recording;
  final List<Species> choices;
  final Species correctAnswer;
  Species _givenAnswer;

  Question(this.recording, this.choices, this.correctAnswer) :
        assert(recording != null),
        assert(choices.isNotEmpty),
        assert(choices.contains(correctAnswer));

  bool get isAnswered => _givenAnswer != null;

  bool get isCorrect => isAnswered ? _givenAnswer == correctAnswer : null;

  Species get givenAnswer => _givenAnswer;

  void answerWith(Species answer) {
    assert(_givenAnswer == null);
    assert(answer != null);
    _givenAnswer = answer;
  }
}