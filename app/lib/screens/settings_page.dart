import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/services/settings.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final theme = Theme.of(context);
    final settings = Provider.of<Settings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settings),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text(
              strings.speciesNameDisplay.toUpperCase(),
              style: theme.textTheme.subtitle2,
            ),
          ),
          ListTile(
            title: Text(strings.primarySpeciesNameLanguage),
            subtitle: Text(strings.languageSettingName(settings.primarySpeciesLanguage.value)),
            onTap: () async {
              final value = await showDialog<LanguageSetting>(
                context: context,
                builder: (context) => LanguagePicker(
                  title: strings.primarySpeciesNameLanguage,
                  allowNone: false,
                ),
              );
              if (value != null) {
                settings.primarySpeciesLanguage.set(value);
              }
            },
          ),
          ListTile(
            title: Text(strings.secondarySpeciesNameLanguage),
            subtitle: Text(strings.languageSettingName(settings.secondarySpeciesLanguage.value)),
            onTap: () async {
              final value = await showDialog<LanguageSetting>(
                context: context,
                builder: (context) => LanguagePicker(
                  title: strings.secondarySpeciesNameLanguage,
                  allowNone: true,
                ),
              );
              if (value != null) {
                settings.secondarySpeciesLanguage.set(value);
              }
            },
          ),
          CheckboxListTile(
            title: Text(strings.showScientificName),
            value: settings.showScientificName.value,
            onChanged: (value) {
              settings.showScientificName.set(value);
            },
          ),
        ],
      )
    );
  }
}

class LanguagePicker extends StatelessWidget {
  final String title;
  final bool allowNone;

  const LanguagePicker({Key key, this.title, this.allowNone}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final languageCodes = LanguageCode.allSupported
        .map((languageCode) => LanguageSetting.languageCode(languageCode))
        .toList();
    languageCodes.sort((a, b) => strings.languageSettingName(a).compareTo(strings.languageSettingName(b)));
    languageCodes.insert(0, LanguageSetting.system);
    if (allowNone) {
      languageCodes.insert(0, LanguageSetting.none);
    }
    return SimpleDialog(
      title: Text(title),
      children: <Widget>[
        for (final languageCode in languageCodes) SimpleDialogOption(
          child: Text(strings.languageSettingName(languageCode)),
          onPressed: () {
            Navigator.of(context).pop(languageCode);
          },
        ),
      ],
    );
  }
}

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