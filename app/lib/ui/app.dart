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
    return FutureProvider<AppDb>.value(
      value: _appDb,
      child: Consumer<AppDb>(
        builder: (context, value, child) {
          if (value == null) {
            return _buildSplashScreen();
          } else {
            return _buildApp(context);
          }
        },
      ),
    );
  }

  Container _buildSplashScreen() {
    // TODO show logo, title, etc.
    return Container(
      color: Colors.white,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildApp(BuildContext context) {
    final inheritanceDelegate = InheritanceDelegate({
      Locale('en'): Strings_en(),
      Locale('nl'): Strings_nl(),
    });
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => Strings.of(context).appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CourseScreen(),
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