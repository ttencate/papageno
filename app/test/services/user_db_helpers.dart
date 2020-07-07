import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mock_app_db.dart';

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

Question makeQuestion(Recording recording, Species correctAnswer, Species givenAnswer, DateTime answerTimestamp) {
  return Question(recording: recording, choices: <Species>[species1, species2, species3], correctAnswer: correctAnswer)
      .answeredWith(givenAnswer, answerTimestamp);
}

DateTime time({int days, int minutes}) {
  return _startTime.add(Duration(days: days ?? 0, minutes: minutes ?? 0));
}

final DateTime _startTime = DateTime.parse('2020-05-08 12:00:00'); // Happy birthday, David Attenborough!