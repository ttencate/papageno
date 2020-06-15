import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
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

Future<void> openEmailApp({@required String toAddress, String subject, String body}) async {
  await openUrl(
      'mailto:$toAddress'
      '?subject=${_encodeEmailQueryComponent(subject ?? '')}'
      '&body=${_encodeEmailQueryComponent(_toHtml(body))}');
}

String _encodeEmailQueryComponent(String s) {
  // The + character is not unescaped by the Gmail app, so we need to percent-encode it instead.
  return Uri.encodeQueryComponent(s).replaceAll('+', '%20');
}

String _toHtml(String s) {
  // Apparently the Gmail app expects HTML, so we need to encode special characters,
  // and replace line endings by `<br>`.
  return s.replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('\n', '<br>');
}