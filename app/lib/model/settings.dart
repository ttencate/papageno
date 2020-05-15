import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:papageno/model/model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Algebraic data type containing one of:
/// - a [LanguageCode]
/// - the value "system"
/// - the value "none"
abstract class LanguageSetting {
  /// Returns the actual language code, falling back to English if the system
  /// language was requested but is not supported.
  /// Returns `null` if this setting represents "none".
  LanguageCode resolve(Locale locale);

  factory LanguageSetting.languageCode(LanguageCode languageCode) => LanguageCodeLanguageSetting._internal(languageCode);
  static const system = SystemLanguageSetting._internal();
  static const none = NoneLanguageSetting._internal();

  factory LanguageSetting.fromString(String string) {
    switch (string) {
      case SystemLanguageSetting._stringValue: return system;
      case NoneLanguageSetting._stringValue: return none;
      default: return LanguageCodeLanguageSetting._internal(LanguageCode.fromString(string));
    }
  }
}

class LanguageCodeLanguageSetting implements LanguageSetting {
  final LanguageCode languageCode;

  LanguageCodeLanguageSetting._internal(this.languageCode);

  @override
  LanguageCode resolve(Locale locale) => languageCode;

  @override
  bool operator ==(Object other) => other is LanguageCodeLanguageSetting && languageCode == other.languageCode;

  @override
  int get hashCode => languageCode.hashCode;

  @override
  String toString() => languageCode.toString();
}

class SystemLanguageSetting implements LanguageSetting {
  static const _stringValue = 'system';

  const SystemLanguageSetting._internal();

  /// Resolves the system locale into a supported language code.
  /// First tries to match exact language code and country code, like `en_US`.
  /// Then tries to match only language code, like `en`.
  /// Finally falls back to `en`.
  @override
  LanguageCode resolve(Locale locale) {
    final language = locale.languageCode;
    final country = locale.countryCode;
    return
        LanguageCode.allSupported.firstWhere(
            (lc) => lc.languageCode == language && lc.countryCode == country, orElse: () => null) ??
        LanguageCode.allSupported.firstWhere(
            (lc) => lc.languageCode == language, orElse: () => null) ??
        LanguageCode.fallback;
  }

  @override
  bool operator ==(Object other) => other is SystemLanguageSetting;

  @override
  int get hashCode => _stringValue.hashCode;

  @override
  String toString() => _stringValue;
}

class NoneLanguageSetting implements LanguageSetting {
  static const _stringValue = 'none';

  const NoneLanguageSetting._internal();

  @override
  LanguageCode resolve(Locale appLocale) {
    return null;
  }

  @override
  bool operator ==(Object other) => other is NoneLanguageSetting;

  @override
  int get hashCode => _stringValue.hashCode;

  @override
  String toString() => _stringValue;
}

// TODO settings should be stored in UserDb because they are profile-dependent
class Settings with ChangeNotifier {
  final SharedPreferences _prefs;

  Settings._internal(this._prefs);

  static Future<Settings> create() async {
    return Settings._internal(await SharedPreferences.getInstance());
  }

  static const primarySpeciesLanguageKey = 'primarySpeciesLanguage';
  static const secondarySpeciesLanguageKey = 'secondarySpeciesLanguage';
  static const showScientificNameKey = 'showScientificName';

  LanguageSetting get primarySpeciesLanguage {
    try {
      return LanguageSetting.fromString(_prefs.getString(primarySpeciesLanguageKey));
    } catch (ex) {
      return LanguageSetting.system;
    }
  }

  set primarySpeciesLanguage(LanguageSetting languageSetting) {
    _prefs.setString(primarySpeciesLanguageKey, languageSetting.toString());
    notifyListeners();
  }

  LanguageSetting get secondarySpeciesLanguage {
    try {
      return LanguageSetting.fromString(_prefs.getString(secondarySpeciesLanguageKey));
    } catch (ex) {
      return LanguageSetting.none;
    }
  }

  set secondarySpeciesLanguage(LanguageSetting languageSetting) {
    _prefs.setString(secondarySpeciesLanguageKey, languageSetting.toString());
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