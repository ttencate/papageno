import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:package_info/package_info.dart';
import 'package:papageno/common/log_writer.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/theme.dart';
import 'package:papageno/screens/splash_screen_page.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

LogWriter _logWriter;

final _log = Logger('main');

Future<void> main() async {
  _logWriter = await LogWriter.toCache();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final formattedMessage = '${record.level.name} ${record.time} ${record.message} ${record.error ?? ''} ${record.stackTrace ?? ''}';
    print(formattedMessage); // ignore: avoid_print
    _logWriter.write(formattedMessage);
  });

  _log.info('Starting application');

  // Forcing portrait mode until we implement landscape layouts (https://github.com/ttencate/papageno/issues/16)
  // https://stackoverflow.com/a/52720581/14637
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  runZonedGuarded(() { runApp(App()); }, _handleError);
}

void _handleError(dynamic exception, StackTrace stackTrace) {
  _log.severe('uncaught future error', exception, stackTrace);
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
  AppDb _appDb;
  UserDb _userDb;

  @override
  void initState() {
    super.initState();
    // TODO handle exceptions here!
    _loadingFuture = () async {
      // According to the `intl` docs we need to call this:
      // await initializeDateFormatting(null, null);
      // But on Flutter it crashes because Material also initializes it:
      // https://github.com/flutter/flutter/issues/15741

      final packageInfo = await PackageInfo.fromPlatform();
      setState(() { _packageInfo = packageInfo; });

      // All these are I/O-heavy, so it does not seem useful to try and do them in parallel.
      final appDb = await AppDb.open();
      setState(() { _appDb = appDb; });
      final userDb = await UserDb.open(appDb: _appDb);
      setState(() { _userDb = userDb; });
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
        Provider<LogWriter>.value(value: _logWriter),
        Provider<PackageInfo>.value(value: _packageInfo),
        Provider<AppDb>.value(value: _appDb),
        Provider<UserDb>.value(value: _userDb),
      ],
      child: MaterialApp(
        onGenerateTitle: (BuildContext context) => Strings.of(context).appTitleShort,
        theme: appTheme,
        home: Builder(builder: (context) => SplashScreenPage(
          loadingFuture: _loadingFuture,
          onDismissed: () => Navigator.of(context).pushReplacement(ProfilesRoute(proceedAutomatically: true)),
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