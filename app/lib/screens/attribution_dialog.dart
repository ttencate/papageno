import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/app_model.dart' as model show Image;
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/utils/url_utils.dart';// Avoid conflict with Flutter's Image class.

class AttributionDialog extends StatelessWidget {

  final Recording recording;
  final model.Image image;

  const AttributionDialog({@required this.recording, @required this.image});

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: EdgeInsets.all(8.0),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LinkTile(
                text: strings.recordingCreator,
                linkText: _creatorName(recording.attribution, context),
                url: null,
                style: theme.textTheme.headline6,
              ),
              _LinkTile(
                text: strings.source,
                linkText: prettyUrl(recording.sourceUrl),
                url: recording.sourceUrl,
              ),
              _LinkTile(
                text: strings.license,
                linkText: recording.licenseName,
                url: recording.licenseUrl,
              ),
              Divider(),
              _LinkTile(
                text: strings.imageCreator,
                linkText: image.attribution,
                url: null,
                style: theme.textTheme.headline6,
              ),
              _LinkTile(
                text: strings.source,
                linkText: prettyUrl(image.sourceUrl),
                url: image.sourceUrl,
              ),
              _LinkTile(
                text: strings.license,
                linkText: image.licenseName,
                url: image.licenseUrl,
              ),
              Divider(),
            ],
          )
      ),
      actions: <Widget>[
        FlatButton(
          child: Text(strings.ok),
          onPressed: () => Navigator.of(context).pop(),
        )
      ],
    );
  }

  String _creatorName(String attribution, BuildContext context) =>
      attribution != null && attribution.isNotEmpty ?
      attribution :
      Strings.of(context).unknownCreator;
}

class _LinkTile extends StatelessWidget {

  final String Function(String) text;
  final String linkText;
  final String url;
  final TextStyle style;

  const _LinkTile({Key key, this.text, this.linkText, this.url, this.style}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var linkColor = Theme.of(context).accentColor;
    var textStyle = style ?? DefaultTextStyle.of(context).style;
    const placeholder = '__LINK_TEXT__';
    final replacedText = text(placeholder);
    final placeholderIndex = replacedText.indexOf(placeholder);
    final textBeforeLink = replacedText.substring(0, placeholderIndex);
    final textAfterLink = replacedText.substring(placeholderIndex + placeholder.length);
    return ListTile(
      title: RichText(
        text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: textBeforeLink,
                style: textStyle,
              ),
              TextSpan(
                text: linkText,
                style: url == null ? textStyle : textStyle.copyWith(color: linkColor),
              ),
              TextSpan(
                text: textAfterLink,
                style: textStyle,
              ),
            ]
        ),
      ),
      onTap: url == null ? null : () { openUrl(url); },
    );
  }
}