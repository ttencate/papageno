import '../model/settings.dart';
import 'strings.g.dart';

extension StringsExtension on Strings {
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