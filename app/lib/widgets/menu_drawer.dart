import 'package:flutter/material.dart';
import 'package:papageno/common/strings.g.dart';

class MenuDrawer extends StatelessWidget {
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
          ListTile(
            leading: Icon(Icons.settings),
            title: Text(strings.settings),
            onTap: () {
              Navigator.of(context)
                  ..pop()
                  ..pushNamed('/settings');
            },
          ),
        ],
      ),
    );
  }

}