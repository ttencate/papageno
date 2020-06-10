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
  final lessons = <Lesson>[];
  final speciesInLesson = <Species>[];
  for (final species in rankedSpecies.speciesList) {
    speciesInLesson.add(species);
    if (speciesInLesson.length >= _numSpeciesInLesson(lessons.length)) {
      lessons.add(Lesson(index: lessons.length, species: BuiltList.of(speciesInLesson)));
      speciesInLesson.clear();
    }
  }
  // The last few species are omitted. This is on purpose; a lesson with just 1 new species would be silly.
  // Since we ensure that there are at least 50 species, this doesn't really matter.

  return Course(profileId: profileId, location: location, lessons: BuiltList.of(lessons));
}

int _numSpeciesInLesson(int index) {
  return index == 0 ? 10 : 5;
}

Future<Quiz> createQuiz(AppDb appDb, UserDb userDb, Course course, Lesson lesson, [DateTime now]) async {
  assert(course.lessons[lesson.index] == lesson);

  now ??= DateTime.now();

  const questionCount = 20;
  const newSpeciesQuestionCount = 10;
  assert(newSpeciesQuestionCount <= questionCount);
  const choiceCount = 4;

  final random = Random();

  final oldSpecies = <Species>[];
  for (final oldLesson in course.lessons.take(lesson.index)) {
    oldSpecies.addAll(oldLesson.species);
  }
  final newSpecies = lesson.species.asList();
  final allSpecies = oldSpecies + newSpecies;
  assert(allSpecies.length >= choiceCount);

  final knowledge = await userDb.knowledge(course.profileId);

  // Ask higher priority first.
  final byPriority = (Species a, Species b) {
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
  };
  final newSpeciesBag = CyclicBag(newSpecies.sorted(byPriority));
  final oldSpeciesBag = CyclicBag(oldSpecies.sorted(byPriority));

  final allSpeciesBag = RandomBag(allSpecies);
  final recordingsBags = <Species, RandomBag<Recording>>{};

  final questions = <Question>[];
  for (var i = 0; i < questionCount; i++) {
    final answer = i < newSpeciesQuestionCount || oldSpecies.isEmpty ?
        newSpeciesBag.next() :
        oldSpeciesBag.next();
    if (!recordingsBags.containsKey(answer)) {
      recordingsBags[answer] = RandomBag(await appDb.recordingsFor(answer));
    }
    final recording = recordingsBags[answer].next(random);
    final choices = <Species>[answer];
    while (choices.length < choiceCount) {
      final choice = allSpeciesBag.next(random);
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

  return Quiz(lesson, questions.toBuiltList());
}

Future<void> storeAnswer(UserDb userDb, Profile profile, Course course, Question question) async {
  await userDb.insertQuestion(profile.profileId, course.courseId, question);
  final speciesKnowledge = await userDb.speciesKnowledgeOrNull(profile.profileId, question.correctAnswer.speciesId);
  final newSpeciesKnowledge =
      speciesKnowledge?.update(correct: question.isCorrect, answerTimestamp: question.answerTimestamp) ??
      SpeciesKnowledge.initial(question.answerTimestamp);
  await userDb.upsertSpeciesKnowledge(profile.profileId, question.correctAnswer.speciesId, newSpeciesKnowledge);
}

const minScorePercentToUnlockNextLesson = 90;

Future<bool> maybeUnlockNextLesson(UserDb userDb, Course course, Quiz quiz) async {
  if (quiz.lesson.index == course.lastUnlockedLesson.index && quiz.scorePercent >= minScorePercentToUnlockNextLesson) {
    if (course.unlockNextLesson()) {
      await userDb.updateCourseUnlockedLessons(course);
      return true;
    }
  }
  return false;
}