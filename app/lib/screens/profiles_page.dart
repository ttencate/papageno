import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/widgets/confirmation_dialog.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';

class ProfilesPage extends StatefulWidget {
  final bool proceedAutomatically;

  const ProfilesPage({Key key, this.proceedAutomatically}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  UserDb _userDb;

  Future<List<Profile>> _profiles;
  bool _proceedAutomatically;

  @override
  void initState() {
    super.initState();
    _proceedAutomatically = widget.proceedAutomatically;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userDb = Provider.of<UserDb>(context);
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() { _profiles = _userDb.getProfiles(); });
    final profiles = await _profiles;
    if (_proceedAutomatically) {
      _proceedAutomatically = false;
      if (profiles.isEmpty) {
        final profile = await _createAnonymousProfile();
        unawaited(_loadProfiles()); // Reload in the background.
        unawaited(_openProfile(profile, proceedAutomatically: true));
      } else if (profiles.length == 1) {
        unawaited(_openProfile(profiles.single, proceedAutomatically: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profiles),
      ),
      drawer: MenuDrawer(),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              strings.profilesExplanation,
              softWrap: true,
              style: theme.textTheme.bodyText2,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Profile>>(
              future: _profiles,
              builder: (context, snapshot) =>
              snapshot.hasData ?
              ListView(
                children: ListTile.divideTiles(context: context, tiles: <Widget>[
                  for (final profile in snapshot.data) ListTile(
                    title: Text(strings.profileName(profile)),
                    subtitle: Text(strings.profileLastUsed(strings.profileLastUsedDate(profile))),
                    onTap: () { _openProfile(profile); },
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () { _editProfile(profile); },
                    ),
                  ),
                ]).toList(),
              ) :
              Center(child: CircularProgressIndicator())
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: RaisedButton(
              onPressed: _createProfile,
              child: Text(strings.startCreatingProfileButton.toUpperCase()),
            ),
          )
        ],
      ),
    );
  }

  Future<Profile> _createAnonymousProfile() async {
    return _userDb.createProfile(null);
  }

  Future<Profile> _createProfile() async {
    final result = await showDialog<_ProfileDialogResult>(
      context: context,
      builder: (BuildContext context) => _ProfileDialog(profile: null),
    );
    if (result == null) {
      return null;
    }
    assert(result.name != null);
    final profile = await _userDb.createProfile(result.name.isEmpty ? null : result.name);
    await _loadProfiles();
    return profile;
  }

  Future<void> _editProfile(Profile profile) async {
    final result = await showDialog<_ProfileDialogResult>(
      context: context,
      builder: (BuildContext context) => _ProfileDialog(profile: profile),
    );
    if (result == null) {
      return;
    }if (result.name != null) {
      await _userDb.renameProfile(profile, result.name);
      await _loadProfiles();
    } else if (result.delete) {
      await _maybeDeleteProfile(profile);
    }
  }

  Future<void> _maybeDeleteProfile(Profile profile) async {
    final strings = Strings.of(context);
    final reallyDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ConfirmationDialog(
        content: Text(strings.deleteProfileConfirmation(strings.profileName(profile))),
      ),
    ) ?? false;
    if (reallyDelete) {
      await _userDb.deleteProfile(profile);
      await _loadProfiles();
    }
  }

  Future<void> _openProfile(Profile profile, {bool proceedAutomatically = false}) async {
    profile.settings = await Settings.create(_userDb, profile);
    unawaited(Navigator.of(context).push(CoursesRoute(profile, proceedAutomatically: proceedAutomatically)));
  }
}

@immutable
class _ProfileDialogResult {
  final String name;
  final bool delete;

  _ProfileDialogResult({this.name, this.delete});
}

class _ProfileDialog extends StatefulWidget {
  /// Caution: may be `null`.
  final Profile profile;

  const _ProfileDialog({Key key, this.profile}) : super(key: key);

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.profile?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(widget.profile == null ? strings.createProfileTitle : strings.editProfileTitle),
          if (widget.profile != null) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(_ProfileDialogResult(delete: true)),
            icon: Icon(Icons.delete),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: strings.profileNameLabel.toUpperCase(),
          hintText: strings.profileNamePlaceholder,
        ),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel.toUpperCase()),
        ),
        FlatButton(
          onPressed: () => Navigator.of(context).pop(_ProfileDialogResult(name: _controller.text)),
          child: Text(strings.ok.toUpperCase()),
        ),
      ],
    );
  }
}