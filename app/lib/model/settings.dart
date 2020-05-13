import 'package:flutter/foundation.dart';
import 'package:papageno/model/model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO settings should be stored in UserDb because they are profile-dependent
class Settings with ChangeNotifier {
  final SharedPreferences _prefs;

  Settings._internal(this._prefs);

  static Future<Settings> create() async {
    return Settings._internal(await SharedPreferences.getInstance());
  }

  static const primarySpeciesLanguageCodeKey = 'primarySpeciesLanguageCode';
  static const secondarySpeciesLanguageCodeKey = 'secondarySpeciesLanguageCode';
  static const showScientificNameKey = 'showScientificName';

  LanguageCode get primarySpeciesLanguageCode {
    try {
      return LanguageCode.fromString(_prefs.getString(primarySpeciesLanguageCodeKey));
    } catch (ex) {
      // TODO switch back to 'en' once we have a UI for changing it
      return LanguageCode('nl');
    }
  }

  // TODO initialize with user's OS language setting at first start
  set primarySpeciesLanguageCode(LanguageCode languageCode) {
    _prefs.setString(primarySpeciesLanguageCodeKey, languageCode.toString());
    notifyListeners();
  }

  LanguageCode get secondarySpeciesLanguageCode {
    try {
      return LanguageCode.fromString(_prefs.getString(secondarySpeciesLanguageCodeKey));
    } catch (ex) {
      return null;
    }
  }

  set secondarySpeciesLanguageCode(LanguageCode languageCode) {
    _prefs.setString(secondarySpeciesLanguageCodeKey, languageCode.toString());
    notifyListeners();
  }

  bool get showScientificName {
    try {
      return _prefs.getBool(showScientificNameKey);
    } catch (ex) {
      return false;
    }
  }

  set showScientificName(bool value) {
    _prefs.setBool(showScientificNameKey, value);
    notifyListeners();
  }
}