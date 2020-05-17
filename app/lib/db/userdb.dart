import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class UserDb {
  static const _latestVersion = 1;

  final Database _db;

  UserDb._fromDatabase(this._db);

  static Future<UserDb> open() async {
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
    return UserDb._fromDatabase(db);
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
      default: return Future.value();
    }
  }

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
}