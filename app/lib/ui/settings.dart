import 'package:papageno/model/model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final SharedPreferences _prefs;

  Settings._internal(this._prefs);

  static Future<Settings> create() async {
    return Settings._internal(await SharedPreferences.getInstance());
  }

  static const primarySpeciesLanguageCodeKey = 'primarySpeciesLanguageCode';

  LanguageCode get primarySpeciesLanguageCode {
    try {
      return LanguageCode.fromString(_prefs.getString(primarySpeciesLanguageCodeKey));
    } catch (ex) {
      // TODO switch back to 'en' once we have a UI for changing it
      return LanguageCode('en');
    }
  }

  // TODO initialize with user's OS language setting at first start
  set primarySpeciesLanguageCode(LanguageCode languageCode) {
    _prefs.setString(primarySpeciesLanguageCodeKey, languageCode.toString());
  }
}