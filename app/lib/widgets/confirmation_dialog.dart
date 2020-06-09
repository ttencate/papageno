import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:papageno/common/strings.g.dart';

/// Confirmation dialog with "no" and "yes" buttons. Pops the navigator returning a boolean.
class ConfirmationDialog extends StatelessWidget {
  final Widget title;
  final Widget content;

  const ConfirmationDialog({Key key, this.title, this.content}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return AlertDialog(
      title: title,
      content: content,
      actions: <Widget>[
        FlatButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.no.toUpperCase()),
        ),
        FlatButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.yes.toUpperCase()),
        ),
      ],
    );
  }
}