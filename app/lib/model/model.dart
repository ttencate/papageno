import 'dart:convert';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

import '../utils/angle_utils.dart';

/// An ISO-639-1 two-letter language code with an optional ISO-3166-1 country
/// code.
///
/// This is used only for translations of bird species names, and is entirely
/// separate from the rest of the app's localization.
@immutable
class LanguageCode {
  final String languageCode;
  final String countryCode;

  const LanguageCode(this.languageCode, [this.countryCode = '']);

  LanguageCode.fromString(String string) :
      languageCode = string.split('_')[0],
      countryCode = string.contains('_') ? string.split('_')[1] : ''
  {
    assert(languageCode.length == 2);
    assert(countryCode.isEmpty || countryCode.length == 2);
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

  static const all = <LanguageCode>[
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
}

@immutable
class Species {
  final int speciesId;
  final String scientificName;
  final BuiltMap<LanguageCode, String> commonNames;

  Species(this.speciesId, this.scientificName, this.commonNames) :
        assert(LanguageCode.all.every((language) => commonNames.containsKey(language)));

  Species.fromMap(Map<String, dynamic> map) :
      speciesId = map['species_id'] as int,
      scientificName = map['scientific_name'] as String,
      commonNames = BuiltMap<LanguageCode, String>.build((builder) {
        builder.addEntries(map.entries
            .where((e) => e.key.startsWith('common_name_'))
            .map((e) => MapEntry(LanguageCode.fromString(e.key.substring(12)), e.value as String)));
        });

  String commonNameIn(LanguageCode language) {
    final commonName = commonNames[language];
    if (commonName == null || commonName.isEmpty) {
      return scientificName;
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

  double distanceTo(LatLon other) {
    // https://en.wikipedia.org/wiki/Great-circle_distance#Formulae
    const earthRadius = 6371.0;
    final angle = acos(
        sin(lat.degToRad()) * sin(other.lat.degToRad()) +
        cos(lat.degToRad()) * cos(other.lat.degToRad()) * cos(lon.degToRad() - other.lon.degToRad()));
    return angle * earthRadius;
  }
}

@immutable
class Region {
  final int regionId;
  final LatLon centroid;
  final BuiltMap<int, int> weightBySpeciesId;

  Region.fromMap(Map<String, dynamic> map) :
      regionId = map['region_id'] as int,
      centroid = LatLon(map['centroid_lat'] as double, map['centroid_lon'] as double),
      weightBySpeciesId = BuiltMap<int, int>.build((builder) {
        final json = jsonDecode(map['weight_by_species_id'] as String) as Map<String, dynamic>;
        builder.addEntries(json.entries.map((e) => MapEntry<int, int>(int.parse(e.key), e.value as int)));
      });
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

@immutable
class Quiz {
  final BuiltList<Question> questions;

  Quiz(this.questions);
}

@immutable
class Question {
  final Recording recording;
  final List<Species> choices;
  final Species answer;

  Question(this.recording, this.choices, this.answer) :
        assert(recording != null),
        assert(choices.isNotEmpty),
        assert(choices.contains(answer));

  bool isCorrect(Species species) => species == answer;
}