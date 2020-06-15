import 'package:flutter/material.dart';
import 'package:papageno/common/log_writer.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/utils/url_utils.dart';
import 'package:provider/provider.dart';

class DebugLogPage extends StatefulWidget {
  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  static const emailAddress = 'thomas@papageno.app';
  static const emailSubject = 'Papageno debug log';
  static const emailBodyPrefix = '\n\n---\nWrite your message above this line. I understand English and Dutch.\n---\n';

  Future<String> _logContents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logWriter = Provider.of<LogWriter>(context);
    _logContents = logWriter.getContents()
        .catchError((dynamic e) => 'Could not load log contents: $e');
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.debugLogTitle),
        actions: <Widget>[
          FutureBuilder<String>(
            future: _logContents,
            builder: (context, snapshot) =>
              snapshot.hasData ?
              IconButton(
                icon: Icon(Icons.mail),
                onPressed: () { _emailLog(snapshot.data); },
              ) :
              Container(),
          )
        ],
      ),
      body: FutureBuilder<String>(
        future: _logContents,
        builder: (context, snapshot) =>
          snapshot.hasData ?
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                snapshot.data,
                softWrap: true,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.0),
              ),
            ),
          ) :
          Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _emailLog(String logContents) {
    final subject = _encodeQueryComponent(emailSubject);
    final body = _encodeQueryComponent('$emailBodyPrefix$logContents');
    openUrl('mailto:$emailAddress?subject=$subject&body=$body');
  }

  static String _encodeQueryComponent(String s) {
    // Apparently the Gmail app expects HTML, so we need to encode special characters,
    // and replace line endings by `<br>`.
    s = s.replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('\n', '<br>');
    // The + character is not unescaped by the Gmail app, so we need to percent-encode it instead.
    return Uri.encodeQueryComponent(s).replaceAll('+', '%20');
  }
}