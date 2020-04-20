import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../db/appdb.dart';
import 'course.dart';
import 'localization.dart';
import 'strings.dart';

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AppState();
}

class AppState extends State<App> {
  Future<AppDb> _appDb;

  @override
  void initState() {
    super.initState();
    _appDb = AppDb.open();
  }

  @override
  Widget build(BuildContext context) {
    final inheritanceDelegate = InheritanceDelegate({
      Locale('en'): Strings_en(),
      Locale('nl'): Strings_nl(),
    });
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => Strings.of(context).appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<AppDb>(
        future: _appDb,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Provider<AppDb>.value(
              value: snapshot.data,
              child: CourseScreen(),
            );
          } else if (snapshot.hasError) {
            throw snapshot.error;
          } else {
            // TODO show splash screen instead
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      localizationsDelegates: [
        inheritanceDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: inheritanceDelegate.supportedLocales,
    );
  }
}