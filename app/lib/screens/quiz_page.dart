import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:logging/logging.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/controller/knowledge_controller.dart';
import 'package:papageno/controller/quiz_controller.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/app_model.dart' as model show Image; // Avoid conflict with Flutter's Image class.
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/attribution_dialog.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/iterable_utils.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:papageno/widgets/player.dart';
import 'package:papageno/widgets/revealing_image.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';

final _log = Logger('QuizPage');

class QuizPage extends StatefulWidget {
  final Profile profile;
  final KnowledgeController knowledgeController;
  final Course course;

  QuizPage(this.profile, this.knowledgeController, this.course);

  @override
  State<StatefulWidget> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {

  QuizController _controller;
  PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _log.finer('Creating _QuizPageState');
    final appDb = Provider.of<AppDb>(context, listen: false);
    final userDb = Provider.of<UserDb>(context, listen: false);
    _controller = QuizController(appDb, userDb, widget.knowledgeController, widget.course);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _log.finer('Disposing _QuizPageState');
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Settings>.value(
      value: widget.profile.settings,
      child: StreamBuilder<Quiz>(
        stream: _controller.quizUpdates,
        builder: (context, snapshot) {
          final quiz = snapshot.data;
          final theme = Theme.of(context);
          final drawer = MenuDrawer(profile: widget.profile, course: widget.course);
          if (quiz == null) {
            return Scaffold(
              appBar: AppBar(),
              drawer: drawer,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return WillPopScope(
            onWillPop: quiz.isComplete ? null : _confirmPop,
            // Keep the system's status bar green, because having it transparent on top of the photo is too visually noisy.
            child: Container(
              color: theme.primaryColor,
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) { setState(() { _currentPage = index; }); },
                        scrollDirection: Axis.horizontal,
                        physics: PageScrollPhysics(),
                        // We don't pass `itemCount` because if we set it to `quiz.questionCount + 1`,
                        // the `PageView` sometimes creates pages before they are visible, causing
                        // https://github.com/ttencate/papageno/issues/58.
                        // If we fix this by setting `itemCount` to `quiz.firstUnansweredQuestionIndex + 1`, then
                        // each `_QuestionScreenState`s gets rebuilt twice for some reason I don't understand
                        // (shouldn't keys prevent this?).
                        itemCount: null,
                        itemBuilder: (BuildContext context, int index) {
                          if (index > quiz.firstUnansweredQuestionIndex) {
                            return null;
                          }
                          if (index < quiz.questionCount) {
                            if (index >= quiz.availableQuestions.length) {
                              return Center(child: CircularProgressIndicator());
                            } else {
                              final question = quiz.availableQuestions[index];
                              return QuestionScreen(
                                key: ObjectKey(index),
                                drawer: drawer,
                                question: question,
                                onAnswer: (givenAnswer) { _answerQuestion(index, givenAnswer); },
                                onProceed: () { _showNextQuestion(quiz); },
                              );
                            }
                          } else {
                            return QuizResult(
                              quiz: quiz,
                              drawer: drawer,
                              onRetry: () { Navigator.of(context).pop(AfterQuizOption.retry); },
                              onBack: () { Navigator.of(context).pop(AfterQuizOption.stop); },
                              onAddSpecies: () { Navigator.of(context).pop(AfterQuizOption.addSpecies); },
                            );
                          }
                        },
                      ),
                    ),
                    if (_currentPage < quiz.questionCount) LinearProgressIndicator(
                      value: quiz.firstUnansweredQuestionIndex / quiz.questionCount,
                      valueColor: AlwaysStoppedAnimation(theme.primaryColorDark),
                      backgroundColor: theme.backgroundColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _answerQuestion(int questionIndex, Species givenAnswer) {
    _log.finer('Answering question $questionIndex with $givenAnswer');
    _controller.answerQuestion(questionIndex, givenAnswer, DateTime.now());
  }

  Future<void> _showNextQuestion(Quiz quiz) async {
    _log.finer('_QuizScreenState._showNextQuestion() isComplete: ${quiz.isComplete}');
    final targetPage = quiz.isComplete ? quiz.questionCount : quiz.firstUnansweredQuestionIndex;
    _log.finer('Animating to page ${targetPage}');
    await _pageController.animateToPage(
        targetPage,
        duration: Duration(milliseconds: 400),
        curve: Curves.ease);
  }

  Future<bool> _confirmPop() async {
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

class QuestionScreen extends StatefulWidget {
  final Question question;
  final Widget drawer;
  final void Function(Species) onAnswer;
  final void Function() onProceed;

  QuestionScreen({Key key, @required this.question, @required this.drawer, this.onAnswer, this.onProceed}) :
        assert(question != null),
        super(key: key);

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {

  Question get _question => widget.question;
  model.Image _image;
  PlayerController _playerController;

  @override
  void initState() {
    _log.finer('_QuestionScreenState.initState() for $_question');
    super.initState();
    _playerController = PlayerController(
      audioFile: 'assets/sounds/${_question.recording.fileName}',
      playing: !_question.isAnswered,
      looping: !_question.isAnswered,
      pauseWhenLosingFocus: true,
    );
  }

  @override
  void didChangeDependencies() {
    _log.finer('_QuestionScreenState.didChangeDependencies() for $_question');
    super.didChangeDependencies();
    final appDb = Provider.of<AppDb>(context);
    appDb.imageForOrNull(_question.correctAnswer).then((image) {
      if (mounted && image != null) {
        setState(() { _image = image; });
      }
    });
  }

  @override
  void dispose() {
    _log.finer('_QuestionScreenState.dispose() for $_question');
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.window.locale;
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final textOnImageColor = Colors.white;
    final textOnImageShadows = <Shadow>[
      Shadow(blurRadius: 3.0),
      Shadow(blurRadius: 6.0),
    ];
    final settings = Provider.of<Settings>(context);
    // TODO alternative layout for landscape orientation
    return GestureDetector(
      onTap: _question.isAnswered ? widget.onProceed : null,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0.0, // Prevents shadow.
          actions: <Widget>[
            if (_question.isAnswered) IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: _showAttribution,
            ),
          ],
        ),
        drawer: widget.drawer,
        body: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  RevealingImage(
                    image: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (_image == null) Container(),
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
                            // color: Colors.black.withOpacity(0.2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.5)],
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                    revealed: _question.isAnswered,
                  ),
                  Positioned(
                    right: 16.0,
                    bottom: 16.0,
                    child: FloatingPlayPauseButton(
                      controller: _playerController,
                    ),
                  ),
                ],
              ),
            ),
            PlaybackProgress(
              controller: _playerController,
            ),
            // SizedBox(height: 6.0), // Matches LinearProgressIndicator.
            Divider(height: 0.0),
            for (var widget in ListTile.divideTiles(
              context: context,
              tiles: _question.choices.map(_buildChoice),
            )) widget,
            Divider(height: 0.0),
            SizedBox(
              height: 48.0, // ListTile in non-dense mode: 56.0; dense: 48.0
              child: Center(
                child: AnimatedOpacity(
                  opacity: _question.isAnswered ? 1.0 : 0.0,
                  duration: Duration(seconds: 3),
                  // TODO DelayedCurve is just a quick and dirty way to delay the start of the animation, but I'm sure there's a better way.
                  curve: _DelayedCurve(delay: 0.5, inner: Curves.easeInOut),
                  child: Text(
                    // TODO see if screen readers do the right thing if we just leave the text here always
                    _question.isAnswered ? strings.tapInstructions : '',
                    textScaleFactor: 1.25,
                    style: theme.textTheme.caption,
                  ),
                )
              ),
            )
          ],
        ),
      ),
    );
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
        title: Text(
          species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
          textScaleFactor: 1.25,
        ),
        trailing: icon,
        onTap: _question.isAnswered ? null : () { _choose(species); },
      ),
    );
  }

  void _choose(Species givenAnswer) {
    _log.finer('_QuestionScreenState._choose($givenAnswer) for $_question');
    if (!_question.isAnswered) {
      _playerController.looping = false;
      if (widget.onAnswer != null) {
        widget.onAnswer(givenAnswer);
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
  final Widget drawer;
  final void Function() onRetry;
  final void Function() onBack;
  final void Function() onAddSpecies;

  const QuizResult({Key key, @required this.quiz, @required this.drawer, @required this.onRetry, @required this.onBack, @required this.onAddSpecies}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
    final primarySpeciesLanguageCode = settings.primarySpeciesLanguage.value.resolve(locale);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.quizResultsTitle),
      ),
      drawer: drawer,
      body: Column(
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
                        style: theme.textTheme.headline5,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${quiz.scorePercent}%',
                        style: theme.textTheme.headline1.copyWith(fontSize: 92.0),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (quiz.alwaysCorrectSpecies.isNotEmpty) Container(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        AnswerIcon(correct: true),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            quiz.alwaysCorrectSpecies
                                .map((species) => species.commonNameIn(primarySpeciesLanguageCode))
                                .sorted()
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (quiz.sometimesIncorrectSpecies.isNotEmpty) Container(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        AnswerIcon(correct: false),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            quiz.sometimesIncorrectSpecies
                                .map((species) => species.commonNameIn(primarySpeciesLanguageCode))
                                .sorted()
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _recommendationActions(quiz.recommendation, strings),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _recommendationActions(AfterQuizRecommendation recommendation, Strings strings) {
    Widget raisedButton(void Function() onPressed, String text) {
      return RaisedButton(onPressed: onPressed, child: Text(text.toUpperCase()));
    }
    Widget flatButton(void Function() onPressed, String text) {
      return FlatButton(onPressed: onPressed, child: Text(text.toUpperCase()));
    }
    switch (recommendation) {
      case AfterQuizRecommendation.stop:
        return <Widget>[
          Text(strings.recommendStop),
          SizedBox(height: 8.0),
          flatButton(onRetry, strings.retryQuizButton),
          raisedButton(onBack, strings.backButton),
        ];
      case AfterQuizRecommendation.strongRetry:
        return <Widget>[
          Text(strings.recommendRetry),
          SizedBox(height: 8.0),
          raisedButton(onRetry, strings.retryQuizButton),
          flatButton(onBack, strings.backButton),
        ];
      case AfterQuizRecommendation.weakRetry:
        return <Widget>[
          Text(strings.recommendRetry),
          SizedBox(height: 8.0),
          raisedButton(onRetry, strings.retryQuizButton),
          flatButton(onAddSpecies, strings.addSpeciesButton),
          flatButton(onBack, strings.backButton),
        ];
      case AfterQuizRecommendation.addSpecies:
        return <Widget>[
          Text(strings.recommendAddSpecies),
          SizedBox(height: 8.0),
          raisedButton(onAddSpecies, strings.addSpeciesButton),
          flatButton(onRetry, strings.retryQuizButton),
          flatButton(onBack, strings.backButton),
        ];
    }
    assert(false);
    return <Widget>[];
  }
}