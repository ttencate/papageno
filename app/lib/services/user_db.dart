import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class UserDb {
  static const _latestVersion = 6;

  final AppDb _appDb;
  final Database _db;

  UserDb._fromDatabase(this._appDb, this._db);

  static Future<UserDb> open({@required AppDb appDb}) async {
    final databasesPath = await getDatabasesPath();
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}

    final db = await openDatabase(
      join(databasesPath, 'user.db'),
      version: _latestVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // TODO run 'pragma quick_check' and/or 'pragma integrity_check'? Needs proper error reporting first.
    return UserDb._fromDatabase(appDb, db);
  }

  Future<void> close() async {
    await _db.close();
  }

  static Future<void> _onConfigure(Database db) async {
    // Enable foreign key checks.
    await db.execute('pragma foreign_keys = on');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _onUpgrade(db, 0, version);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      for (var v = oldVersion + 1; v <= newVersion; v++) {
        await _upgradeToVersion(txn, v);
      }
    });
  }

  static Future<void> _upgradeToVersion(Transaction txn, int version) {
    switch (version) {
      case 1: return _upgradeToVersion1(txn);
      case 2: return _upgradeToVersion2(txn);
      case 3: return _upgradeToVersion3(txn);
      case 4: return _upgradeToVersion4(txn);
      case 5: return _upgradeToVersion5(txn);
      case 6: return _upgradeToVersion6(txn);
      default: return Future.value();
    }
  }

  /// Creates profiles and settings tables.
  static Future<void> _upgradeToVersion1(Transaction txn) async {
    await txn.execute('''
      create table profiles (
        profile_id integer primary key autoincrement,
        name text
      )
    ''');
    await txn.execute('''
      create table settings (
        profile_id integer not null,
        name text not null,
        value text,
        primary key (profile_id, name),
        foreign key (profile_id) references profiles(profile_id) on delete cascade
      )
    ''');
  }

  /// Adds courses table.
  static Future<void> _upgradeToVersion2(Transaction txn) async {
    // The `name` field is not yet used and will always be NULL for now.
    await txn.execute('''
      create table courses (
        course_id integer primary key autoincrement,
        profile_id integer not null,
        location_lat float,
        location_lon float,
        name text,
        lessons text,
        foreign key (profile_id) references profiles(profile_id) on delete cascade
      )
    ''');
  }

  /// Adds questions table.
  static Future<void> _upgradeToVersion3(Transaction txn) async {
    await txn.execute('''
      create table questions (
        profile_id integer not null,
        course_id integer,
        recording_id string,
        choices text,
        correct_species_id integer,
        given_species_id integer,
        answer_timestamp double,
        foreign key (profile_id) references profiles(profile_id) on delete cascade
      )
    ''');
    await txn.execute('''
      create index questions_profile_id on questions(profile_id)
    ''');
  }

  /// Adds unlocked_lesson_count to courses table.
  static Future<void> _upgradeToVersion4(Transaction txn) async {
    await txn.execute('''
      alter table courses add column unlocked_lesson_count integer
    ''');
  }

  /// Adds last_used timestamp to profiles table.
  static Future<void> _upgradeToVersion5(Transaction txn) async {
    await txn.execute('''
      alter table profiles add column last_used_timestamp_ms integer
    ''');
  }

  /// Adds knowledge table.
  static Future<void> _upgradeToVersion6(Transaction txn) async {
    await txn.execute('''
      create table knowledge (
        profile_id integer not null,
        species_id integer not null,
        ebisu_time double,
        ebisu_alpha double,
        ebisu_beta double,
        last_asked_timestamp_ms int,
        primary key (profile_id, species_id),
        foreign key (profile_id) references profiles(profile_id) on delete cascade
      )
    ''');
    await txn.execute('''
      create index knowledge_profile_id on knowledge(profile_id)
    ''');
    await txn.execute('''
      create index knowledge_profile_id_species_id on knowledge(profile_id, species_id)
    ''');
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

  Future<void> updateCourseUnlockedLessons(Course course) async {
    await _db.update(
        'courses',
        <String, dynamic>{'unlocked_lesson_count': course.unlockedLessonCount},
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
    final bySpecies = <Species, SpeciesKnowledge>{};
    for (final record in records) {
      final species = await _appDb.speciesOrNull(record['species_id'] as int);
      if (species == null) {
        continue;
      }
      bySpecies[species] = SpeciesKnowledge.fromMap(record);
    }
    return Knowledge(bySpecies);
  }

  Future<SpeciesKnowledge> speciesKnowledgeOrNull(int profileId, int speciesId) async {
    final records = await _db.query(
        'knowledge',
        where: 'profile_id = ? and species_id = ?',
        whereArgs: <dynamic>[profileId, speciesId]);
    if (records.isEmpty) {
      return null;
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
    'lessons': json.encode(
      course.lessons.map((lesson) => <String, dynamic>{
        'i': lesson.index,
        's': lesson.species.map((species) => species.speciesId).toList(),
      }).toList()
    ),
    'unlocked_lesson_count': course.unlockedLessonCount,
  };

  Future<Course> _courseFromMap(Map<String, dynamic> map) async {
    final lessons = <Lesson>[];
    for (final lesson in json.decode(map['lessons'] as String) as List<dynamic>) {
      final speciesList = <Species>[];
      for (final speciesId in lesson['s'] as List<dynamic>) {
        final species = await _appDb.speciesOrNull(speciesId as int);
        if (species == null) {
          // This can happen if the species was removed from a subsequent version of the app.
          continue;
        }
        speciesList.add(species);
      }
      if (speciesList.isEmpty) {
        continue;
      }
      lessons.add(Lesson(
        index: lesson['i'] as int,
        species: speciesList.toBuiltList(),
      ));
    }
    return Course(
      courseId: map['course_id'] as int,
      profileId: map['profile_id'] as int,
      location: LatLon(map['location_lat'] as double, map['location_lon'] as double),
      lessons: lessons.toBuiltList(),
      unlockedLessonCount: map['unlocked_lesson_count'] as int,
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