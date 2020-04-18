import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'appdb.dart';
import 'localization.dart';
import 'model.dart';
import 'revealing_image.dart';
import 'strings.dart';

void main() {
  runApp(App());
}

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AppState();
}

class AppState extends State<App> {
  Future<AppDb> _appDb;

  @override
  void initState() {
    super.initState();
    _appDb = AppDb.open();
  }

  @override
  Widget build(BuildContext context) {
    final inheritanceDelegate = InheritanceDelegate({
      Locale('en'): Strings_en(),
      Locale('nl'): Strings_nl(),
    });
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => Strings.of(context).appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<AppDb>(
        future: _appDb,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Provider<AppDb>.value(
              value: snapshot.data,
              child: CourseScreen(),
            );
          } else if (snapshot.hasError) {
            return ErrorScreen('Error loading app database', snapshot.error);
          } else {
            // TODO show splash screen instead
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      localizationsDelegates: [
        inheritanceDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: inheritanceDelegate.supportedLocales,
    );
  }
}

// TODO only for development; stop using this
class ErrorScreen extends StatelessWidget {

  final String message;
  final dynamic exception;

  const ErrorScreen(this.message, this.exception) : super();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('${message}\n${exception}')
      ),
    );
  }
}

class CourseScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appDb = Provider.of<AppDb>(context);
    final quiz = Quiz(appDb);
    return FutureBuilder<Question>(
      future: quiz.getNextQuestion(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return QuizScreen(quiz);
        } else if (snapshot.hasError) {
          return ErrorScreen('Error creating question', snapshot.error);
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

class QuizScreen extends StatefulWidget {

  QuizScreen(this.quiz);

  final Quiz quiz;

  @override
  State<StatefulWidget> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {

  Future<Question> _currentQuestion;

  @override
  void initState() {
    super.initState();
    _currentQuestion = widget.quiz.getNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.of(context).questionIndex(widget.quiz.currentQuestionIndex + 1, widget.quiz.totalQuestionCount)),
        // TODO show some sort of progress bar
      ),
      body: FutureBuilder<Question>(
        future: _currentQuestion,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return QuestionScreen(
                key: ObjectKey(snapshot.data),
                question: snapshot.data,
                onProceed: _showNextQuestion
            );
          } else {
            return Container();
          }
        },
      ),
    );
  }

  void _showNextQuestion() {
    // TODO this only slides the new question in; also slide the old one out
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => QuizScreen(widget.quiz),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(begin: Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          textDirection: Directionality.of(context),
          child: child,
        );
      },
    );
    Navigator.of(context).pushReplacement(route);
  }
}

class DelayedCurve extends Curve {
  const DelayedCurve({this.delay, this.inner}) :
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
              curve: DelayedCurve(delay: 0.5, inner: Curves.easeInOut),
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

class _PlayerState extends State<Player> {
  AudioPlayer _audioPlayer;
  AudioCache _audioCache;
  bool _loaded = false;
  AudioPlayerState _state = AudioPlayerState.STOPPED;
  Duration _duration = Duration();
  Duration _position = Duration();
  StreamSubscription<AudioPlayerState> _playerStateSubscription;
  StreamSubscription<Duration> _durationSubscription;
  StreamSubscription<Duration> _audioPositionSubscription;

  Recording get _recording => widget.recording;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.LOOP);
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      setState(() { _state = state; });
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() { _duration = duration; });
    });
    _audioPositionSubscription = _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      setState(() { _position = position; });
    });

    _audioCache = AudioCache(fixedPlayer: _audioPlayer);
    _audioCache.play(_recording.fileName).then((_) {
      setState(() {
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _audioCache.clearCache();

    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _audioPositionSubscription.cancel();
    _audioPlayer.release();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Slider(
            min: 0.0,
            max: _duration.inMilliseconds.toDouble(),
            value: _position.inMilliseconds.toDouble(),
            onChanged: _loaded ? _seek : null,
          ),
        ),
        IconButton(
          icon: Icon(_state == AudioPlayerState.PLAYING ? Icons.pause : Icons.play_arrow),
          color: Colors.blue, // TODO take from theme
          iconSize: 48.0,
          onPressed: _loaded ? _togglePlaying : null,
        ),
      ]
    );
  }

  void _togglePlaying() {
    if (_state != AudioPlayerState.PLAYING) {
      _audioPlayer.resume();
    } else {
      _audioPlayer.pause();
    }
  }

  void _seek(double position) {
    _audioPlayer.seek(Duration(milliseconds: position.toInt()));
  }
}

class Player extends StatefulWidget {
  final Recording recording;

  Player({Key key, @required this.recording}) :
    assert(recording != null),
    super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

extension Capitalize on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}