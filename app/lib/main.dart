import 'dart:io';

import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';

import 'model.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var questionFactory = QuestionFactory();
    return MaterialApp(
      title: 'Papageno',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QuestionScreen(questionFactory.createQuestion()),
    );
  }
}

class _QuestionScreenState extends State<QuestionScreen> {

  Question get _question => widget._question;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TODO alternative layout for landscape orientation
      body: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16.0 / 9.0,
            child: Placeholder(),
          ),
          Player(_question.recording),
          ListView(
            padding: EdgeInsets.all(0),
            shrinkWrap: true,
            children: ListTile.divideTiles(
              context: context,
              tiles: _question.choices.map((species) {
                return ListTile(
                  title: Text(species.nameIn(Language.english).capitalize()),
                  onTap: () {
                    // TODO
                  },
                );
              }),
            ).toList(),
          ),
        ],
      ),
    );
  }
}

class QuestionScreen extends StatefulWidget {
  final Question _question;

  QuestionScreen(this._question);

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

  Recording get _recording => widget._recording;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.LOOP);
    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      setState(() { _state = state; });
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() { _duration = duration; });
    });
    _audioPlayer.onAudioPositionChanged.listen((Duration position) {
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

  @override
  void dispose() {
    _audioCache.clearCache();
    _audioPlayer.release();
    super.dispose();
  }
}

class Player extends StatefulWidget {
  final Recording _recording;

  Player(this._recording) :
    assert(_recording != null);

  @override
  _PlayerState createState() => _PlayerState();
}

extension Capitalize on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}