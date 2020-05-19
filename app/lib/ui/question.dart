import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:papageno/model/user_model.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:papageno/db/app_db.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/app_model.dart' as model show Image; // Avoid conflict with Flutter's Image class.
import 'package:papageno/model/settings.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:papageno/ui/player.dart';
import 'package:papageno/ui/revealing_image.dart';
import 'package:papageno/ui/strings.g.dart';

class QuestionScreen extends StatefulWidget {
  final Question question;
  final Function() onProceed;

  QuestionScreen({Key key, @required this.question, this.onProceed}) :
        assert(question != null),
        super(key: key);

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {

  Question get _question => widget.question;
  model.Image _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appDb = Provider.of<AppDb>(context);
    appDb.imageForOrNull(_question.correctAnswer).then((image) {
      if (image != null) {
        setState(() { _image = image; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.window.locale;
    final instructions = _question.isAnswered ? Strings.of(context).tapInstructions : '';
    final theme = Theme.of(context);
    final textOnImageColor = Colors.white;
    final textOnImageShadows = <Shadow>[
      Shadow(blurRadius: 3.0),
      Shadow(blurRadius: 6.0),
    ];
    final settings = Provider.of<Settings>(context);
    // TODO alternative layout for landscape orientation
    var questionScreen = Column(
      children: <Widget>[
        Expanded(
          child: RevealingImage(
            image: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: <Widget>[
                if (_image == null) Placeholder(),
                if (_image != null) material.Image(
                  image: AssetImage(join('assets', 'images', _image.fileName)),
                  fit: BoxFit.cover,
                ),
                if (_image != null) ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 8.0,
                      sigmaY: 8.0,
                    ),
                    child: material.Image(
                      image: AssetImage(join('assets', 'images', _image.fileName)),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(2.0),
                    child: Column(
                      children: <Widget>[
                        Text(
                          _question.correctAnswer.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
                          style: theme.textTheme.headline6.copyWith(
                            color: textOnImageColor,
                            shadows: textOnImageShadows,
                          ),
                        ),
                        if (settings.secondarySpeciesLanguage != null) Text(
                          _question.correctAnswer.commonNameIn(settings.secondarySpeciesLanguage.value.resolve(locale)).capitalize(),
                          style: theme.textTheme.headline6.copyWith(
                            color: textOnImageColor,
                            shadows: textOnImageShadows,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        if (settings.showScientificName.value) Text(
                          _question.correctAnswer.scientificName.capitalize(),
                          style: theme.textTheme.caption.copyWith(
                            fontStyle: FontStyle.italic,
                            color: textOnImageColor,
                            shadows: textOnImageShadows,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 0.0,
                  top: 0.0,
                  child: IconButton(
                    icon: Icon(Icons.info_outline),
                    iconSize: 32.0,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    color: Colors.white.withOpacity(0.5),
                    onPressed: _showAttribution,
                  )
                ),
              ],
            ),
            revealed: _question.isAnswered,
          ),
        ),
        Player(
          key: GlobalObjectKey(_question.recording),
          recording: _question.recording,
        ),
        Divider(height: 0.0),
        for (var widget in ListTile.divideTiles(
          context: context,
          tiles: _question.choices.map(_buildChoice),
        )) widget,
        Divider(height: 0.0),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(
              child: AnimatedOpacity(
                key: GlobalObjectKey(_question),
                opacity: _question.isAnswered ? 1.0 : 0.0,
                duration: Duration(seconds: 3),
                // TODO DelayedCurve is just a quick and dirty way to delay the start of the animation, but I'm sure there's a better way.
                curve: _DelayedCurve(delay: 0.5, inner: Curves.easeInOut),
                child: Text(instructions, style: theme.textTheme.caption),
              )
          ),
        )
      ],
    );
    if (!_question.isAnswered) {
      return questionScreen;
    } else {
      return GestureDetector(
        onTap: widget.onProceed,
        child: questionScreen,
      );
    }
  }

  Widget _buildChoice(Species species) {
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
    Color color;
    AnswerIcon icon;
    if (_question.isAnswered) {
      if (species == _question.correctAnswer) {
        color = Colors.green.shade200;
        icon = AnswerIcon(correct: true);
      } else if (species == _question.givenAnswer) {
        color = Colors.red.shade200;
        icon = AnswerIcon(correct: false);
      }
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: color,
        // TODO animate the background appearing, in the Material ink manner
//        gradient: RadialGradient(
//          radius: 0.5,
//          colors: [color, color, Colors.transparent],
//          stops: [0.0, 1.0, 1.0],
//        ),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
          textScaleFactor: 1.5,
        ),
        trailing: icon,
        onTap: _question.isAnswered ? null : () { _choose(species); },
      ),
    );
  }

  void _choose(Species species) {
    if (!_question.isAnswered) {
      setState(() {
        _question.answerWith(species);
      });
    }
  }

  void _showAttribution() {
    showDialog<void>(
      context: context,
      builder: (context) => AttributionDialog(
        recording: _question.recording,
        image: _image,
      ),
    );
  }
}

class AnswerIcon extends StatelessWidget {
  final bool correct;

  const AnswerIcon({Key key, this.correct}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (correct) {
      return Icon(Icons.check_circle, color: Colors.green.shade800);
    } else {
      return Icon(Icons.cancel, color: Colors.red.shade800);
    }
  }
}

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
              linkText: _prettyUrl(recording.sourceUrl),
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
              linkText: _prettyUrl(image.sourceUrl),
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

  String _prettyUrl(String url) => url.replaceFirst(RegExp('^https?://'), '');
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
      onTap: url == null ? null : () { _openUrl(url); },
    );
  }

  void _openUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      log('Could not launch URL ${url}');
    }
  }
}

class _DelayedCurve extends Curve {
  const _DelayedCurve({this.delay, this.inner}) :
        assert(delay >= 0),
        assert(delay <= 1);

  final double delay;
  final Curve inner;

  @override
  double transform(double t) {
    if (t <= delay) {
      return 0.0;
    } else {
      return inner.transform((t - delay) / (1.0 - delay));
    }
  }
}