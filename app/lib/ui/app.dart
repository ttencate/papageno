import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:papageno/ui/course.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../db/appdb.dart';
import '../db/userdb.dart';
import '../model/settings.dart';
import 'create_course.dart';
import 'localization.dart';
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
  UserDb _userDb;
  Future<void> _loadingFuture;

  @override
  void initState() {
    super.initState();
    // TODO handle exceptions here!
    _loadingFuture = () async {
      // All these are I/O-heavy, so it does not seem necessary to try and do them in parallel.
      final appDb = await AppDb.open();
      setState(() { _appDb = appDb; });
      final userDb = await UserDb.open();
      setState(() { _userDb = userDb; });

      // XXX When we start supporting multiple profiles, these objects will be pushed down
      // to lower widgets.
      final profiles = await userDb.getProfiles();
      final profile = profiles.isEmpty ? await userDb.createProfile(null) : profiles.first;
      final settings = await Settings.create(userDb, profile);
      setState(() { _settings = settings; });
    }();
  }

  @override
  void dispose() {
    if (_userDb != null) {
      _userDb.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO autogenerate this as a const in the Strings class
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
        Provider<UserDb>.value(value: _userDb),
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