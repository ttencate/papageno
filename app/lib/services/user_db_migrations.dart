/// This file implements migrations on the user database.
///
/// These migrations upgrade the database structure and content from previous versions of the app to the current
/// version.
///
/// Note that several migration functions duplicate functionality that is also present in the model and controller
/// layers. This is done because changes to the model and controller always assume the latest database version, and this
/// assumption may not be valid during the migration process. It also helps to guarantee that the semantics of the
/// migrations remain frozen in time, even if the other code continues to evolve.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ebisu_dart/ebisu.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqlite_api.dart';

final _log = Logger('user_db_migrations');

typedef Migration = Future<void> Function(Transaction);

const List<Migration> migrations = [
  _upgradeFromVersion0,
  _upgradeFromVersion1,
  _upgradeFromVersion2,
  _upgradeFromVersion3,
  _upgradeFromVersion4,
  _upgradeFromVersion5,
  _upgradeFromVersion6,
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
Future<void> _upgradeFromVersion0(Transaction txn) async {
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
Future<void> _upgradeFromVersion1(Transaction txn) async {
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
Future<void> _upgradeFromVersion2(Transaction txn) async {
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
Future<void> _upgradeFromVersion3(Transaction txn) async {
// Since version 6, this column is no longer used.
  await txn.execute('''
      alter table courses add column unlocked_lesson_count integer
    ''');
}

/// Adds last_used timestamp to profiles table.
Future<void> _upgradeFromVersion4(Transaction txn) async {
  await txn.execute('''
      alter table profiles add column last_used_timestamp_ms integer
    ''');
}

/// Adds knowledge table and populates it.
///
/// This mirrors the update logic from [KnowledgeController].
Future<void> _upgradeFromVersion5(Transaction txn) async {
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
  final knowledges = <int, Map<int, Map<String, dynamic>>>{
    for (final profileId in existingProfileIds) profileId: <int, Map<String, dynamic>>{},
  };

  final questionRecords = await txn.query(
      'questions',
      columns: <String>['profile_id', 'correct_species_id', 'given_species_id', 'answer_timestamp'],
      orderBy: 'answer_timestamp');
  for (final record in questionRecords) {
    final profileId = record['profile_id'] as int;
    final knowledge = knowledges[profileId];
    if (knowledge == null) {
      continue;
    }

    final correctSpeciesId = record['correct_species_id'] as int;
    final givenSpeciesId = record['given_species_id'] as int;
    final answerTimestamp = DateTime.fromMillisecondsSinceEpoch((record['answer_timestamp'] as double).round());

    final speciesKnowledge = knowledge[correctSpeciesId];
    if (speciesKnowledge == null) {
      knowledge[correctSpeciesId] = <String, dynamic>{
        'profile_id': profileId,
        'species_id': correctSpeciesId,
        'ebisu_time': 10.0 / (60.0 * 24.0),
        'ebisu_alpha': 3.0,
        'ebisu_beta': 3.0,
        'last_asked_timestamp_ms': answerTimestamp.millisecondsSinceEpoch,
      };
    } else {
      final model = EbisuModel(
          time: speciesKnowledge['ebisu_time'] as double,
          alpha: speciesKnowledge['ebisu_alpha'] as double,
          beta: speciesKnowledge['ebisu_beta'] as double);
      final correct = givenSpeciesId == correctSpeciesId;
      final daysSinceAsked = max(0.0, (answerTimestamp.millisecondsSinceEpoch - (speciesKnowledge['last_asked_timestamp_ms'] as int)) / (1000.0 * 60.0 * 60.0 * 24.0));
      final newModel = model.updateRecall(correct ? 1 : 0, 1, daysSinceAsked);
      speciesKnowledge['ebisu_time'] = newModel.time;
      speciesKnowledge['ebisu_alpha'] = newModel.alpha;
      speciesKnowledge['ebisu_beta'] = newModel.beta;
    }
  }

  for (final knowledge in knowledges.values) {
    for (final speciesKnowledge in knowledge.values) {
      await txn.insert('knowledge', speciesKnowledge);
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

/// Adds the `confusion_species_ids` column to the `knowledge` table and populates it.
///
/// This duplicates some logic from [KnowledgeController] so that the latter can safely diverge without affecting
/// migration correctness.
Future<void> _upgradeFromVersion6(Transaction txn) async {
  await txn.execute('''
      alter table knowledge add column confusion_species_ids blob
    ''');

  final existingProfileIds = (await txn.query('profiles', columns: <String>['profile_id']))
      .map((Map<String, dynamic> r) => r['profile_id'] as int)
      .toSet();
  final knowledges = <int, Map<int, List<int>>>{
    for (final profileId in existingProfileIds) profileId: <int, List<int>>{},
  };

  final questionRecords = await txn.query(
      'questions',
      columns: <String>['profile_id', 'correct_species_id', 'given_species_id'],
      orderBy: 'answer_timestamp');
  for (final record in questionRecords) {
    final profileId = record['profile_id'] as int;
    final knowledge = knowledges[profileId];
    if (knowledge == null) {
      continue;
    }

    final correctSpeciesId = record['correct_species_id'] as int;
    final givenSpeciesId = record['given_species_id'] as int;
    final correct = givenSpeciesId == correctSpeciesId;
    if (correct) {
      // Correct answers are recorded as confusions to eventually push out the wrong ones.
      knowledge.update(correctSpeciesId, (confusionSpeciesIds) => confusionSpeciesIds..add(correctSpeciesId), ifAbsent: () => <int>[]);
    } else if (!correct && (knowledge.containsKey(correctSpeciesId) || knowledge.containsKey(givenSpeciesId))) {
      // Wrong answers are recorded as confusions on both sides if either species was previously encountered.
      knowledge.putIfAbsent(correctSpeciesId, () => <int>[]).add(givenSpeciesId);
      knowledge.putIfAbsent(givenSpeciesId, () => <int>[]).add(correctSpeciesId);
    }
  }

  const numConfusionsToKeep = 20;
  for (final entry in knowledges.entries) {
    final profileId = entry.key;
    final knowledge = entry.value;
    for (final entry in knowledge.entries) {
      final speciesId = entry.key;
      final confusionSpeciesIds = Uint8List.sublistView(Uint16List.fromList(
          entry.value.reversed.take(numConfusionsToKeep).toList()));
      final updatedRecordCount = await txn.update(
          'knowledge',
          <String, dynamic>{
            'confusion_species_ids': confusionSpeciesIds,
          },
          where: 'profile_id = ? and species_id = ?',
          whereArgs: <dynamic>[profileId, speciesId]);
      if (updatedRecordCount == 0) {
        await txn.insert(
            'knowledge',
            <String, dynamic>{
              'profile_id': profileId,
              'species_id': speciesId,
              'confusion_species_ids': confusionSpeciesIds,
            });
      }
    }
  }
}