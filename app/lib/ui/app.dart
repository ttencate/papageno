import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:papageno/ui/course.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../db/appdb.dart';
import 'create_course.dart';
import 'localization.dart';
import '../model/settings.dart';
import 'settings_page.dart';
import 'splash_screen.dart';
import 'strings.g.dart';

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
    final inheritanceDelegate = InheritanceDelegate<Strings>({
      // Order is important: the first entry becomes the default locale.
      // (Map literals are LinkedHashMaps, thus order-preserving.)
      Locale('en'): Strings_en(),
      Locale('nl'): Strings_nl(),
    });
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<Settings>.value(value: _settings),
        Provider<AppDb>.value(value: _appDb),
      ],
      child: MaterialApp(
        onGenerateTitle: (BuildContext context) =>  Strings.of(context).appTitle,
        theme: ThemeData(
          brightness: Brightness.light,
          // Circle in icon: green 500 - green 900.
          primarySwatch: Colors.green,
          primaryColor: Colors.green.shade800,
          primaryColorLight: Colors.green.shade500,
          primaryColorDark: Colors.green.shade900,
          primaryColorBrightness: Brightness.dark,
          // Question mark in icon: yellow 500 - yellow 800.
          // Using the dark end because it needs to contrast well with white.
          accentColor: Colors.yellow.shade800,
          accentColorBrightness: Brightness.light,
          buttonTheme: ButtonThemeData(
            buttonColor: Colors.green.shade600,
            textTheme: ButtonTextTheme.primary,
          ),
          iconTheme: IconThemeData(
            color: Colors.green.shade500,
          ),
        ),
        routes: <String, WidgetBuilder>{
          SplashScreen.route: (context) => SplashScreen(loadingFuture: _loadingFuture),
          CreateCoursePage.route: (context) => CreateCoursePage(),
          CoursePage.route: (context) => CoursePage(),
          SettingsPage.route: (context) => SettingsPage(),
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