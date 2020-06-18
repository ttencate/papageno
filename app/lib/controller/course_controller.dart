import 'dart:async';

import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';

class CourseController {
  final Course course;
  final UserDb _userDb;

  final _courseUpdatesController = StreamController<Course>();

  CourseController({@required this.course, @required UserDb userDb}) :
      _userDb = userDb;

  void dispose() {
    _courseUpdatesController.close();
  }

  Stream<Course> get courseUpdates => _courseUpdatesController.stream;

  Future<void> addSpecies(List<Species> newSpecies) async {
    final newSpeciesSet = newSpecies.toSet()
        ..removeAll(course.unlockedSpecies);
    course.unlockedSpecies.addAll(newSpecies.where(newSpeciesSet.remove));
    await _userDb.updateCourse(course);
    _notifyListeners();
  }

  void _notifyListeners() {
    _courseUpdatesController.add(course);
  }
}