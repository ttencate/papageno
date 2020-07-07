import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/services/user_db_migrations.dart';

import 'mock_app_db.dart';
import 'user_db_helpers.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}'); // ignore: avoid_print
  });

  // Tests for database migrations. Note that we typically upgrade to the latest version, not just to the next version,
  // so that our current model classes can be used to test the result.
  group('UserDb migration', () {
    group('from version 5', () {
      UserDb userDb;
      int profileId1;
      int profileId2;
      final courseId1 = 1;
      final courseId2 = 2;

      setUp(() async {
        userDb = await createUserDbForTest(version: 5);
        profileId1 = (await userDb.createProfile(null)).profileId;
        profileId2 = (await userDb.createProfile(null)).profileId;
      });

      test('populates the knowledge table', () async {
        // Species 1: always right.
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species1, species1, time(days: 1)));
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species1, species1, time(days: 2)));
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species1, species1, time(days: 3)));
        // Species 2: wrong, wrong, right.
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species2, species1, time(days: 1)));
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species2, species1, time(days: 2)));
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species2, species2, time(days: 3)));
        // Species 3: asked only once (right).
        await userDb.insertQuestion(profileId1, courseId1, makeQuestion(recording1, species3, species3, time(days: 3)));

        // Species 1: asked only once, on day 1.
        await userDb.insertQuestion(profileId2, courseId2, makeQuestion(recording1, species1, species1, time(days: 1)));

        final now = time(days: 4);
        await upgradeToVersion(userDb.dbForTest, latestVersion);

        final knowledge1 = await userDb.knowledge(profileId1);
        expect(knowledge1.ofSpeciesOrNone(species1).recallProbability(now), greaterThan(knowledge1.ofSpeciesOrNone(species2).recallProbability(now)));
        expect(knowledge1.ofSpeciesOrNone(species1).recallProbability(now), greaterThan(knowledge1.ofSpeciesOrNone(species3).recallProbability(now)));
        expect(knowledge1.ofSpeciesOrNone(species2).recallProbability(now), greaterThan(knowledge1.ofSpeciesOrNone(species3).recallProbability(now)));

        final knowledge2 = await userDb.knowledge(profileId2);
        expect(knowledge2.ofSpeciesOrNone(species1).recallProbability(now), lessThan(knowledge1.ofSpeciesOrNone(species3).recallProbability(now)));
        expect(knowledge2.ofSpeciesOrNone(species2).recallProbability(now), 0.0);
        expect(knowledge2.ofSpeciesOrNone(species3).recallProbability(now), 0.0);
      });

      test('converts courses', () async {
        await userDb.dbForTest.insert('courses', <String, dynamic>{
          'course_id': 1,
          'profile_id': profileId1,
          'lessons': '[{"i":0,"s":[3]},{"i":1,"s":[1]},{"i":2,"s":[2]}]',
          'unlocked_lesson_count': 2,
        });

        await upgradeToVersion(userDb.dbForTest, latestVersion);

        final course = await userDb.getCourse(courseId1);
        expect(course.unlockedSpecies, [species3, species1]);
        expect(course.localSpecies, [species3, species1, species2]);
      });
    });

    group('from version 6', () {
      UserDb userDb;
      int profileId;
      final courseId = 1;

      setUp(() async {
        userDb = await createUserDbForTest(version: 6);
        profileId = (await userDb.createProfile(null)).profileId;
      });

      test('populates confusions', () async {
        // Species 1: always right.
        // Species 2: sometimes confused with species 3 or species 1.
        // Species 3: sometimes confused with species 2.
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species1, species1, time(days: 1, minutes: 0)));
        await userDb.dbForTest.insert('knowledge', <String, dynamic>{
          'profile_id': profileId,
          'species_id': species1.speciesId,
          'last_asked_timestamp_ms': time(days: 1, minutes: 0).millisecondsSinceEpoch,
        });
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species2, species3, time(days: 1, minutes: 1))); // Neither exists.
        await userDb.dbForTest.insert('knowledge', <String, dynamic>{
          'profile_id': profileId,
          'species_id': species2.speciesId,
          'last_asked_timestamp_ms': time(days: 1, minutes: 1).millisecondsSinceEpoch,
        });
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species1, species1, time(days: 2, minutes: 0)));
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species2, species2, time(days: 2, minutes: 1)));
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species1, species1, time(days: 3, minutes: 0)));
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species2, species3, time(days: 3, minutes: 1))); // Correct exists, given doesn't.
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species3, species2, time(days: 4, minutes: 0))); // Correct doesn't exist, given does.
        await userDb.dbForTest.insert('knowledge', <String, dynamic>{
          'profile_id': profileId,
          'species_id': species3.speciesId,
          'last_asked_timestamp_ms': time(days: 4, minutes: 0).millisecondsSinceEpoch,
        });
        await userDb.insertQuestion(profileId, courseId, makeQuestion(recording1, species2, species1, time(days: 4, minutes: 1))); // Both correct and given exist.

        await upgradeToVersion(userDb.dbForTest, latestVersion);

        final knowledge = await userDb.knowledge(profileId);
        expect(knowledge.ofSpeciesOrNull(species1).confusionSpeciesIds, <int>[species2.speciesId]);
        expect(knowledge.ofSpeciesOrNull(species2).confusionSpeciesIds, <int>[species1.speciesId, species3.speciesId, species3.speciesId]);
        expect(knowledge.ofSpeciesOrNull(species3).confusionSpeciesIds, <int>[]);
      });
    });
  });
}