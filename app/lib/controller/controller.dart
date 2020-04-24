import 'dart:math';

import 'package:built_collection/built_collection.dart';

import '../db/appdb.dart';
import '../model/model.dart';
import '../utils/random_utils.dart';

Future<Course> createCourse(AppDb appDb) async {
  final location = LatLon(52.830102, 6.4475933);

  // Get region whose centroid is closest to our location.
  //
  // We could do something along the lines of
  // https://en.wikipedia.org/wiki/Inverse_distance_weighting,
  // but it's not clear that it is always better than nearest neighbour (see
  // e.g. the "Example in 1 dimension" graph).
  //
  // We could also find the four regions at the corners and do a bilinear
  // interpolation, but it's not clear that the added complexity is worth it at
  // this point.
  final region = await appDb.closestRegionTo(location);

  final weights = region.weightBySpeciesId;
  final speciesIds = weights.keys.toList();
  speciesIds.sort((a, b) => weights[b].compareTo(weights[a]));

  final speciesOrder = <Species>[];
  for (final speciesId in speciesIds) {
    speciesOrder.add(await appDb.species(speciesId));
  }

  final lessons = <Lesson>[];
  final speciesInLesson = <Species>[];
  for (final species in speciesOrder) {
    speciesInLesson.add(species);
    if (speciesInLesson.length >= _numSpeciesInLesson(lessons.length)) {
      lessons.add(Lesson(lessons.length, BuiltList.of(speciesInLesson)));
      speciesInLesson.clear();
    }
  }

  return Course(location, BuiltList.of(lessons));
}

int _numSpeciesInLesson(int index) {
  return index == 0 ? 10 : 5;
}

Future<Quiz> createQuiz(AppDb appDb, Course course, Lesson lesson) async {
  assert(course.lessons[lesson.index] == lesson);

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

  final questions = <Question>[];
  for (var i = 0; i < questionCount; i++) {
    final answer = i < newSpeciesQuestionCount || oldSpecies.isEmpty ?
        newSpecies.randomElement(random) :
        oldSpecies.randomElement(random);
    final recording = (await appDb.recordingsFor(answer)).randomElement(random);
    final choices = <Species>[answer];
    while (choices.length < choiceCount) {
      final choice = allSpecies.randomElement(random);
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