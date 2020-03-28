import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:audioplayers/audio_cache.dart';

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

enum Language {
  // scientific,
  english,
  // dutch,
}

class Species {
  final int id;
  final Map<Language, String> _names;

  Species(this.id, this._names) {
    assert(Language.values.every((language) => _names.containsKey(language)));
  }

  String nameIn(Language language) => _names[language];
}

class SpeciesDb {
  final _species = HashMap<int, Species>();

  SpeciesDb() {
    for (final species in [
      Species(1, {Language.english: 'great tit'}),
      Species(2, {Language.english: 'common chaffinch'}),
      Species(3, {Language.english: 'common blackbird'}),
      Species(4, {Language.english: 'common chiffchaff'}),
      Species(5, {Language.english: 'European robin'}),
      Species(6, {Language.english: 'willow warbler'}),
      Species(7, {Language.english: 'Eurasian blue tit'}),
      Species(8, {Language.english: 'Eurasian blackcap'}),
      Species(9, {Language.english: 'red crossbill'}),
      Species(10, {Language.english: 'song thrush'}),
    ]) {
      _addSpecies(species);
    }
  }

  List<int> get ids => _species.keys.toList();

  Species species(int id) => _species[id];

  void _addSpecies(Species species) {
    assert(!_species.containsKey(species.id));
    _species[species.id] = species;
  }
}

class Recording {
  final Species species;
  final String fileName;

  Recording(this.species, this.fileName);
}

class Question {
  final Recording recording;
  final List<Species> choices;

  Question(this.recording, this.choices) {
    assert(recording != null);
    assert(choices.isNotEmpty);
    assert(choices.contains(answer));
  }

  Species get answer => recording.species;
}

class QuestionFactory {
  final _random = Random();
  final _answerCount = 4;
  final _speciesDb = SpeciesDb();

  Question createQuestion() {
    var ids = _speciesDb.ids;
    assert(ids.length >= _answerCount);
    var choices = <Species>[];
    for (var i = 0; i < _answerCount; i++) {
      var index = _random.nextInt(ids.length);
      choices.add(_speciesDb.species(ids[index]));
      ids[index] = ids.last;
      ids.removeLast();
    }
    var answer = choices[_random.nextInt(choices.length)];
    return Question(Recording(answer, 'recordings/cuckoo.mp3'), choices);
  }
}

class QuestionWidget extends StatefulWidget {
  final Question _question;

  QuestionWidget(this._question);

  @override
  _QuestionWidgetState createState() => _QuestionWidgetState(_question);
}

class _QuestionWidgetState extends State<QuestionWidget> {
  final Question _question;

  _QuestionWidgetState(this._question);

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