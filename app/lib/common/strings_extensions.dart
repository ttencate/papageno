import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';

/// A couple of helper methods on the generated [Strings] class that make it work with custom data types.
extension StringsExtensions on Strings {
  String profileName(Profile profile) => profile.name ?? anonymousProfileName(profile.profileId);

  String profileLastUsedDate(Profile profile) =>
      profile.lastUsed == null ? profileNeverUsed : humanizedDateTime(profile.lastUsed);

  String courseNameOrLocation(Course course) {
    return course.name ?? courseName(latLon(course.location));
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

  String latLon(LatLon latLon) => latLon.toString(fractionDigits: 3);

  // This should be made more human, e.g. "4 hours ago", "yesterday", "2 weeks ago"
  String humanizedDateTime(DateTime dateTime) => DateFormat.MMMMEEEEd(_locale.toLanguageTag()).add_Hm().format(dateTime);

  static Locale get _locale => WidgetsBinding.instance.window.locale;
}