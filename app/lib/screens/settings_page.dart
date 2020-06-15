import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';

class SettingsPage extends StatelessWidget {
  final Settings settings;

  const SettingsPage(this.settings);

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settings),
      ),
      body: AnimatedBuilder( // Strangely named widget: https://github.com/flutter/flutter/issues/50528#issuecomment-584781225
        animation: settings,
        builder: (context, _) => ListView(
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
              onChanged: settings.showScientificName.set,
            ),
            Divider(),
            ListTile(
              title: Text(strings.debugLogButton),
              onTap: () {
                Navigator.of(context)
                    ..pop()
                    ..push(DebugLogRoute());
              },
            )
          ],
        ),
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
        .toList()
        ..sort((a, b) => strings.languageSettingName(a).compareTo(strings.languageSettingName(b)))
        ..insert(0, LanguageSetting.system);
    if (allowNone) {
      languageCodes.insert(0, LanguageSetting.none);
    }
    return SimpleDialog(
      title: Text(title),
      children: <Widget>[
        for (final languageCode in languageCodes) SimpleDialogOption(
          onPressed: () {
            Navigator.of(context).pop(languageCode);
          },
          child: Text(strings.languageSettingName(languageCode)),
        ),
      ],
    );
  }
}