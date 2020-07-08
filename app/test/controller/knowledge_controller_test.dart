import 'package:flutter_test/flutter_test.dart';
import 'package:papageno/controller/knowledge_controller.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:pedantic/pedantic.dart';

import '../services/mock_app_db.dart';
import '../services/user_db_helpers.dart';

void main() {
  const initialHalflife = 10.0 / (60.0 * 24.0);
  final isInitialHalflife = closeTo(initialHalflife, 1e-4 * initialHalflife);
  final isExtendedHalflife = greaterThan(1.01 * initialHalflife);
  final isReducedHalflife = lessThan(0.99 * initialHalflife);

  UserDb userDb;
  Profile profile;
  KnowledgeController knowledgeController;
  
  setUp(() async {
    userDb = await createUserDbForTest();
    profile = await userDb.createProfile(null);
    knowledgeController = KnowledgeController(profile: profile, userDb: userDb);
  });

  Future<Knowledge> knowledgeFromDb() async {
    return await userDb.knowledge(profile.profileId);
  }
  
  group('updateSpeciesKnowledge', () {
    test('emits updates', () async {
      unawaited(knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species1, time(minutes: 0))));
      expect(knowledgeController.knowledgeUpdates, emits(anything));
      expect(await knowledgeController.updatedKnowledge, isNotNull);
      knowledgeController.dispose();
    });

    test('has no knowledge initially', () async {
      final knowledge = await knowledgeController.updatedKnowledge;
      expect(knowledge.ofSpeciesOrNull(species1), null);

      expect(knowledge, await knowledgeFromDb());
    });

    group('with correct answer', () {
      test('when the species is unknown', () async {
        final knowledge = await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species1, time(minutes: 0)));

        // Halflife is initialized to the initial value.
        final speciesKnowledge = knowledge.ofSpeciesOrNull(species1);
        expect(speciesKnowledge.isNone, false);
        expect(speciesKnowledge.lastAskedTimestamp, time(minutes: 0));
        expect(speciesKnowledge.model.modelToPercentileDecay(), isInitialHalflife);
        expect(speciesKnowledge.confusionSpeciesIds, isEmpty);

        expect(knowledge, await knowledgeFromDb());
      });
      test('when the species is known', () async {
        await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species1, time(minutes: 0)));
        final knowledge = await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species1, time(minutes: 10)));

        // Halflife is extended.
        final speciesKnowledge = knowledge.ofSpeciesOrNull(species1);
        expect(speciesKnowledge.isNone, false);
        expect(speciesKnowledge.lastAskedTimestamp, time(minutes: 10));
        expect(speciesKnowledge.model.modelToPercentileDecay(), isExtendedHalflife);
        expect(speciesKnowledge.confusionSpeciesIds, isEmpty);

        expect(knowledge, await knowledgeFromDb());
      });
    });

    group('with wrong answer', () {
      test('when neither species is known', () async {
        // Ask species 1 while the user guessed species 2.
        final knowledge = await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species2, time(minutes: 0)));

        // Species 1 should have its model initialized, but the confusion should not be recorded because the user
        // couldn't know this species yet.
        final species1Knowledge = knowledge.ofSpeciesOrNull(species1);
        expect(species1Knowledge.isNone, false);
        expect(species1Knowledge.lastAskedTimestamp, time(minutes: 0));
        expect(species1Knowledge.model.modelToPercentileDecay(), isInitialHalflife);
        expect(species1Knowledge.confusionSpeciesIds, isEmpty);
        // Species 2 has never been presented so it does not get its model initialized, nor confusions recorded.
        final species2Knowledge = knowledge.ofSpeciesOrNull(species2);
        expect(species2Knowledge, null);

        expect(knowledge, await knowledgeFromDb());
      });

      test('when only the correct species is known', () async {
        // Ask species 1 and get it right the first time, then wrong the second time.
        await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species1, time(minutes: 0)));
        final knowledge = await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species2, time(minutes: 1)));

        // Species 1 should have a reduced halflife, and the confusion should be recorded because the user has heard it
        // before.
        final species1Knowledge = knowledge.ofSpeciesOrNull(species1);
        expect(species1Knowledge.isNone, false);
        expect(species1Knowledge.lastAskedTimestamp, time(minutes: 1));
        expect(species1Knowledge.model.modelToPercentileDecay(), isReducedHalflife);
        expect(species1Knowledge.confusionSpeciesIds, <int>[species2.speciesId]);
        // Species 2 has never been presented so it does not get its model initialized, but the confusion is recorded
        // because the user could have known that it was species 1.
        final species2Knowledge = knowledge.ofSpeciesOrNull(species2);
        expect(species2Knowledge.isNone, true);
        expect(species2Knowledge.lastAskedTimestamp, null);
        expect(species2Knowledge.model, isNull);
        expect(species2Knowledge.confusionSpeciesIds, <int>[species1.speciesId]);

        expect(knowledge, await knowledgeFromDb());
      });

      test('when only the answered species is known', () async {
        // Ask species 1 for the first time, but the user guessed that it was species 2 which they heard before.
        await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording2, species2, species2, time(minutes: 0)));
        final knowledge = await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species2, time(minutes: 1)));

        // Species 1 gets the initial model because it was just presented for the first time, and the confusion is
        // recorded because they could have known that it wasn't species 2.
        final species1Knowledge = knowledge.ofSpeciesOrNull(species1);
        expect(species1Knowledge.isNone, false);
        expect(species1Knowledge.lastAskedTimestamp, time(minutes: 1));
        expect(species1Knowledge.model.modelToPercentileDecay(), isInitialHalflife);
        expect(species1Knowledge.confusionSpeciesIds, <int>[species2.speciesId]);
        // Species 2 also gets the confusion recorded, and a halflife reduction, but no timestamp update.
        final species2Knowledge = knowledge.ofSpeciesOrNull(species2);
        expect(species2Knowledge.isNone, false);
        expect(species2Knowledge.lastAskedTimestamp, time(minutes: 0));
        expect(species2Knowledge.model.modelToPercentileDecay(), isReducedHalflife);
        expect(species2Knowledge.confusionSpeciesIds, <int>[species1.speciesId]);

        expect(knowledge, await knowledgeFromDb());
      });

      test('when both species are known', () async {
        // Ask species 1 and get it wrong as species 2, while both were known before.
        await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species1, time(minutes: 0)));
        await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording2, species2, species2, time(minutes: 1)));
        final knowledge = await knowledgeController.updateSpeciesKnowledge(makeQuestion(recording1, species1, species2, time(minutes: 2)));

        // Species 1 should have its halflife reduced and the confusion recorded.
        final species1Knowledge = knowledge.ofSpeciesOrNull(species1);
        expect(species1Knowledge.isNone, false);
        expect(species1Knowledge.lastAskedTimestamp, time(minutes: 2));
        expect(species1Knowledge.model.modelToPercentileDecay(), isReducedHalflife);
        expect(species1Knowledge.confusionSpeciesIds, <int>[species2.speciesId]);
        // Species also gets the confusion recorded, and a halflife reduction, but no timestamp update.
        final species2Knowledge = knowledge.ofSpeciesOrNull(species2);
        expect(species2Knowledge.isNone, false);
        expect(species2Knowledge.lastAskedTimestamp, time(minutes: 1));
        expect(species2Knowledge.model.modelToPercentileDecay(), isReducedHalflife);
        expect(species2Knowledge.confusionSpeciesIds, <int>[species1.speciesId]);

        expect(knowledge, await knowledgeFromDb());
      });
    });
  });
}