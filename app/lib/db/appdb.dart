import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../model/model.dart';

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
    return Species.fromMap(records[0]);
  }

  Future<List<Recording>> recordingsFor(Species species) async {
    final records = await _db.rawQuery('select * from recordings where species_id = ?', <dynamic>[species.speciesId]);
    return records.map((r) => Recording.fromMap(r)).toList();
  }

  Future<Image> imageForOrNull(Species species) async {
    final records = await _db.rawQuery('select * from images where species_id = ?', <dynamic>[species.speciesId]);
    if (records.isEmpty) {
      return null;
    }
    return Image.fromMap(records[0]);
  }

  Future<Region> closestRegionTo(LatLon pos) async {
    // SQLite does not have trigonometry functions, so we can't compute the
    // great-circle distance in the database directly. But we can avoid parsing
    // the big JSON initially.
    final records = await _db.rawQuery('select region_id, centroid_lat, centroid_lon from regions');
    var closestRegionId = -1;
    var closestDistance = double.infinity;
    for (final record in records) {
      final centroid = LatLon(record['centroid_lat'] as double, record['centroid_lon'] as double);
      var distance = centroid.distanceTo(pos);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestRegionId = record['region_id'] as int;
      }
    }
    return region(closestRegionId);
  }

  Future<Region> region(int regionId) async {
    final records = await _db.rawQuery('select * from regions where region_id = ?', <dynamic>[regionId]);
    if (records.isEmpty) {
      throw NotFoundException(regionId);
    }
    return Region.fromMap(records[0]);
  }
}