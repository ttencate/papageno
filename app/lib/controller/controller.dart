import 'package:built_collection/built_collection.dart';

import '../db/appdb.dart';
import '../model/model.dart';

// TODO if we use it, cite GBIF somewhere:
// Downloaded from https://www.gbif.org/occurrence/download?dataset_key=4fa7b334-ce0d-4e88-aaae-2e0c138d049e
//
// SIMPLE
// Citation: GBIF.org (20 April 2020) GBIF Occurrence Download https://doi.org/10.15468/dl.s5q9xn
// License: Unspecified
//
// SPECIES LIST
// Citation: GBIF.org (20 April 2020) GBIF Occurrence Download https://doi.org/10.15468/dl.g8nprw
// License: Unspecified
//
// https://www.gbif.org/terms/data-user
// https://www.gbif.org/citation-guidelines

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