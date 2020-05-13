import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app.dart';

void main() {
  // Forcing portrait mode until we implement landscape layouts (https://github.com/ttencate/papageno/issues/16)
  // https://stackoverflow.com/a/52720581/14637
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])
    .then((_) {
      runApp(App());
    });
}