import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:papageno/ebisu/ebisu.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';

final _log = Logger('user_model');

@immutable
class RankedSpecies {
  final LatLon location;
  // Suffix "List" used for clarity because "species" is both singular and plural.
  final BuiltList<Species> speciesList;
  final double usedRadiusKm;

  RankedSpecies(this.location, this.speciesList, this.usedRadiusKm);

  int get length => speciesList.length;
}

/// A [Profile] represents a single user of the app.
/// Pretty much all other data (courses, settings, ...) is scoped to a single profile.
class Profile {
  final int profileId;
  final String name;
  /// Unix timestamp when the profile was last accessed; 0 if never set.
  int lastUsedTimestampMs;
  /// Caution: may be `null` if not loaded.
  Settings settings;

  Profile(this.profileId, this.name, this.lastUsedTimestampMs);

  /// Returns the time (in the local time zone) when the profile was last used, or `null` if unused.
  DateTime get lastUsed => lastUsedTimestampMs <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(lastUsedTimestampMs);

  Profile.fromMap(Map<String, dynamic> map) :
      profileId = map['profile_id'] as int,
      name = map['name'] as String,
      lastUsedTimestampMs = (map['last_used_timestamp_ms'] ?? 0) as int;
}

class Course {
  int courseId;
  final int profileId;
  final LatLon location;
  final List<Species> unlockedSpecies;
  final List<Species> lockedSpecies;

  Course({this.courseId, this.profileId, this.location, this.unlockedSpecies, this.lockedSpecies});

  int get speciesCount => unlockedSpecies.length + lockedSpecies.length;
}

class Quiz {
  final BuiltList<Question> questions;

  Quiz(this.questions);

  int get questionCount => questions.length;

  bool get isComplete => !questions.any((q) => !q.isAnswered);

  /// Returns the index (0-based) of the first question that has not been answered yet.
  /// If all questions have been answered, returns [questionCount].
  int get firstUnansweredQuestionIndex {
    final index = questions.indexWhere((question) => !question.isAnswered);
    return index >= 0 ? index : questionCount;
  }

  int get correctAnswerCount => questions.where((question) => question.isCorrect == true).length;

  int get scorePercent => correctAnswerCount * 100 ~/ questionCount;

  Set<Species> get fullyCorrectSpecies =>
  questions
      .map((question) => question.correctAnswer)
      .toSet()
    ..removeAll(incorrectQuestions.map((question) => question.correctAnswer))
    ..removeAll(incorrectQuestions.map((question) => question.givenAnswer));

  List<Question> get correctQuestions => questions.where((question) => question.isCorrect == true).toList();
  List<Question> get incorrectQuestions => questions.where((question) => question.isCorrect == false).toList();
}

class Question {
  final Recording recording;
  final List<Species> choices;
  final Species correctAnswer;

  DateTime _answerTimestamp;
  Species _givenAnswer;

  Question(this.recording, this.choices, this.correctAnswer) :
        assert(recording != null),
        assert(choices.isNotEmpty),
        assert(choices.contains(correctAnswer));

  bool get isAnswered => _givenAnswer != null;

  bool get isCorrect => isAnswered ? _givenAnswer == correctAnswer : null;

  Species get givenAnswer => _givenAnswer;

  DateTime get answerTimestamp => _answerTimestamp;

  void answerWith(Species answer, [DateTime answerTimestamp]) {
    assert(_givenAnswer == null);
    assert(answer != null);
    _givenAnswer = answer;
    _answerTimestamp = answerTimestamp ?? DateTime.now();
  }

  @override
  String toString() => 'Question(correctAnswer: $correctAnswer, givenAnswer: $givenAnswer)';
}

/// Represents how much the user knows about each species.
@immutable
class Knowledge {
  final Map<Species, SpeciesKnowledge> _ofSpecies;

  Knowledge(this._ofSpecies);

  SpeciesKnowledge ofSpecies(Species species) {
    return _ofSpecies[species];
  }

  @override
  String toString() => _ofSpecies.toString();
}

@immutable
class SpeciesKnowledge {
  static const _minutesPerDay = 60.0 * 24.0;
  static const _millisecondsPerDay = 1000.0 * 60.0 * 60.0 * 24.0;
  
  static const _initialHalflifeDays = 10.0 / _minutesPerDay;
  static const _initialAlpha = 3.0;

  /// The underlying Ebisu model. Time is in days.
  final EbisuModel _model;
  final int _lastAskedTimestampMs;

  SpeciesKnowledge.initial(DateTime creationTimestamp) :
      _model = EbisuModel(time: _initialHalflifeDays, alpha: _initialAlpha),
      _lastAskedTimestampMs = creationTimestamp.millisecondsSinceEpoch;

  SpeciesKnowledge.fromMap(Map<String, dynamic> map) :
      _model = EbisuModel(
        time: map['ebisu_time'] as double,
        alpha: map['ebisu_alpha'] as double,
        beta: map['ebisu_beta'] as double,
      ),
      _lastAskedTimestampMs = map['last_asked_timestamp_ms'] as int;
  
  SpeciesKnowledge._internal(this._model, this._lastAskedTimestampMs);

  /// Returns the estimated halflife (time to forget) for this species in days.
  double get halflifeDays => _model.modelToPercentileDecay(percentile: 0.5);

  /// Returns how many half stars (out of 5 whole stars, i.e. 10 half stars) this species gets.
  /// The first half star is earned at a halflife is 1 hour; each next half star takes twice as much
  /// as the previous one.
  int get halfStars => max(0, min((log(halflifeDays * 24.0) / log(2.0) + 1).floor(), 10));

  EbisuModel get ebisuModel => _model;

  /// Returns the probability between 0 and 1 that the species is remembered at this moment.
  double recallProbability(DateTime now) => _model.predictRecall(_daysSinceAsked(now), exact: true);

  /// Returns a number that represents how important it is to ask about this species now (greater is higher priority).
  /// The number is not meaningful by itself, only in comparisons.
  double priority(DateTime now) => -_model.predictRecall(_daysSinceAsked(now));
  
  SpeciesKnowledge update({@required bool correct, DateTime answerTimestamp}) {
    answerTimestamp ??= DateTime.now();
    var newModel = _model;
    try {
      newModel = _model.updateRecall(correct ? 1 : 0, 1, _daysSinceAsked(answerTimestamp));
    } catch (ex) {
      _log.warning('Failed to update Ebishu model', ex);
    }
    return SpeciesKnowledge._internal(newModel, answerTimestamp.millisecondsSinceEpoch);
  }

  double _daysSinceAsked(DateTime now) => (now.millisecondsSinceEpoch - _lastAskedTimestampMs) / _millisecondsPerDay;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'ebisu_time': _model.time,
    'ebisu_alpha': _model.alpha,
    'ebisu_beta': _model.beta,
    'last_asked_timestamp_ms': _lastAskedTimestampMs,
  };

  @override
  String toString() => '$_model @ ${DateTime.fromMillisecondsSinceEpoch(_lastAskedTimestampMs).toIso8601String()}';
}