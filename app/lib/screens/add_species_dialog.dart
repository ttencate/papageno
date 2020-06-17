import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:provider/provider.dart';

/// A dialog that prompts the user to select some species to add to the course.
/// Pops the [Navigator] with a nonempty `List<Species>`, or `null` if cancelled.
class AddSpeciesDialog extends StatefulWidget {
  final Course course;
  final Settings settings;

  const AddSpeciesDialog({Key key, this.course, this.settings}) : super(key: key);

  @override
  _AddSpeciesDialogState createState() => _AddSpeciesDialogState();
}

class _AddSpeciesDialogState extends State<AddSpeciesDialog> {
  bool _selectManually = false;
  final Set<Species> _selectedSpecies = <Species>{};
  final List<Species> _candidates = <Species>[];

  @override
  void initState() {
    super.initState();
    final unlockedSpecies = widget.course.unlockedSpecies.toSet();
    _candidates.addAll(widget.course.localSpecies.where((s) => !unlockedSpecies.contains(s)));
    _selectedSpecies.addAll(_candidates.take(5));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final settings = widget.settings;
    final locale = WidgetsBinding.instance.window.locale;
    final orderedSelectedSpecies = _orderedSelectedSpecies();
    const padding = 24.0;
    return Dialog(
      insetPadding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(padding),
            child: Text(
              strings.addSpeciesTitle,
              style: theme.textTheme.headline6,
            ),
          ),
          Divider(height: 0.0),
          if (!_selectManually) Padding(
            padding: const EdgeInsets.all(padding),
            child: Text(
              strings.addSpeciesText(_selectedSpecies.length),
              style: theme.textTheme.bodyText2,
            ),
          ),
          if (!_selectManually) Expanded(
            flex: 0,
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final species in orderedSelectedSpecies) Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8.0),
                  child: Text(
                    species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
                    style: theme.textTheme.subtitle1,
                  ),
                ),
              ],
            ),
          ),
          if (!_selectManually) Align(
            alignment: Alignment.centerLeft,
            child: FlatButton(
              onPressed: _enableManualSelection,
              child: Text(strings.chooseSpeciesToAddButton.toUpperCase()),
            ),
          ),
          if (_selectManually) Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: padding - 16.0),
              itemCount: _candidates.length,
              itemBuilder: (context, index) {
                final species = _candidates[index];
                return CheckboxListTile(
                  dense: true,
                  value: _selectedSpecies.contains(species),
                  onChanged: (value) { _setSelection(species, value); },
                  title: Text(
                    species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
                    style: theme.textTheme.subtitle1, // dense: true also makes the font needlessly small; override it.
                  ),
                );
              },
            ),
          ),
          Divider(height: 0.0),
          ButtonBar(
            children: <Widget>[
              FlatButton(
                onPressed: _cancel,
                child: Text(strings.cancel.toUpperCase()),
              ),
              FlatButton(
                onPressed: _selectedSpecies.isEmpty ? null : _add,
                child: Text(strings.addSelectedSpeciesButton(_selectedSpecies.length).toUpperCase()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _enableManualSelection() {
    setState(() { _selectManually = true; });
  }

  void _setSelection(Species species, bool selected) {
    setState(() {
      if (selected) {
        _selectedSpecies.add(species);
      } else {
        _selectedSpecies.remove(species);
      }
    });
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  void _add() {
    Navigator.of(context).pop(_orderedSelectedSpecies());
  }

  List<Species> _orderedSelectedSpecies() => _candidates
      .where(_selectedSpecies.contains)
      .toList(growable: false);
}