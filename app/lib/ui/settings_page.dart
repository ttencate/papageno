import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/model.dart';
import '../model/settings.dart';
import 'strings.dart';

class SettingsPage extends StatelessWidget {
  static const route = '/settings';

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
            subtitle: Text(strings.languageName(settings.primarySpeciesLanguageCode)),
            onTap: () async {
              final value = await showDialog<LanguageCode>(
                context: context,
                builder: (context) => LanguagePicker(
                  title: strings.primarySpeciesNameLanguage,
                  allowNone: false,
                ),
              );
              if (value != null) {
                settings.primarySpeciesLanguageCode = value;
              }
            },
          ),
          ListTile(
            title: Text(strings.secondarySpeciesNameLanguage),
            subtitle: Text(strings.languageName(settings.secondarySpeciesLanguageCode)),
            onTap: () async {
              final value = await showDialog<LanguageCode>(
                context: context,
                builder: (context) => LanguagePicker(
                  title: strings.secondarySpeciesNameLanguage,
                  allowNone: true,
                ),
              );
              if (value != null) {
                settings.secondarySpeciesLanguageCode = value;
              }
            },
          ),
          CheckboxListTile(
            title: Text(strings.showScientificName),
            value: settings.showScientificName,
            onChanged: (value) {
              settings.showScientificName = value;
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
    final languageCodes = LanguageCode.all.toList();
    languageCodes.sort((a, b) => strings.languageName(a).compareTo(strings.languageName(b)));
    if (allowNone) {
      languageCodes.insert(0, LanguageCode.none);
    }
    return SimpleDialog(
      title: Text(title),
      children: <Widget>[
        for (final languageCode in languageCodes) SimpleDialogOption(
          child: Text(strings.languageName(languageCode)),
          onPressed: () {
            Navigator.of(context).pop(languageCode);
          },
        ),
      ],
    );
  }
}