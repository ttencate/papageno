import 'package:flutter/material.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/model/user_model.dart';

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
//          ListTile(
//            title: Text(strings.profile),
//          ),
          if (course != null) ListTile(
            title: Text(strings.switchCourse),
            subtitle: course == null ? null : Text(strings.courseName(course)),
            onTap: () { _switchCourse(context); },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text(strings.settings),
            onTap: () { _openSettings(context); },
          ),
        ],
      ),
    );
  }

  void _switchCourse(BuildContext context) async {
    // TODO Navigator.popUntil() doesn't honor the route's willPop() callback.
    //  Reimplementing it in terms of maybePop() seems fraught with peril though.
    Navigator.of(context).popUntil((route) => route is CoursesRoute);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        ..pop()
        ..push(SettingsRoute());
  }
}