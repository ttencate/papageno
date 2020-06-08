import 'dart:io';

import 'package:flutter/services.dart';
import 'package:papageno/model/app_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class NotFoundException implements Exception {
  final dynamic what;
  NotFoundException(this.what);
  @override
  String toString() => '${super.toString()} (${what.toString()})';
}

class AppDb {

  final Database _db;

  AppDb._fromDatabase(this._db);

  static Future<AppDb> open() async {
    // https://github.com/tekartik/sqflite/blob/master/sqflite/doc/opening_asset_db.md
    final databasesPath = await getDatabasesPath();
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}

    // We'd like to stream this, rather than loading it all into RAM at once.
    // But there seems no way to stream data from an AssetBundle.
    final path = join(databasesPath, 'app.db');
    final data = await rootBundle.load(join('assets', 'app.db'));
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);

    final db = await openReadOnlyDatabase(path);
    return AppDb._fromDatabase(db);
  }

  Future<List<int>> allSpeciesIds() async {
    final records = await _db.rawQuery('select species_id from species order by species_id');
    return records.map((r) => r['species_id'] as int).toList();
  }

  Future<Species> species(int speciesId) async {
    final species = speciesOrNull(speciesId);
    if (species == null) {
      throw NotFoundException(speciesId);
    }
    return species;
  }

  Future<Species> speciesOrNull(int speciesId) async {
    final records = await _db.rawQuery('select * from species where species_id = ?', <dynamic>[speciesId]);
    if (records.isEmpty) {
      return null;
    }
    return Species.fromMap(records.single);
  }

  Future<List<Recording>> allRecordings() async {
    final records = await _db.rawQuery('select * from recordings order by recording_id');
    return records.map((r) => Recording.fromMap(r)).toList();
  }

  Future<List<Recording>> recordingsFor(Species species) async {
    final records = await _db.rawQuery('select * from recordings where species_id = ? order by recording_id', <dynamic>[species.speciesId]);
    return records.map((r) => Recording.fromMap(r)).toList();
  }

  Future<List<Image>> allImages() async {
    final records = await _db.rawQuery('select * from images order by species_id');
    return records.map((r) => Image.fromMap(r)).toList();
  }

  Future<Image> imageForOrNull(Species species) async {
    final records = await _db.rawQuery('select * from images where species_id = ?', <dynamic>[species.speciesId]);
    if (records.isEmpty) {
      return null;
    }
    return Image.fromMap(records.single);
  }

  Future<List<Region>> regionsByDistanceTo(LatLon pos) async {
    // SQLite does not have trigonometry functions, so we can't compute the
    // great-circle distance in the database directly.
    final records = await _db.rawQuery('select * from regions order by region_id');
    final regions = records.map((record) => Region.fromMap(record)).toList()
        ..sort((a, b) => a.centroid.distanceInKmTo(pos).compareTo(b.centroid.distanceInKmTo(pos)));
    return regions;
  }

  Future<Region> region(int regionId) async {
    final records = await _db.rawQuery('select * from regions where region_id = ?', <dynamic>[regionId]);
    if (records.isEmpty) {
      throw NotFoundException(regionId);
    }
    return Region.fromMap(records.single);
  }
}