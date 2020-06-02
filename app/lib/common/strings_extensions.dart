import 'package:papageno/common/strings.g.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/model/settings.dart';

/// A couple of helper methods on the generated [Strings] class that make it work with custom data types.
extension StringsExtensions on Strings {
  String courseName(Course course) {
    // When we have an actual name stored in the course, return that instead.
    // TODO Convert lat/lon to string in a locale-dependent way
    return courseTitle(course.location.toString());
  }

  String languageSettingName(LanguageSetting languageSetting) {
    if (languageSetting == LanguageSetting.system) {
      return languageSystem;
    }
    if (languageSetting == LanguageSetting.none) {
      return languageNone;
    }
    final dynamic languageName = this['language_${languageSetting.toString()}'];
    return languageName is String ? languageName : '?';
  }
}