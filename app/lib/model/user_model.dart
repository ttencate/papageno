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
  final List<Species> localSpecies;
  final List<Species> unlockedSpecies;

  Course({this.courseId, this.profileId, this.location, this.localSpecies, this.unlockedSpecies});
}

enum AfterQuizOption {
  /// Stop now.
  stop,
  /// Try the same quiz again.
  retry,
  /// Stop and add more species.
  addSpecies,
}

enum AfterQuizRecommendation {
  /// Results aren't great yet, but there has been enough practice for now.
  stop,
  /// Results not great but should improve if tried again.
  strongRetry,
  /// Results not great, but good enough to add some birds if really wanted.
  weakRetry,
  /// Results are great, more species should be added.
  addSpecies,
}

@immutable
class Quiz {
  /// The total number of questions in this [Quiz].
  final int questionCount;
  
  /// The questions that are currently available.
  /// Caution: may be shorter than [questionCount] because not all questions may have been generated yet.
  /// Questions that are missing from this list are implicitly unanswered.
  final BuiltList<Question> availableQuestions;

  Quiz(this.questionCount, this.availableQuestions);

  bool get isComplete => availableQuestions.length == questionCount && !availableQuestions.any((q) => !q.isAnswered);

  /// Returns the index (0-based) of the first question that has not been answered yet.
  /// If all questions have been answered, returns [questionCount].
  int get firstUnansweredQuestionIndex {
    final index = availableQuestions.indexWhere((question) => !question.isAnswered);
    return index >= 0 ? index : availableQuestions.length;
  }

  int get correctAnswerCount => availableQuestions.where((question) => question.isCorrect == true).length;

  int get scorePercent => correctAnswerCount * 100 ~/ questionCount;

  Set<Species> get alwaysCorrectSpecies =>
      availableQuestions
          .map((question) => question.correctAnswer)
          .toSet()
          ..removeAll(incorrectQuestions.map((question) => question.correctAnswer))
          ..removeAll(incorrectQuestions.map((question) => question.givenAnswer));

  Set<Species> get sometimesIncorrectSpecies =>
      incorrectQuestions.map((question) => question.correctAnswer)
          .toSet()
          ..addAll(incorrectQuestions.map((question) => question.givenAnswer));
  
  List<Question> get correctQuestions => availableQuestions.where((question) => question.isCorrect == true).toList();
  List<Question> get incorrectQuestions => availableQuestions.where((question) => question.isCorrect == false).toList();

  AfterQuizRecommendation get recommendation {
    // TODO recommend stop if the worst recallProbability is still fairly large (say >50%)
    final score = scorePercent;
    if (score < 60) {
      return AfterQuizRecommendation.strongRetry;
    } else if (score < 80) {
      return AfterQuizRecommendation.weakRetry;
    } else {
      return AfterQuizRecommendation.addSpecies;
    }
  }
}

@immutable
class Question {
  final Recording recording;
  final List<Species> choices;
  final Species correctAnswer;

  final Species givenAnswer;
  final DateTime answerTimestamp;

  Question({@required this.recording, @required this.choices, @required this.correctAnswer, this.givenAnswer, this.answerTimestamp}) :
        assert(recording != null),
        assert(choices.isNotEmpty),
        assert(choices.contains(correctAnswer));

  bool get isAnswered => givenAnswer != null;

  bool get isCorrect => isAnswered ? givenAnswer == correctAnswer : null;

  Question answeredWith(Species givenAnswer, [DateTime answerTimestamp]) {
    assert(this.givenAnswer == null);
    assert(givenAnswer != null);
    answerTimestamp = answerTimestamp ?? DateTime.now();
    return Question(recording: recording, choices: choices, correctAnswer: correctAnswer, givenAnswer: givenAnswer, answerTimestamp: answerTimestamp);
  }

  @override
  String toString() => 'Question(correctAnswer: $correctAnswer, givenAnswer: $givenAnswer, isCorrect: $isCorrect)';
}

/// Represents how much the user knows about each species.
@immutable
class Knowledge {
  final BuiltMap<Species, SpeciesKnowledge> _ofSpecies;

