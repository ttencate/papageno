import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mock_app_db.dart';

Question _makeQuestion(Recording recording, Species correctAnswer, Species givenAnswer, DateTime answerTimestamp) {
  return Question(recording, <Species>[species1, species2, species3], correctAnswer)
    ..answerWith(givenAnswer, answerTimestamp);
}

DateTime _time({int days, int minutes}) {
  return _startTime.add(Duration(days: days ?? 0, minutes: minutes ?? 0));
}

final DateTime _startTime = DateTime.parse('2020-05-08 12:00:00'); // Happy birthday, David Attenborough!

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}'); // ignore: avoid_print
  });

  // Using `sqflite_ffi` to run unit tests on the host system (desktop OS),
  // because `sqflite` out of the box only supports mobile. For more info:
  // https://github.com/tekartik/sqflite/blob/master/sqflite/doc/testing.md
  sqfliteFfiInit();

  test('upgradeToVersion6', () async {
    final appDb = MockAppDb();

    final userDb = await UserDb.open(appDb: appDb, factory: databaseFactoryFfi, path: inMemoryDatabasePath, upgradeToVersion: 5);

    final profileId1 = (await userDb.createProfile(null)).profileId;
    final courseId1 = 1;
    // Species 1: always right.
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species1, species1, _time(days: 1)));
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species1, species1, _time(days: 2)));
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species1, species1, _time(days: 3)));
    // Species 2: wrong, wrong, right.
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species2, species1, _time(days: 1)));
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species2, species1, _time(days: 2)));
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species2, species2, _time(days: 3)));
    // Species 3: asked only once (right).
    await userDb.insertQuestion(profileId1, courseId1, _makeQuestion(recording1, species3, species3, _time(days: 3)));

    final profileId2 = (await userDb.createProfile(null)).profileId;
    final courseId2 = 2;
    // Species 1: asked only once, on day 1.
    await userDb.insertQuestion(profileId2, courseId2, _makeQuestion(recording1, species1, species1, _time(days: 1)));

    final now = _time(days: 4);
    await userDb.upgradeForTest(6);

    final knowledge1 = await userDb.knowledge(profileId1);
    expect(knowledge1.ofSpecies(species1).recallProbability(now), greaterThan(knowledge1.ofSpecies(species2).recallProbability(now)));
    expect(knowledge1.ofSpecies(species1).recallProbability(now), greaterThan(knowledge1.ofSpecies(species3).recallProbability(now)));
    expect(knowledge1.ofSpecies(species2).recallProbability(now), greaterThan(knowledge1.ofSpecies(species3).recallProbability(now)));

    final knowledge2 = await userDb.knowledge(profileId2);
    expect(knowledge2.ofSpecies(species1).recallProbability(now), lessThan(knowledge1.ofSpecies(species3).recallProbability(now)));
    expect(knowledge2.ofSpecies(species2), null);
    expect(knowledge2.ofSpecies(species3), null);
  });
}