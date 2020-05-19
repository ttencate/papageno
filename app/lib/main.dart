import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:papageno/db/app_db.dart';
import 'package:papageno/db/user_db.dart';
import 'package:papageno/common/localization.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/screens/splash_screen_page.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  // Forcing portrait mode until we implement landscape layouts (https://github.com/ttencate/papageno/issues/16)
  // https://stackoverflow.com/a/52720581/14637
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])
    .then((_) {
      runApp(App());
    });
}

/// The root widget of the app.
///
/// It performs async initialization of globally available [Provider]s. While this
/// is going on, it shows a [SplashScreenPage]. When done, it switches to the main
/// page.
class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AppState();
}

class AppState extends State<App> {

  Future<void> _loadingFuture;

  Settings _settings;
  AppDb _appDb;
  UserDb _userDb;

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
        onGenerateTitle: (BuildContext context) => Strings.of(context).appTitle,
        theme: appTheme,
        routes: appRoutes,
        home: Builder(builder: (context) => SplashScreenPage(
          loadingFuture: _loadingFuture,
          onDismissed: () => Navigator.of(context).pushReplacementNamed(Routes.createCourse),
        )),
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