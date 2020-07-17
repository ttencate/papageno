import 'dart:async';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:location/location.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:pedantic/pedantic.dart';

@immutable
class CreateCourseState {
  final bool searchingLocation;
  final LatLon selectedLocation;
  final String cityName;
  final RankedSpecies rankedSpecies;
  final Course course;

  CreateCourseState({this.searchingLocation = false, this.selectedLocation, this.cityName, this.rankedSpecies, this.course});
}

@immutable
class ZoomRequest {
  final LatLon location;
  final double radiusKm;

  ZoomRequest(this.location, this.radiusKm);
}

class CreateCourseController {

  final _stateUpdatesController = StreamController<CreateCourseState>.broadcast();
  final _zoomRequestsController = StreamController<ZoomRequest>.broadcast();

  final AppDb appDb;
  final UserDb userDb;
  final Profile profile;
  String Function(String) courseNameFunc = (cityName) => cityName;

  bool _searchingLocation = false;
  LatLon _selectedLocation;
  String _cityName;
  RankedSpecies _rankedSpecies;
  Course _course;

  CreateCourseController(this.appDb, this.userDb, this.profile);

  void dispose() {
    _zoomRequestsController.close();
    _stateUpdatesController.close();
  }

  Stream<CreateCourseState> get stateUpdates => _stateUpdatesController.stream;
  Stream<ZoomRequest> get zoomRequests => _zoomRequestsController.stream;

  Future<void> useCurrentLocation() async {
    if (_searchingLocation) {
      return;
    }
    _searchingLocation = true;
    _notifyListeners();
    try {
      final location = Location();
      var serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return;
        }
      }
      await location.changeSettings(accuracy: LocationAccuracy.low);
      var permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return;
        }
      }
      final locationData = await location.getLocation();
      unawaited(selectLocation(LatLon(locationData.latitude, locationData.longitude)));
    } finally {
      _searchingLocation = false;
      _notifyListeners();
    }
  }

  Future<void> selectLocation(LatLon location) async {
    _selectedLocation = location;
    _cityName = null;
    _rankedSpecies = null;
    _course = null;
    _notifyListeners();

    _cityName = await appDb.nearestCityNameTo(location);
    _notifyListeners();
    _rankedSpecies = await _rankSpecies();
    _notifyListeners();

    _course = await _createCourse();
    _notifyListeners();
  }

  Future<RankedSpecies> _rankSpecies() async {
    assert(_selectedLocation != null);

    final regions = await appDb.regionsByDistanceTo(_selectedLocation);

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
      final distanceKm = region.centroid.distanceInKmTo(_selectedLocation);
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

    return RankedSpecies(_selectedLocation, species.toBuiltList(), usedRadiusKm);
  }

  Future<Course> _createCourse() async {
    assert(_selectedLocation != null);
    assert(_cityName != null);
    assert(_rankedSpecies != null);
    const initialUnlockedSpeciesCount = 10;
    return Course(
      profileId: profile.profileId,
      location: _selectedLocation,
      name: courseNameFunc(_cityName),
      localSpecies: _rankedSpecies.speciesList.toList(),
      unlockedSpecies: _rankedSpecies.speciesList.sublist(0, initialUnlockedSpeciesCount).toList(),
    );
  }

  Future<Course> saveCourse() async {
    if (_course == null) {
      return null;
    }
    await userDb.insertCourse(_course);
    return _course;
  }

  void _notifyListeners() {
    _stateUpdatesController.add(CreateCourseState(
      searchingLocation: _searchingLocation,
      selectedLocation: _selectedLocation,
      cityName: _cityName,
      rankedSpecies: _rankedSpecies,
      course: _course,
    ));
  }
}