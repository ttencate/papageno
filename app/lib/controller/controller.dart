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
  final regions = await appDb.allRegions();
  regions.sort((a, b) =>
      location.distanceTo(a.centroid).compareTo(
          location.distanceTo(b.centroid)));

  const numRegionsUsed = 9;
  final weights = <int, int>{};
  for (var i = 0; i < numRegionsUsed; i++) {
    final regionWeight = numRegionsUsed - i; // TODO gaussian based on distance
    for (final entry in regions[i].weightBySpeciesId.entries) {
      if (!weights.containsKey(entry.key)) {
        weights[entry.key] = 0;
      }
      weights[entry.key] += entry.value * regionWeight;
    }
  }

  final speciesIds = weights.keys.toList();
  speciesIds.sort((a, b) => weights[b].compareTo(weights[a]));

  final speciesOrder = <Species>[];
  for (final speciesId in speciesIds) {
    speciesOrder.add(await appDb.species(speciesId));
  }

  return Course(location, BuiltList.of(speciesOrder));
}