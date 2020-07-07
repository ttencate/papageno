import 'package:built_collection/built_collection.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/services/app_db.dart';

final Species species1 = _makeSpecies(1, 'Species 1');
final Species species2 = _makeSpecies(2, 'Species 2');
final Species species3 = _makeSpecies(3, 'Species 3');

final Recording recording1 = _makeRecording('xc:1', species1);
final Recording recording2 = _makeRecording('xc:2', species2);
final Recording recording3 = _makeRecording('xc:3', species3);

class MockAppDb implements AppDb {

  static final _images = <Image>{}.toBuiltList();
  static final _species = <Species>{species1, species2, species3}.toBuiltList();
  static final _recordings = <Recording>{recording1, recording2, recording3}.toBuiltList();
  static final _regions = <Region>{}.toBuiltList();

  @override
  Future<List<int>> allSpeciesIds() async => _species
      .map((s) => s.speciesId).toList(growable: false);

  @override
  Future<Species> species(int speciesId) async => _species
      .firstWhere((s) => s.speciesId == speciesId, orElse: () => throw NotFoundException(speciesId));

  @override
  Future<Species> speciesOrNull(int speciesId) async => _species
      .firstWhere((s) => s.speciesId == speciesId, orElse: () => null);

  @override
  Future<List<Recording>> allRecordings() async => _recordings.toList(growable: false);

  @override
  Future<List<Recording>> recordingsFor(Species species) async => _recordings
      .where((r) => r.speciesId == species.speciesId).toList(growable: false);

  @override
  Future<List<Image>> allImages() async => _images.toList(growable: false);

  @override
  Future<Image> imageForOrNull(Species species) async => _images
      .firstWhere((i) => i.speciesId == species.speciesId, orElse: () => null);

  @override
  Future<List<Region>> regionsByDistanceTo(LatLon pos) async {
    throw UnimplementedError();
  }

  @override
  Future<Region> region(int regionId) async => _regions
      .firstWhere((r) => r.regionId == regionId, orElse: () => null);
}

Species _makeSpecies(int speciesId, String scientificName) {
  return Species(speciesId, scientificName, BuiltMap.of(<LanguageCode, String>{}));
}

Recording _makeRecording(String recordingId, Species species) {
  return Recording(recordingId: recordingId, speciesId: species.speciesId, fileName: '$recordingId.ogg');
}