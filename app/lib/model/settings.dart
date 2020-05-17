import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:papageno/db/userdb.dart';
import 'package:papageno/model/model.dart';

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

  factory LanguageSetting.fromString(String string, [LanguageSetting defaultValue]) {
    if (string == null) {
      return defaultValue;
    }
    switch (string) {
      case SystemLanguageSetting._stringValue:
        return system;
      case NoneLanguageSetting._stringValue:
        return none;
      default:
        LanguageCode languageCode;
        try {
          languageCode = LanguageCode.fromString(string);
        } catch (ex) {
          return defaultValue;
        }
        return LanguageCodeLanguageSetting._internal(languageCode);
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

class Settings with ChangeNotifier {

  final Setting<LanguageSetting> primarySpeciesLanguage =
      Setting.language('primarySpeciesLanguage', LanguageSetting.system);
  final Setting<LanguageSetting> secondarySpeciesLanguage =
      Setting.language('secondarySpeciesLanguage', LanguageSetting.none);
  final Setting<bool> showScientificName =
      Setting.boolean('showScientificName', false);

  final UserDb _userDb;
  final int _profileId;

  static Future<Settings> create(UserDb userDb, Profile profile) async {
    final settings = Settings._internal(userDb, profile.profileId);
    await settings._init();
    return settings;
  }

  Settings._internal(this._userDb, this._profileId);

  Future<void> _init() async {
    await primarySpeciesLanguage._init(this);
    await secondarySpeciesLanguage._init(this);
    await showScientificName._init(this);
  }

  void _notifyListeners() {
    notifyListeners();
  }
}

class Setting<T> {
  final String _key;
  final T Function(String string) _parse;
  final String Function(T value) _serialize;
  final T _defaultValue;

  Settings _settings;
  T _value;

  Setting._create(this._key, this._parse, this._serialize, this._defaultValue) {
    _value = _defaultValue;
  }

  static Setting<LanguageSetting> language(String key, LanguageSetting defaultValue) =>
    Setting._create(key, (s) => LanguageSetting.fromString(s), (v) => v.toString(), defaultValue);

  static Setting<bool> boolean(String key, bool defaultValue) =>
    Setting._create(key, (s) => s == '1', (v) => v ? '1' : '0', defaultValue);

  Future<void> _init(Settings settings) async {
    _settings = settings;
    var string = await settings._userDb.getSetting(settings._profileId, _key);
    _value = _defaultValue;
    if (string != null) {
      try {
        _value = _parse(string);
        // ignore: empty_catches
      } catch (ignored) {}
    }
  }

  T get value {
    return _value;
  }

  void set(T value) {
    _value = value;
    _settings._userDb.setSetting(_settings._profileId, _key, _serialize(value)); // Future not awaited!
    _settings._notifyListeners();
  }
}