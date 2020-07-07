import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:papageno/model/user_model.dart';
import 'package:sqflite/sqlite_api.dart';

final _log = Logger('user_db_migrations');

typedef Migration = Future<void> Function(Transaction);

const List<Migration> migrations = [
  _upgradeToVersion1,
  _upgradeToVersion2,
  _upgradeToVersion3,
  _upgradeToVersion4,
  _upgradeToVersion5,
  _upgradeToVersion6,
];

final latestVersion = migrations.length;

Future<void> upgradeToVersion(Database db, int newVersion) async {
  assert(newVersion >= 0);
  assert(newVersion <= latestVersion);
  final oldVersion = await db.getVersion();
  await db.transaction((txn) async {
    for (var fromVersion = oldVersion; fromVersion < newVersion; fromVersion++) {
      _log.info('Running migration from version $fromVersion to ${fromVersion + 1}');
      await migrations[fromVersion](txn);
    }
  });
}

/// Creates profiles and settings tables.
Future<void> _upgradeToVersion1(Transaction txn) async {
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
Future<void> _upgradeToVersion2(Transaction txn) async {
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
Future<void> _upgradeToVersion3(Transaction txn) async {
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
Future<void> _upgradeToVersion4(Transaction txn) async {
// Since version 6, this column is no longer used.
  await txn.execute('''
      alter table courses add column unlocked_lesson_count integer
    ''');
}

/// Adds last_used timestamp to profiles table.
Future<void> _upgradeToVersion5(Transaction txn) async {
  await txn.execute('''
      alter table profiles add column last_used_timestamp_ms integer
    ''');
}

/// Adds knowledge table and populates it.
/// This duplicates some code from the controller, because we don't want the database layer to depend on the
/// controller layer. And also, because we want to be able to change the controller but keep the migration frozen.
Future<void> _upgradeToVersion6(Transaction txn) async {
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
    profile[correctSpeciesId] = (profile[correctSpeciesId] ?? SpeciesKnowledge.none())
        .update(correct: correct, answerTimestamp: answerTimestamp);
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
    final localSpecies = <int>[];
    final unlockedSpecies = <int>[];
    for (var i = 0; i < lessons.length; i++) {
      final unlocked = i < unlockedLessonCount;
      final lesson = lessons[i] as Map<String, dynamic>;
      final speciesIds = lesson['s'] as List<dynamic>;
      for (final speciesId in speciesIds) {
        localSpecies.add(speciesId as int);
        if (unlocked) {
          unlockedSpecies.add(speciesId as int);
        }
      }
    }
    await txn.update(
      'courses',
      <String, dynamic>{
        'lessons': jsonEncode(<String, dynamic>{
          'unlocked_species': unlockedSpecies,
          'local_species': localSpecies,
        }),
      },
      where: 'course_id = ?',
      whereArgs: <dynamic>[courseId],
    );
  }
}