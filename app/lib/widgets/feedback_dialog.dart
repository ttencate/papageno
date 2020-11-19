
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:papageno/common/log_writer.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/utils/email_utils.dart';
import 'package:provider/provider.dart';

const _feedbackEmail = 'thomas@papageno.app';

class FeedbackDialog extends StatefulWidget {
  @override
  _FeedbackDialogState createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {

  bool _includeDebugLog = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
            child: Text(
              strings.feedbackExplanation,
              softWrap: true,
            ),
          ),
          CheckboxListTile(
            title: Text(strings.feedbackIncludeDebugLog),
            value: _includeDebugLog,
            onChanged: (bool value) { setState(() { _includeDebugLog = value; }); },
          ),
          /*
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(strings.feedbackIncludeDebugLog),
              Checkbox(
                value: _includeDebugLog,
                onChanged: (bool value) { setState(() { _includeDebugLog = value; }); },
              ),
            ],
          ),
          */
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Text(
              strings.feedbackIncludeDebugLogExplanation,
              style: theme.textTheme.caption,
            ),
          ),
        ]
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () { Navigator.of(context).pop(); },
          child: Text(strings.cancel.toUpperCase()),
        ),
        FlatButton(
          onPressed: _sendFeedback,
          child: Text(strings.feedbackStartEmailAppButton.toUpperCase()),
        ),
      ],
    );
  }

  Future<void> _sendFeedback() async {
    final strings = Strings.of(context);
    var body = strings.feedbackEmailTemplate;
    final attachments = <Attachment>[];
    if (_includeDebugLog) {
      try {
        final logContents = await _loadLog();
        final attachment = await Attachment.fromString('log.txt', logContents);
        attachments.add(attachment);
      } catch (e, s) {
        body += '\n\n---\n\nError attaching log file:\n$e\n$s';
      }
    }
    await openEmailApp(
      toAddress: _feedbackEmail,
      body: body,
      attachments: attachments,
    );
  }

  Future<String> _loadLog() async {
    final logWriter = Provider.of<LogWriter>(context, listen: false);
    return logWriter.getContents();
  }
}