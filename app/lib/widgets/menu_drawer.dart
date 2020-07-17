import 'package:flutter/material.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/widgets/feedback_dialog.dart';

class MenuDrawer extends StatelessWidget {
  final Profile profile;
  final Course course;

  const MenuDrawer({Key key, this.profile, this.course}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Image(
              image: AssetImage('assets/logo.png'),
            ),
          ),
          if (profile != null) ListTile(
            title: Text(strings.switchProfile),
            subtitle: Text(strings.profileName(profile)),
            onTap: () { _switchProfile(context); },
          ),
          if (course != null) ListTile(
            title: Text(strings.switchCourse),
            subtitle: course == null ? null : Text(strings.courseNameOrLocation(course)),
            onTap: () { _switchCourse(context); },
          ),
          Divider(),
          if (profile?.settings != null) ListTile(
            leading: Icon(Icons.settings),
            title: Text(strings.settings),
            onTap: () { _openSettings(context, profile?.settings); },
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(strings.about),
            onTap: () { _openAbout(context); },
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text(strings.sendFeedbackButton),
            onTap: () { _openFeedback(context); },
          ),
          Divider(),
        ],
      ),
    );
  }

  void _switchProfile(BuildContext context) {
    // TODO Navigator.popUntil() doesn't honor the route's willPop() callback.
    //  Reimplementing it in terms of maybePop() seems fraught with peril though.
    Navigator.of(context).popUntil((route) => route is ProfilesRoute);
  }

  void _switchCourse(BuildContext context) {
    // TODO Navigator.popUntil() doesn't honor the route's willPop() callback.
    //  Reimplementing it in terms of maybePop() seems fraught with peril though.
    Navigator.of(context).popUntil((route) => route is CoursesRoute);
  }

  void _openSettings(BuildContext context, Settings settings) {
    Navigator.of(context)
        ..pop()
        ..push(SettingsRoute(settings));
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context)
        ..pop()
        ..push(AboutRoute());
  }

  void _openFeedback(BuildContext context) {
    Navigator.of(context).pop();
    showDialog<void>(context: context, builder: (context) => FeedbackDialog());
  }
}