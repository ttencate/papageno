import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:papageno/ui/course.dart';
import 'package:provider/provider.dart';

import '../db/appdb.dart';
import 'create_course.dart';
import 'localization.dart';
import 'settings.dart';
import 'strings.dart';

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AppState();
}

/// The root widget of the app.
///
/// It performs async initialization of globally available [Provider]s. While this
/// is going on, it shows a [_SplashScreen]. When done, it switches to the [_Main]
/// page.
class AppState extends State<App> {
  Settings _settings;
  AppDb _appDb;
  bool _loading;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _initAsync();
  }

  Future<void> _initAsync() async {
    // Kick off all async operations in parallel before awaiting any of them.
    final settingsFuture = Settings.create();
    final appDbFuture = AppDb.open();
    final settings = await settingsFuture;
    final appDb = await appDbFuture;
    setState(() {
      _settings = settings;
      _appDb = appDb;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _SplashScreen();
    } else {
      return Provider<Settings>.value(
        value: _settings,
        child: Provider<AppDb>.value(
          value: _appDb,
          child: _Main(),
        ),
      );
    }
  }
}

class _SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO show logo, title, etc.
    return Container(
      color: Colors.white,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _Main extends StatelessWidget {
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
      routes: <String, WidgetBuilder>{
        CreateCoursePage.route: (context) => CreateCoursePage(),
        CoursePage.route: (context) => CoursePage(),
      },
      initialRoute: CreateCoursePage.route,
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
