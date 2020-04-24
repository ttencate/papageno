import 'dart:convert';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';

import '../utils/angle_utils.dart';

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

  Species.fromMap(Map<String, dynamic> map) :
      speciesId = map['species_id'] as int,
      scientificName = map['scientific_name'] as String,
      commonNames = BuiltMap<LanguageCode, String>.build((builder) {
        builder.addEntries(map.entries
            .where((e) => e.key.startsWith('common_name_'))
            .map((e) => MapEntry(languageCodeFromString(e.key.substring(12)), e.value as String)));
        });

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