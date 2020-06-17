import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';

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