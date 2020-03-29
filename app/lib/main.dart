import 'package:flutter/material.dart';

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
      home: QuestionWidget(questionFactory.createQuestion()),
    );
  }
}

class QuestionWidget extends StatelessWidget {
  final Question _question;

  QuestionWidget(this._question);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TODO horizontal layout
      body: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16.0/9.0,
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

class _PlayerState extends State<Player> {
  final Recording _recording;

  final _audioCache = AudioCache();

  _PlayerState(this._recording);

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: Colors.blue.shade50, // TODO take from theme
      child: Row(
          children: <Widget>[
            Expanded(
              child: Slider(
                value: 0.0,
                min: 0.0,
                max: 0.0, // TODO get from AudioPlayer (but it's async)
                onChanged: (double value) {
                  // TODO
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow),
              color: Colors.blue, // TODO take from theme
              iconSize: 48.0,
              onPressed: () {
                _audioCache.play(_recording.fileName);
              },
            ),
          ]
      ),
    );
  }
}

class Player extends StatefulWidget {
  final Recording _recording;

  Player(this._recording);

  @override
  _PlayerState createState() => _PlayerState(_recording);
}

extension Capitalize on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}