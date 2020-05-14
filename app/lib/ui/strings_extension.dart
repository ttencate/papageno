import '../model/model.dart';
import 'strings.g.dart';

extension StringsExtension on Strings {
  String languageName(LanguageCode languageCode) {
    if (languageCode == null || languageCode.toString() == '') {
      return languageNone;
    }
    final dynamic languageName = this['language_${languageCode.toString()}'];
    return languageName is String ? languageName : '?';
  }
}