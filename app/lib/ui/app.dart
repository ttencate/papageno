import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:papageno/ui/course.dart';
import 'package:provider/provider.dart';

import '../db/appdb.dart';
import 'create_course.dart';
import 'localization.dart';
import 'settings.dart';
import 'splash_screen.dart';
import 'strings.dart';

/// The root widget of the app.
///
/// It performs async initialization of globally available [Provider]s. While this
/// is going on, it shows a [SplashScreen]. When done, it switches to the main
/// page.
class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AppState();
}

class AppState extends State<App> {

  Settings _settings;
  AppDb _appDb;
  Future<void> _loadingFuture;

  @override
  void initState() {
    super.initState();
    // TODO handle exceptions here!
    _loadingFuture = Future.wait([
      Settings.create().then((settings) {
        setState(() { _settings = settings; });
      }),
      AppDb.open().then((appDb) {
        setState(() { _appDb = appDb; });
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final inheritanceDelegate = InheritanceDelegate({
      Locale('en'): Strings_en(),
      Locale('nl'): Strings_nl(),
    });
    return MultiProvider(
      providers: <Provider>[
        Provider<Settings>.value(value: _settings),
        Provider<AppDb>.value(value: _appDb),
      ],
      child: MaterialApp(
        onGenerateTitle: (BuildContext context) => Strings.of(context).appTitle,
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: Colors.green.shade500,
          accentColor: Colors.red.shade600,
        ),
        routes: <String, WidgetBuilder>{
          SplashScreen.route: (context) => SplashScreen(loadingFuture: _loadingFuture),
          CreateCoursePage.route: (context) => CreateCoursePage(),
          CoursePage.route: (context) => CoursePage(),
        },
        initialRoute: SplashScreen.route,
        localizationsDelegates: [
          inheritanceDelegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: inheritanceDelegate.supportedLocales,
      ),
    );
  }
}