import 'dart:async';

import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';

import 'model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papageno',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QuizScreen(),
    );
  }
}

class _QuizScreenState extends State<QuizScreen> {

  final _questionFactory = QuestionFactory();
  Question _currentQuestion;
  int _currentQuestionIndex = 0;
  final int _totalQuestionCount = 20;

  @override
  void initState() {
    super.initState();
    _showNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentQuestionIndex} of ${_totalQuestionCount}'),
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
    setState(() {
      _currentQuestionIndex++;
      _currentQuestion = _questionFactory.createQuestion();
    });
  }
}

class QuizScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _QuizScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {

  Question get _question => widget.question;
  Species _choice;

  @override
  Widget build(BuildContext context) {
    var instructions = '';
    if (_choice != null) {
      if (_question.isCorrect(_choice)) {
        instructions = 'Right answer! Tap to continue';
      } else {
        instructions = 'Wrong answer… Tap to continue';
      }
    }
    // TODO alternative layout for landscape orientation
    var questionScreen = Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              Placeholder(),
              Visibility(
                visible: _choice == null,
                child: Positioned.fill(
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
              ),
            ],
          ),
        ),
        Player(
          key: GlobalObjectKey(_question.recording),
          recording: _question.recording,
        ),
        for (var widget in ListTile.divideTiles(
          context: context,
          tiles: _question.choices.map(_buildChoice),
        )) widget,
        Divider(height: 0.0),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(
            child: Opacity(
              opacity: _choice == null ? 0.0 : 1.0,
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
      color: color,
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

class QuestionScreen extends StatefulWidget {
  final Question question;
  final Function() onProceed;

  QuestionScreen({Key key, @required this.question, this.onProceed}) :
      assert(question != null),
      super(key: key);

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
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
    return Ink(
      color: Colors.blue.shade50, // TODO take from theme
      child: Row(
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
      ),
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