  Knowledge(this._ofSpecies);

  Knowledge.none() : this(<Species, SpeciesKnowledge>{}.build());

  SpeciesKnowledge ofSpecies(Species species) {
    return _ofSpecies[species] ?? SpeciesKnowledge.none();
  }

  Knowledge updated(Species species, SpeciesKnowledge speciesKnowledge) {
    final builder = _ofSpecies.toBuilder();
    builder[species] = speciesKnowledge;
    return Knowledge(builder.build());
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

  // The first half star is easy to get by just improving very slightly on the initial halflife.
  // The remaining 9 half stars at this rate require a halflife of about 30 days.
  // That is still no guarantee for great recall a year later, but the halflife won't be extended to that duration
  // until the user has actually used the app for that much time (and then some), which would be demoralizing.
  static const _firstHalfStarAtDays = _initialHalflifeDays * 1.1;
  static const _halfStarExponent = 2.5;
  static const maxStarCount = 5;
  static const maxHalfStarCount = 2 * maxStarCount;

  /// The underlying Ebisu model. Time is in days.
  /// This is `null` if the species has never been encountered before.
  final EbisuModel model;

  /// When the species was last quizzed on.
  /// This is 0 if and only if [model] is `null`.
  final int _lastAskedTimestampMs;

  SpeciesKnowledge.none() :
      model = null,
      _lastAskedTimestampMs = 0;

  SpeciesKnowledge.fromMap(Map<String, dynamic> map) :
      model = EbisuModel(
        time: map['ebisu_time'] as double,
        alpha: map['ebisu_alpha'] as double,
        beta: map['ebisu_beta'] as double,
      ),
      _lastAskedTimestampMs = map['last_asked_timestamp_ms'] as int;
  
  SpeciesKnowledge._internal(this.model, this._lastAskedTimestampMs);

  /// Returns the estimated halflife (time to forget) for this species in days.
  double get halflifeDays => model?.modelToPercentileDecay(percentile: 0.5) ?? 0.0;

  /// Returns how many half stars (out of 5 whole stars, i.e. 10 half stars) this species gets.
  /// The first half star is earned at a particular halflife;
  /// each next half star takes a particular factor as much as the previous one.
  int get halfStars =>
      halflifeDays <= 0 ?
      0 :
      max(0, min((log(halflifeDays / _firstHalfStarAtDays) / log(_halfStarExponent) + 1).floor(), maxHalfStarCount));

  /// Returns the probability between 0 and 1 that the species is remembered at this moment.
  double recallProbability(DateTime now) => model?.predictRecall(daysSinceAsked(now), exact: true) ?? 0.0;

  /// Returns a number that represents how important it is to ask about this species now (greater is higher priority).
  /// The number is not meaningful by itself, only in comparisons.
  double priority(DateTime now) => -(model?.predictRecall(daysSinceAsked(now)) ?? double.negativeInfinity);
  
  SpeciesKnowledge update({@required bool correct, DateTime answerTimestamp}) {
    answerTimestamp ??= DateTime.now();
    EbisuModel newModel;
    if (model == null) {
      newModel = EbisuModel(time: _initialHalflifeDays, alpha: _initialAlpha);
    } else {
      try {
        newModel = model.updateRecall(correct ? 1 : 0, 1, daysSinceAsked(answerTimestamp));
      } catch (ex) {
        _log.warning('Failed to update Ebishu model', ex);
      }
    }
    return SpeciesKnowledge._internal(newModel, answerTimestamp.millisecondsSinceEpoch);
  }

  double daysSinceAsked(DateTime now) => max(0.0, (now.millisecondsSinceEpoch - _lastAskedTimestampMs) / _millisecondsPerDay);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'ebisu_time': model.time,
    'ebisu_alpha': model.alpha,
    'ebisu_beta': model.beta,
    'last_asked_timestamp_ms': _lastAskedTimestampMs,
  };

  @override
  String toString() => '$model @ ${DateTime.fromMillisecondsSinceEpoch(_lastAskedTimestampMs).toIso8601String()}';
}