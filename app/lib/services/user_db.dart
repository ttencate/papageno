import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db_migrations.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final _log = Logger('UserDb');

class UserDb {
  final AppDb _appDb;
  final Database _db;

  UserDb._fromDatabase(this._appDb, this._db);

  static Future<UserDb> open({@required AppDb appDb, DatabaseFactory factory, String path, int upgradeToVersion, bool singleInstance = true}) async {
    factory ??= databaseFactory;
    path ??= await _defaultPath();
    upgradeToVersion ??= latestVersion;
    _log.info('Opening database $path');
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: upgradeToVersion,
        singleInstance: singleInstance,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    // TODO run 'pragma quick_check' and/or 'pragma integrity_check'? Needs proper error reporting first.
    return UserDb._fromDatabase(appDb, db);
  }

  static Future<String> _defaultPath() async {
    final databasesPath = await getDatabasesPath();
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}
    return join(databasesPath, 'user.db');
  }

  Future<void> close() async {
    await _db.close();
  }

  // TODO used for tests; make unnecessary by injecting db
  Database get dbForTest => _db;

  static Future<void> _onConfigure(Database db) async {
    // Enable foreign key checks.
    await db.execute('pragma foreign_keys = on');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _onUpgrade(db, 0, version);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await upgradeToVersion(db, newVersion);
  }

  /// Returns all profiles, ordered by descending last used timestamp.
  Future<List<Profile>> getProfiles() async {
    final records = await _db.query(
        'profiles',
        orderBy: 'last_used_timestamp_ms desc');
    return records.map((record) => Profile.fromMap(record)).toList();
  }

  Future<Profile> getProfile(int profileId) async {
    final records = await _db.query(
        'profiles',
        where: 'profile_id = ?',
        whereArgs: <dynamic>[profileId]);
    return Profile.fromMap(records.single);
  }

  Future<Profile> createProfile(String name) async {
    final profileId = await _db.insert(
        'profiles',
        <String, dynamic>{'name': name});
    return await getProfile(profileId);
  }

  Future<void> renameProfile(Profile profile, String name) async {
    await _db.update(
      'profiles',
      <String, dynamic>{'name': name},
      where: 'profile_id = ?',
      whereArgs: <dynamic>[profile.profileId]
    );
  }

  Future<void> markProfileUsed(Profile profile) async {
    profile.lastUsedTimestampMs = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'profiles',
      <String, dynamic>{'last_used_timestamp_ms': profile.lastUsedTimestampMs},
      where: 'profile_id = ?',
      whereArgs: <dynamic>[profile.profileId]
    );
  }

  Future<void> deleteProfile(Profile profile) async {
    await _db.delete(
      'profiles',
      where: 'profile_id = ?',
      whereArgs: <dynamic>[profile.profileId]);
  }

  Future<String> getSetting(int profileId, String name, [String defaultValue]) async {
    final records = await _db.query(
        'settings',
        where: 'profile_id = ? and name = ?',
        whereArgs: <dynamic>[profileId, name]);
    if (records.isEmpty) {
      return defaultValue;
    } else {
      return records.single['value'] as String;
    }
  }

  Future<void> setSetting(int profileId, String name, String value) async {
    await _db.insert(
        'settings',
        <String, dynamic>{'profile_id': profileId, 'name': name, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertCourse(Course course) async {
    final courseId = await _db.insert('courses', _courseToMap(course));
    course.courseId = courseId;
  }

  Future<void> deleteCourse(Course course) async {
    await _db.delete(
        'courses',
        where: 'course_id = ?',
        whereArgs: <dynamic>[course.courseId]);
  }

  Future<Course> getCourse(int courseId) async {
    final records = await _db.query(
        'courses',
        where: 'course_id = ?',
        whereArgs: <dynamic>[courseId]);
    return await _courseFromMap(records.single);
  }

  Future<void> updateCourse(Course course) async {
    await _db.update(
        'courses',
        _courseToMap(course),
        where: 'course_id = ?',
        whereArgs: <dynamic>[course.courseId]);
  }

  /// Returns all courses in the profile.
  Future<List<Course>> courses(int profileId) async {
    final records = await _db.query(
        'courses',
        where: 'profile_id = ?',
        whereArgs: <dynamic>[profileId],
        orderBy: 'course_id');
    return await Future.wait(records.map(_courseFromMap));
  }

  Future<void> insertQuestion(int profileId, int courseId, Question question) async {
    await _db.insert('questions', _questionToMap(profileId, courseId, question));
  }

  Future<Knowledge> knowledge(int profileId) async {
    final records = await _db.query(
        'knowledge',
        where: 'profile_id = ?',
        whereArgs: <dynamic>[profileId]);
    final bySpecies = MapBuilder<Species, SpeciesKnowledge>();
    for (final record in records) {
      final species = await _appDb.speciesOrNull(record['species_id'] as int);
      if (species == null) {
        continue;
      }
      bySpecies[species] = SpeciesKnowledge.fromMap(record);
    }
    return Knowledge(bySpecies.build());
  }

  Future<SpeciesKnowledge> speciesKnowledge(int profileId, int speciesId) async {
    final records = await _db.query(
        'knowledge',
        where: 'profile_id = ? and species_id = ?',
        whereArgs: <dynamic>[profileId, speciesId]);
    if (records.isEmpty) {
      return SpeciesKnowledge.none();
    }
    return SpeciesKnowledge.fromMap(records.single);
  }

  Future<void> upsertSpeciesKnowledge(int profileId, int speciesId, SpeciesKnowledge speciesKnowledge) async {
    await _db.insert(
        'knowledge',
        <String, dynamic>{
          'profile_id': profileId,
          'species_id': speciesId,
          ...speciesKnowledge.toMap(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, dynamic> _courseToMap(Course course) => <String, dynamic>{
    'course_id': course.courseId,
    'profile_id': course.profileId,
    'location_lat': course.location.lat,
    'location_lon': course.location.lon,
    'name': course.name,
    'lessons': json.encode(<String, dynamic>{
      'unlocked_species': course.unlockedSpecies.map((s) => s.speciesId).toList(),
      'local_species': course.localSpecies.map((s) => s.speciesId).toList(),
    }),
  };

  Future<Course> _courseFromMap(Map<String, dynamic> map) async {
    final lessons = json.decode(map['lessons'] as String) as Map<String, dynamic>;
    Future<List<Species>> parseSpeciesList(List<dynamic> speciesIds) async {
      final speciesList = <Species>[];
      for (final speciesId in speciesIds) {
        final species = await _appDb.speciesOrNull(speciesId as int);
        if (species != null) {
          speciesList.add(species);
        }
      }
      return speciesList;
    }
    final unlockedSpecies = await parseSpeciesList(lessons['unlocked_species'] as List<dynamic>);
    final localSpecies = await parseSpeciesList(lessons['local_species'] as List<dynamic>);
    return Course(
      courseId: map['course_id'] as int,
      profileId: map['profile_id'] as int,
      location: LatLon(map['location_lat'] as double, map['location_lon'] as double),
      name: map['name'] as String,
      unlockedSpecies: unlockedSpecies,
      localSpecies: localSpecies,
    );
  }

  Map<String, dynamic> _questionToMap(int profileId, int courseId, Question question) {
    return <String, dynamic>{
      'profile_id': profileId,
      'course_id': courseId,
      'recording_id': question.recording.recordingId,
      'choices': json.encode(question.choices.map((species) => species.speciesId).toList()),
      'correct_species_id': question.correctAnswer.speciesId,
      'given_species_id': question.givenAnswer?.speciesId,
      'answer_timestamp': question.answerTimestamp?.millisecondsSinceEpoch,
    };
  }
}