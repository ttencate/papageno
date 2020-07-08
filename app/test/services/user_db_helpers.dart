import 'package:papageno/services/user_db.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../testdata.dart';

var _sqfliteInited = false;

void _initSqflite() {
  if (!_sqfliteInited) {
    // Using `sqflite_ffi` to run unit tests on the host system (desktop OS),
    // because `sqflite` out of the box only supports mobile. For more info:
    // https://github.com/tekartik/sqflite/blob/master/sqflite/doc/testing.md
    sqfliteFfiInit();
    _sqfliteInited = true;
  }
}

Future<UserDb> createUserDbForTest({int version}) async {
  _initSqflite();
  final appDb = MockAppDb();
  return await UserDb.open(
      appDb: appDb,
      factory: databaseFactoryFfi,
      singleInstance: false,
      path: inMemoryDatabasePath,
      upgradeToVersion: version);
}