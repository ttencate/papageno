import 'package:flutter/material.dart';

import '../model/model.dart';
import 'strings.dart';
import 'revealing_image.dart';
import 'player.dart';
import '../utils/string_utils.dart';

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
  Species _choice;

  @override
  Widget build(BuildContext context) {
    var instructions = '';
    if (_choice != null) {
      if (_question.isCorrect(_choice)) {
        instructions = Strings.of(context).rightAnswerInstructions;
      } else {
        instructions = Strings.of(context).wrongAnswerInstructions;
      }
    }
    // TODO alternative layout for landscape orientation
    var questionScreen = Column(
      children: <Widget>[
        Expanded(
          child: RevealingImage(
            image: AssetImage('assets/photos/common_blackbird.jpg'),
            revealed: _choice != null,
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
                opacity: _choice == null ? 0.0 : 1.0,
                duration: Duration(seconds: 3),
                // TODO DelayedCurve is just a quick and dirty way to delay the start of the animation, but I'm sure there's a better way.
                curve: _DelayedCurve(delay: 0.5, inner: Curves.easeInOut),
                child: Text(instructions, style: TextStyle(color: Colors.grey)),
              )
          ),
        )
      ],
    );
    if (_choice == null) {
      return questionScreen;
    } else {
      return GestureDetector(
        onTap: widget.onProceed,
        child: questionScreen,
      );
    }
  }

  Widget _buildChoice(Species species) {
    Color color;
    Icon icon;
    if (_choice != null) {
      if (_question.isCorrect(species)) {
        color = Colors.green.shade200;
        icon = Icon(Icons.check_circle, color: Colors.green.shade800);
      } else if (species == _choice) {
        color = Colors.red.shade200;
        icon = Icon(Icons.cancel, color: Colors.red.shade800);
      }
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: color,
//        gradient: RadialGradient(
//          radius: 0.5,
//          colors: [color, color, Colors.transparent],
//          stops: [0.0, 1.0, 1.0],
//        ),
      ),
      child: ListTile(
        title: Text(species.commonNameIn(LanguageCode.language_nl).capitalize()),
        trailing: icon,
        onTap: _choice == null ? () { _choose(species); } : null,
      ),
    );
  }

  void _choose(Species species) {
    assert(_choice == null);
    setState(() {
      _choice = species;
    });
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