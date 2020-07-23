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

  final _speciesCache = <int, Species>{};

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

  Future<void> populateCache() async {
    final records = await _db.rawQuery('select * from species');
    for (final record in records) {
      final species = Species.fromMap(record);
      _speciesCache[species.speciesId] = species;
    }
  }

  Future<Species> species(int speciesId) async {
    final species = speciesOrNull(speciesId);
    if (species == null) {
      throw NotFoundException(speciesId);
    }
    return species;
  }

  Future<Species> speciesOrNull(int speciesId) async {
    if (!_speciesCache.containsKey(speciesId)) {
      final records = await _db.rawQuery('select * from species where species_id = ?', <dynamic>[speciesId]);
      _speciesCache[speciesId] = records.isEmpty ? null : Species.fromMap(records.single);
    }
    return _speciesCache[speciesId];
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

  Future<String> nearestCityNameTo(LatLon pos) async {
    final records = await _db.rawQuery('select city_id, lat, lon from cities order by city_id');
    if (records.isEmpty) {
      throw NotFoundException(pos); // Should not happen.
    }
    final nearest = records.reduce((a, b) {
      final aLatLon = LatLon(a['lat'] as double, a['lon'] as double);
      final bLatLon = LatLon(b['lat'] as double, b['lon'] as double);
      if (aLatLon.distanceInKmTo(pos) < bLatLon.distanceInKmTo(pos)) {
        return a;
      } else {
        return b;
      }
    });
    final nameRecords = await _db.rawQuery('select name from cities where city_id = ?', <dynamic>[nearest['city_id']]);
    return nameRecords.single['name'] as String;
  }
}