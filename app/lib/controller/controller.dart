import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/iterable_utils.dart';
import 'package:papageno/utils/random_utils.dart';

Future<RankedSpecies> rankSpecies(AppDb appDb, LatLon location) async {
  final regions = await appDb.regionsByDistanceTo(location);

  // To deal with sparsely sampled regions (e.g. the Russian steppes), take the
  // sum of several nearby regions until we have some minimum number of species.
  // Then we weigh them according to a Gaussian function.
  const minSpeciesCount = 50;
  const minRegions = 3;
  const sigmaKm = 10000.0 / 90.0; // Maximum edge length of one grid cell.
  final weights = <int, double>{};
  var usedRadiusKm = 0.0;
  for (var i = 0; i < regions.length; i++) {
    if (i >= minRegions && weights.length >= minSpeciesCount) {
      break;
    }
    final region = regions[i];
    final distanceKm = region.centroid.distanceInKmTo(location);
    usedRadiusKm = max(usedRadiusKm, distanceKm);
    final x = distanceKm / sigmaKm;
    final weightFactor = exp(-0.5 * (x * x));
    for (final entry in region.weightBySpeciesId.entries) {
      weights.putIfAbsent(entry.key, () => 0);
      weights[entry.key] += weightFactor * entry.value;
    }
  }

  final speciesIds = weights.keys.toList()
      ..sort((a, b) => -weights[a].compareTo(weights[b]));
  final species = <Species>[];
  for (final speciesId in speciesIds) {
    species.add(await appDb.species(speciesId));
  }

  return RankedSpecies(location, species.toBuiltList(), usedRadiusKm);
}

Future<Course> createCourse(int profileId, LatLon location, RankedSpecies rankedSpecies) async {
  const initialUnlockedSpeciesCount = 10;
  return Course(
    profileId: profileId,
    location: location,
    unlockedSpecies: rankedSpecies.speciesList.sublist(0, initialUnlockedSpeciesCount).toList(),
    lockedSpecies: rankedSpecies.speciesList.sublist(initialUnlockedSpeciesCount).toList(),
  );
}

Future<Quiz> createQuiz(AppDb appDb, UserDb userDb, Course course, [DateTime now]) async {
  now ??= DateTime.now();

  const questionCount = 20;
  const newSpeciesQuestionCount = 10;
  assert(newSpeciesQuestionCount <= questionCount);
  const choiceCount = 4;

  final random = Random();

  final allSpecies = course.unlockedSpecies.toList();

  final knowledge = await userDb.knowledge(course.profileId);

  // Ask higher priority first.
  int byPriority(Species a, Species b) {
    final ka = knowledge.ofSpecies(a);
    final kb = knowledge.ofSpecies(b);
    if (ka == null && kb == null) {
      return 0;
    } else if (ka == null) {
      return -1;
    } else if (kb == null) {
      return 1;
    } else {
      return -ka.priority(now).compareTo(kb.priority(now));
    }
  }

  final questionsBag = CyclicBag(allSpecies.sorted(byPriority));
  final answersBag = RandomBag(allSpecies);
  final recordingsBags = <Species, RandomBag<Recording>>{};

  final questions = <Question>[];
  for (var i = 0; i < questionCount; i++) {
    final answer = questionsBag.next();
    if (!recordingsBags.containsKey(answer)) {
      recordingsBags[answer] = RandomBag(await appDb.recordingsFor(answer));
    }
    final recording = recordingsBags[answer].next(random);
    final choices = <Species>[answer];
    while (choices.length < min(choiceCount, allSpecies.length)) {
      final choice = answersBag.next(random);
      if (!choices.contains(choice)) {
        choices.add(choice);
      }
    }
    choices.shuffle(random);
    questions.add(Question(
        recording,
        choices,
        answer,
    ));
  }
  questions.shuffle(random);

  return Quiz(questions.toBuiltList());
}

Future<void> storeAnswer(UserDb userDb, Profile profile, Course course, Question question) async {
  await userDb.insertQuestion(profile.profileId, course.courseId, question);
  final speciesKnowledge = await userDb.speciesKnowledgeOrNull(profile.profileId, question.correctAnswer.speciesId);
  final newSpeciesKnowledge =
      speciesKnowledge?.update(correct: question.isCorrect, answerTimestamp: question.answerTimestamp) ??
      SpeciesKnowledge.initial(question.answerTimestamp);
  await userDb.upsertSpeciesKnowledge(profile.profileId, question.correctAnswer.speciesId, newSpeciesKnowledge);
}