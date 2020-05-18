import 'package:papageno/model/settings.dart';
import 'package:papageno/ui/strings.g.dart';

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