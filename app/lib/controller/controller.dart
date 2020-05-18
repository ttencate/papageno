import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:papageno/db/appdb.dart';
import 'package:papageno/model/model.dart';
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

  final speciesIds = weights.keys.toList();
  speciesIds.sort((a, b) => -weights[a].compareTo(weights[b]));
  final species = <Species>[];
  for (final speciesId in speciesIds) {
    species.add(await appDb.species(speciesId));
  }

  return RankedSpecies(location, species.toBuiltList(), usedRadiusKm);
}

Future<Course> createCourse(LatLon location, RankedSpecies rankedSpecies) async {
  final lessons = <Lesson>[];
  final speciesInLesson = <Species>[];
  for (final species in rankedSpecies.speciesList) {
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

  final newSpeciesBag = RandomBag(newSpecies);
  final oldSpeciesBag = RandomBag(oldSpecies);
  final allSpeciesBag = RandomBag(allSpecies);
  final recordingsBags = <Species, RandomBag<Recording>>{};

  final questions = <Question>[];
  for (var i = 0; i < questionCount; i++) {
    final answer = i < newSpeciesQuestionCount || oldSpecies.isEmpty ?
        newSpeciesBag.next(random) :
        oldSpeciesBag.next(random);
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

  return Quiz(questions.toBuiltList());
}