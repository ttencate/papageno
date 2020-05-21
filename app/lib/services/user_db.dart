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
  static const _latestVersion = 2;

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

  Future<List<Profile>> getProfiles() async {
    final records = await _db.query(
        'profiles',
        orderBy: 'profile_id');
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
    await _db.insert('courses', _courseToMap(course));
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

  Map<String, dynamic> _courseToMap(Course course) => <String, dynamic>{
    'profile_id': course.profileId,
    'location_lat': course.location.lat,
    'location_lon': course.location.lon,
    'lessons': json.encode(
      course.lessons.map((lesson) => <String, dynamic>{
        'i': lesson.index,
        's': lesson.species.map((species) => species.speciesId).toList(),
      }).toList()
    ),
  };

  Future<Course> _courseFromMap(Map<String, dynamic> map) async {
    final lessons = <Lesson>[];
    for (final lesson in json.decode(map['lessons'] as String) as List<dynamic>) {
      final species = <Species>[];
      for (final speciesId in lesson['s'] as List<dynamic>) {
        species.add(await _appDb.species(speciesId as int));
      }
      lessons.add(Lesson(
        index: lesson['i'] as int,
        species: species.toBuiltList(),
      ));
    }
    return Course(
      profileId: map['profile_id'] as int,
      location: LatLon(map['location_lat'] as double, map['location_lon'] as double),
      lessons: lessons.toBuiltList(),
    );
  }
}