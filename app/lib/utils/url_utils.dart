import 'package:logging/logging.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('url_utils');

String prettyUrl(String url) => url.replaceFirst(RegExp('^https?://'), '');

Future<void> openUrl(String url) async {
  if (await canLaunch(url)) {
    _log.fine('Launching URL ${url.ellipsize(256)}');
    await launch(url);
  } else {
    _log.warning('Could not launch URL $url');
  }
}