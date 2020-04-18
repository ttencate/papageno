import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'model.dart';

class NotFoundException implements Exception {
  final dynamic what;
  NotFoundException(this.what);
}

class AppDb {

  final Database _db;

  AppDb._fromDatabase(this._db);

  static Future<AppDb> open() async {
    // https://github.com/tekartik/sqflite/blob/master/sqflite/doc/opening_asset_db.md
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app.db');
    await deleteDatabase(path);
    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (_) {}
    // TODO stream rather than loading it all into RAM at once
    final data = await rootBundle.load(join('assets', 'app.db'));
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
    final db = await openDatabase(path, readOnly: true);
    return AppDb._fromDatabase(db);
  }

  Future<List<int>> allSpeciesIds() async {
    final records = await _db.rawQuery('select species_id from species');
    return records.map((r) => r['species_id'] as int).toList();
  }

  Future<Species> species(int speciesId) async {
    final records = await _db.rawQuery('select * from species where species_id = ?', <dynamic>[speciesId]);
    if (records.isEmpty) {
      throw NotFoundException(speciesId);
    }
    final r = records[0];
    return Species(
        r['species_id'] as int,
        r['scientific_name'] as String,
        BuiltMap<LanguageCode, String>.build((builder) {
          builder.addEntries(r.entries
              .where((e) => e.key.startsWith('common_name_'))
              .map((e) => MapEntry(languageCodeFromString(e.key.substring(12)), e.value as String)));
        }));
  }
}