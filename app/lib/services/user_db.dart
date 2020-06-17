import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final _log = Logger('UserDb');

class UserDb {
  static const _latestVersion = 6;

  final AppDb _appDb;
  final Database _db;

  UserDb._fromDatabase(this._appDb, this._db);

  static Future<UserDb> open({@required AppDb appDb, DatabaseFactory factory, String path, int upgradeToVersion, bool singleInstance = true}) async {
    factory ??= databaseFactory;
    upgradeToVersion ??= _latestVersion;
    _log.info('Opening database $path');
    final db = await factory.openDatabase(
      path ?? await _defaultPath(),
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

  /// Only used for testing the migrations themselves.
  /// TODO decouple migrations from UserDb so we can do this in a better way.
  Future<void> upgradeForTest(int version) async {
    await _onUpgrade(_db, await _db.getVersion(), version);
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
    await db.transaction((txn) async {
      for (var v = oldVersion + 1; v <= newVersion; v++) {
        await _upgradeToVersion(txn, v);
      }
    });
  }

  static Future<void> _upgradeToVersion(Transaction txn, int version) {
    _log.info('Running migration for version $version');
    switch (version) {
      // TODO pull out migrations to a separate file, in a `const List<Migration>`.
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
        lessons text, -- Format changed in version 6.
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
        answer_timestamp double, -- Note: we actually store integers (milliseconds) here!
        foreign key (profile_id) references profiles(profile_id) on delete cascade
      )
    ''');
    await txn.execute('''
      create index questions_profile_id on questions(profile_id)
    ''');
  }

  /// Adds unlocked_lesson_count to courses table.
  static Future<void> _upgradeToVersion4(Transaction txn) async {
    // Since version 6, this column is no longer used.
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

  /// Adds knowledge table and populates it.
  /// This duplicates some code from the controller, because we don't want the database layer to depend on the
  /// controller layer. And also, because we want to be able to change the controller but keep the migration frozen.
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

    final existingProfileIds = (await txn.query('profiles', columns: <String>['profile_id']))
        .map((Map<String, dynamic> r) => r['profile_id'] as int)
        .toSet();
    final profiles = <int, Map<int, SpeciesKnowledge>>{
      for (final profileId in existingProfileIds) profileId: <int, SpeciesKnowledge>{},
    };

    final questionRecords = await txn.query(
        'questions',
        columns: <String>['profile_id', 'correct_species_id', 'given_species_id', 'answer_timestamp'],
        orderBy: 'answer_timestamp');
    for (final record in questionRecords) {
      final profileId = record['profile_id'] as int;
      final profile = profiles[profileId];
      if (profile == null) {
        continue;
      }

      final correctSpeciesId = record['correct_species_id'] as int;
      final givenSpeciesId = record['given_species_id'] as int;
      final correct = givenSpeciesId == correctSpeciesId;
      final answerTimestamp = DateTime.fromMillisecondsSinceEpoch((record['answer_timestamp'] as double).round());
      profile[correctSpeciesId] = profile.containsKey(correctSpeciesId) ?
        profile[correctSpeciesId].update(correct: correct, answerTimestamp: answerTimestamp) :
        SpeciesKnowledge.initial(answerTimestamp);
    }

    for (final entry in profiles.entries) {
      final profileId = entry.key;
      final profile = entry.value;
      for (final entry in profile.entries) {
        final speciesId = entry.key;
        final knowledge = entry.value;
        await txn.insert(
            'knowledge',
            <String, dynamic>{
              'profile_id': profileId,
              'species_id': speciesId,
              ...knowledge.toMap(),
            });
      }
    }

    await txn.execute('''
      create index knowledge_profile_id on knowledge(profile_id)
    ''');
    await txn.execute('''
      create index knowledge_profile_id_species_id on knowledge(profile_id, species_id)
    ''');

    final courses = await txn.query('courses', columns: <String>['course_id', 'lessons', 'unlocked_lesson_count']);
    for (final course in courses) {
      final courseId = course['course_id'] as int;
      final lessons = jsonDecode(course['lessons'] as String) as List<dynamic>;
      final unlockedLessonCount = course['unlocked_lesson_count'] as int;
      final unlockedSpecies = <int>[];
      final lockedSpecies = <int>[];
      for (var i = 0; i < lessons.length; i++) {
        final targetList = i < unlockedLessonCount ? unlockedSpecies : lockedSpecies;
        final lesson = lessons[i] as Map<String, dynamic>;
        final speciesIds = lesson['s'] as List<dynamic>;
        for (final speciesId in speciesIds) {
          targetList.add(speciesId as int);
        }
      }
      await txn.update(
        'courses',
        <String, dynamic>{
          'lessons': jsonEncode(<String, dynamic>{
            'unlocked_species': unlockedSpecies,
            'locked_species': lockedSpecies,
          }),
        },
        where: 'course_id = ?',
        whereArgs: <dynamic>[courseId],
      );
    }
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