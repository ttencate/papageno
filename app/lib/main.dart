import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization.dart';
import 'model.dart';
import 'strings.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
      home: QuizScreen(QuestionFactory(), 20),
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

class QuizScreen extends StatefulWidget {

  QuizScreen(this.questionFactory, this.totalQuestionCount, [this.currentQuestionIndex = 1]);

  final questionFactory;
  final int totalQuestionCount;
  final int currentQuestionIndex;

  @override
  State<StatefulWidget> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {

  Question _currentQuestion;

  @override
  void initState() {
    super.initState();
    _currentQuestion = widget.questionFactory.createQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.of(context).questionIndex(widget.currentQuestionIndex, widget.totalQuestionCount)),
        // TODO show some sort of progress bar
      ),
      body: QuestionScreen(
        key: ObjectKey(_currentQuestion),
        question: _currentQuestion,
        onProceed: _showNextQuestion
      ),
    );
  }

  void _showNextQuestion() {
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => QuizScreen(widget.questionFactory, widget.totalQuestionCount, widget.currentQuestionIndex + 1),
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

class CircleClipper extends CustomClipper<Rect> {
  const CircleClipper({Listenable reclip, this.fraction = 1.0}) :
      super(reclip: reclip);

  final double fraction;

  @override
  Rect getApproximateClipRect(Size size) {
    return getClip(size);
  }

  @override
  Rect getClip(Size size) {
    final diameter = fraction * sqrt(size.width * size.width + size.height * size.height);
    return Rect.fromCenter(center: size.center(Offset.zero), width: diameter, height: diameter);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return oldClipper.runtimeType == CircleClipper ? (oldClipper as CircleClipper).fraction != fraction : true;
  }
}

class RevealingImage extends StatefulWidget {
  RevealingImage({@required this.image, this.revealed = true}) :
      assert(image != null);

  final ImageProvider image;
  final bool revealed;

  @override
  State<StatefulWidget> createState() => _RevealingImageState();
}

class _RevealingImageState extends State<RevealingImage> with SingleTickerProviderStateMixin {
  AnimationController controller;
  Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(controller);
    // TODO figure out why we need this -- CustomClipper.reclip is tied to this animation so it should be updating outside the build cycle, right?
    animation.addListener(() { setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.revealed) {
      controller.forward();
    } else {
      controller.reverse();
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            color: Colors.grey.shade200,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.all(2.0),
                child: Text(
                  '?',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ClipOval(
            clipper: CircleClipper(
              fraction: animation.value,
              reclip: animation,
            ),
            // Supposed to be faster than antiAlias, and during animation the
            // difference is invisible anyway.
            clipBehavior: Clip.hardEdge,
            child: Image(
              image: widget.image,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
        title: Text(species.nameIn(Language.dutch).capitalize()),
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