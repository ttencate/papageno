import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/app_model.dart' as model show Image; // Avoid conflict with Flutter's Image class.
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/attribution_dialog.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/iterable_utils.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:papageno/widgets/player.dart';
import 'package:papageno/widgets/revealing_image.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';

class QuizPageResult {
  final bool restart;

  QuizPageResult({@required this.restart});
}

class QuizPage extends StatefulWidget {
  final Profile profile;
  final Course course;
  final Quiz quiz;

  QuizPage(this.profile, this.course, this.quiz);

  @override
  State<StatefulWidget> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {

  PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  Quiz get quiz => widget.quiz;

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return ChangeNotifierProvider<Settings>.value(
      value: widget.profile.settings,
      child: WillPopScope(
        onWillPop: _willPop,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              !quiz.isComplete ?
              strings.questionIndex(quiz.currentQuestionNumber, quiz.questionCount) :
              strings.quizResultsTitle
            ),
            // TODO show some sort of progress bar
          ),
          drawer: MenuDrawer(profile: widget.profile, course: widget.course),
          body: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            itemCount: quiz.currentQuestionIndex + 1,
            itemBuilder: (BuildContext context, int index) =>
              index < quiz.questionCount ?
              QuestionScreen(
                key: ObjectKey(quiz.questions[index]),
                question: quiz.questions[index],
                onAnswer: _storeAnswer,
                onProceed: _showNextQuestion,
              ) :
              QuizResult(
                quiz: quiz,
                onRetry: _restart,
                onBack: _back,
              ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _storeAnswer(Question question) async {
    final userDb = Provider.of<UserDb>(context, listen: false);
    await userDb.insertQuestion(widget.profile.profileId, widget.course.courseId, question);
  }

  Future<void> _showNextQuestion() async {
    if (!quiz.isComplete) {
      setState(() {
        quiz.proceedToNextQuestion();
      });
      await _pageController.animateToPage(
          quiz.currentQuestionIndex,
          duration: Duration(milliseconds: 400),
          curve: Curves.ease);
    }
  }

  void _restart() {
    Navigator.of(context).pop(QuizPageResult(restart: true));
  }

  void _back() {
    Navigator.of(context).pop(QuizPageResult(restart: false));
  }

  Future<bool> _willPop() async {
    if (quiz.isComplete) {
      return true;
    } else {
      final strings = Strings.of(context);
      final abortQuiz = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(strings.abortQuizTitle),
          content: Text(strings.abortQuizContent),
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
        ),
      );
      return abortQuiz ?? false;
    }
  }
}

class QuestionScreen extends StatefulWidget {
  final Question question;
  final void Function(Question) onAnswer;
  final void Function() onProceed;

  QuestionScreen({Key key, @required this.question, this.onAnswer, this.onProceed}) :
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
    final questionScreen = Column(
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
                        if (settings.secondarySpeciesLanguage.value != LanguageSetting.none) Text(
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
      if (widget.onAnswer != null) {
        widget.onAnswer(_question);
      }
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

class QuizResult extends StatelessWidget {
  final Quiz quiz;
  final void Function() onRetry;
  final void Function() onBack;

  const QuizResult({Key key, this.quiz, this.onRetry, this.onBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
    final primarySpeciesLanguageCode = settings.primarySpeciesLanguage.value.resolve(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Text(
                      strings.quizScore,
                      style: theme.textTheme.headline4,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${quiz.scorePercent}%',
                      style: theme.textTheme.headline1.copyWith(fontSize: 92.0),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      strings.quizScoreDetails(quiz.correctAnswerCount, quiz.questionCount),
                      style: theme.textTheme.subtitle1,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (quiz.fullyCorrectSpecies.isNotEmpty) Container(
                color: Colors.green.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          AnswerIcon(correct: true),
                          SizedBox(width: 4.0),
                          Text(
                            strings.strongPoints,
                            style: theme.textTheme.headline6,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        quiz.fullyCorrectSpecies
                            .map((species) => species.commonNameIn(primarySpeciesLanguageCode))
                            .sorted()
                            .join(', '),
                      ),
                    ],
                  ),
                ),
              ),
              if (quiz.incorrectQuestions.isNotEmpty) Container(
                color: Colors.red.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          AnswerIcon(correct: false),
                          SizedBox(width: 4.0),
                          Text(
                            strings.weakPoints,
                            style: theme.textTheme.headline6,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.0),
                      for (final question in quiz.incorrectQuestions) Text(
                        strings.confusionText(
                            question.correctAnswer.commonNameIn(primarySpeciesLanguageCode),
                            question.givenAnswer.commonNameIn(primarySpeciesLanguageCode)),
                        style: theme.textTheme.bodyText2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: <Widget>[
              FlatButton(
                onPressed: onBack,
                child: Text(strings.backButton.toUpperCase()),
              ),
              Spacer(),
              RaisedButton(
                onPressed: onRetry,
                child: Text(strings.retryQuizButton.toUpperCase()),
              ),
            ],
          ),
        ),
      ],
    );
  }

}