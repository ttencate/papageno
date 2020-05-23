import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info/package_info.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/theme.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/splash_screen_page.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/settings.dart';
import 'package:papageno/services/user_db.dart';
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

  PackageInfo _packageInfo;
  Settings _settings;
  AppDb _appDb;
  UserDb _userDb;
  Profile _profile;

  @override
  void initState() {
    super.initState();
    // TODO handle exceptions here!
    _loadingFuture = () async {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() { _packageInfo = packageInfo; });

      // All these are I/O-heavy, so it does not seem necessary to try and do them in parallel.
      final appDb = await AppDb.open();
      setState(() { _appDb = appDb; });
      final userDb = await UserDb.open(appDb: _appDb);
      setState(() { _userDb = userDb; });

      // When we start supporting multiple profiles, these objects will be pushed down
      // to lower widgets.
      final profiles = await userDb.getProfiles();
      final profile = profiles.isEmpty ? await userDb.createProfile(null) : profiles.first;
      setState(() { _profile = profile; });

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
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<PackageInfo>.value(value: _packageInfo),
        ChangeNotifierProvider<Settings>.value(value: _settings), // TODO stop providing globally, get from Profile somehow
        Provider<AppDb>.value(value: _appDb),
        Provider<UserDb>.value(value: _userDb),
        Provider<Profile>.value(value: _profile),
      ],
      child: MaterialApp(
        onGenerateTitle: (BuildContext context) => Strings.of(context).appTitleShort,
        theme: appTheme,
        home: Builder(builder: (context) => SplashScreenPage(
          loadingFuture: _loadingFuture,
          onDismissed: () => Navigator.of(context).pushReplacement(CoursesRoute(_profile, proceedAutomatically: true)),
        )),
        localizationsDelegates: [
          Strings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: Strings.supportedLocales,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}