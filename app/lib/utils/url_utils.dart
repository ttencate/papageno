import 'dart:developer';

import 'package:url_launcher/url_launcher.dart';

String prettyUrl(String url) => url.replaceFirst(RegExp('^https?://'), '');

Future<void> openUrl(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    log('Could not launch URL ${url}');
  }
}