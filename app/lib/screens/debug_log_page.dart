import 'package:flutter/material.dart';
import 'package:papageno/common/log_writer.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:provider/provider.dart';

class DebugLogPage extends StatefulWidget {
  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {

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
}