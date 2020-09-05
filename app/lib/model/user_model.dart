import 'dart:math';
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:ebisu_dart/ebisu.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/utils/built_list_utils.dart';

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
  final String name;
  final List<Species> localSpecies;
  final List<Species> unlockedSpecies;

  Course({this.courseId, this.profileId, this.location, this.name, this.localSpecies, this.unlockedSpecies});
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
    if (score < 80) {
      return AfterQuizRecommendation.strongRetry;
    } else if (score < 90) {
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

  SpeciesKnowledge ofSpeciesOrNone(Species species) {
    return _ofSpecies[species] ?? SpeciesKnowledge.none();
  }

  SpeciesKnowledge ofSpeciesOrNull(Species species) {
    return _ofSpecies[species];
  }

  Knowledge updated(Species species, SpeciesKnowledge speciesKnowledge) {
    final builder = _ofSpecies.toBuilder();
    builder[species] = speciesKnowledge;
    return Knowledge(builder.build());
  }

  @override
  bool operator ==(dynamic other) => other is Knowledge && _ofSpecies == other._ofSpecies;

  @override
  int get hashCode => _ofSpecies.hashCode;

  @override
  String toString() => _ofSpecies.toString();

}

/// Represents the knowledge a user has about a single species.
///
/// Wraps an [EbisuModel] as well as the time the species was last asked and species it has been confused with.
///
/// Knowledge about a species can be in one of three states:
/// 0. Never asked before: `speciesKnowledge == null || speciesKnowledge.isNone`.
/// 1. Asked once: `!speciesKnowledge.isNone` but the Ebisu model is the initial model.
/// 2. Asked more than once: the Ebisu model is something else.
@immutable
class SpeciesKnowledge {
  static const _minutesPerDay = 60.0 * 24.0;
  static const _millisecondsPerDay = 1000.0 * 60.0 * 60.0 * 24.0;
  
  static const _initialHalflifeDays = 10.0 / _minutesPerDay;
  static const _initialAlpha = 3.0;

  // Tweaked by hand to "feel right".
  static const _firstHalfStarAtDays = 60.0 / _minutesPerDay;
  static const _halfStarExponent = 1.9;

  static const _numConfusionsToKeep = 20;

  static const maxStarCount = 5;
  static const maxHalfStarCount = 2 * maxStarCount;

  /// The underlying Ebisu model. Time is in days.
  /// This is `null` if the species has never been encountered before.
  final EbisuModel model;

  /// When the species was last quizzed on.
  /// This is 0 if and only if [model] is `null`.
  final int _lastAskedTimestampMs;

  /// A list of species IDs that this species has been confused with in the past.
  ///
  /// Each entry represents either a wrongly answered question (with a confusion in either direction), or this species
  /// answered correctly (to eventually push out old confusions).
  ///
  /// They are in reverse chronological order. One should expect to see the same species ID more than once.
  final BuiltList<int> confusionSpeciesIds;

  SpeciesKnowledge.none() :
      model = null,
      _lastAskedTimestampMs = 0,
      confusionSpeciesIds = BuiltList();

  SpeciesKnowledge.fromMap(Map<String, dynamic> map) :
      model =
        map['ebisu_time'] != null && map['ebisu_alpha'] != null && map['ebisu_beta'] != null ?
        EbisuModel(
          time: map['ebisu_time'] as double,
          alpha: map['ebisu_alpha'] as double,
          beta: map['ebisu_beta'] as double,
        ) :
        null,
      _lastAskedTimestampMs = map['last_asked_timestamp_ms'] as int,
      // We need to clone the Uint8List because offset inside the underlying buffer must be a multiple of elements size.
      confusionSpeciesIds = decodeSpeciesIdList((map['confusion_species_ids'] as Uint8List) ?? Uint8List(0));
  
  SpeciesKnowledge._internal(this.model, this._lastAskedTimestampMs, this.confusionSpeciesIds);

  /// True if and only if this species has never been asked before.
  bool get isNone => model == null;

  /// Returns the estimated halflife (time to forget) for this species in days.
  double get halflifeDays => model?.modelToPercentileDecay(percentile: 0.5) ?? 0.0;

  /// Returns how many half stars (out of 5 whole stars, i.e. 10 half stars) this species gets.
  /// This is a monomial function of the predicted halflife.
  int get halfStars =>
      halflifeDays <= 0 ?
      0 :
      max(0, min((pow(halflifeDays / _firstHalfStarAtDays, 1.0 / _halfStarExponent)).floor(), maxHalfStarCount));

  DateTime get lastAskedTimestamp => _lastAskedTimestampMs == 0 ? null : DateTime.fromMillisecondsSinceEpoch(_lastAskedTimestampMs);

  /// Returns the probability between 0 and 1 that the species is remembered at this moment.
  double recallProbability(DateTime now) => model?.predictRecall(daysSinceAsked(now), exact: true) ?? 0.0;

  /// Returns a number that represents how important it is to ask about this species now (greater is higher priority).
  /// The number is not meaningful by itself, only in comparisons.
  double priority(DateTime now) => -(model?.predictRecall(daysSinceAsked(now)) ?? double.negativeInfinity);

  /// Returns a new [SpeciesKnowledge] that represents the knowledge after the given question has been answered.
  /// [answerTimestamp] may be set to `null` to skip updating the timestamp.
  SpeciesKnowledge withUpdatedModel({@required bool correct, @required DateTime answerTimestamp, bool updateTimestamp = true}) {
    EbisuModel newModel;
    if (model == null) {
      // This species was seen for the first time. Initialize the Ebisu model so that the predicted recall will be 100%
      // and don't record whether the answer was correct, because it wouldn't be meaningful when the species has been
      // encountered for the first time.
      newModel = EbisuModel(time: _initialHalflifeDays, alpha: _initialAlpha);
    } else {
      try {
        newModel = model.updateRecall(correct ? 1 : 0, 1, daysSinceAsked(answerTimestamp));
      } catch (ex) {
        _log.severe('Failed to update Ebisu model; keeping current model', ex);
        newModel = model;
      }
    }
    final newAnswerTimestamp = updateTimestamp ? answerTimestamp.millisecondsSinceEpoch : _lastAskedTimestampMs;
    return SpeciesKnowledge._internal(newModel, newAnswerTimestamp, confusionSpeciesIds);
  }

  /// Returns a new [SpeciesKnowledge] that represents the knowledge after a question about _another_ species has been
  /// wrongly answered with _this_ species, or when _this_ species was correctly answered (to push out old confusions).
  SpeciesKnowledge withAddedConfusion({@required int confusedWithspeciesId}) {
    final newConfusionSpeciesIds = confusionSpeciesIds.rebuild((builder) {
      builder
          ..insert(0, confusedWithspeciesId)
          ..trimTo(_numConfusionsToKeep);
    });
    return SpeciesKnowledge._internal(model, _lastAskedTimestampMs, newConfusionSpeciesIds);
  }

  double daysSinceAsked(DateTime now) => max(0.0, (now.millisecondsSinceEpoch - _lastAskedTimestampMs) / _millisecondsPerDay);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'ebisu_time': model?.time,
    'ebisu_alpha': model?.alpha,
    'ebisu_beta': model?.beta,
    'last_asked_timestamp_ms': _lastAskedTimestampMs,
    'confusion_species_ids': encodeSpeciesIdList(confusionSpeciesIds.asList()),
  };

  @override
  bool operator ==(dynamic other) => other is SpeciesKnowledge &&
      model == other.model &&
      _lastAskedTimestampMs == other._lastAskedTimestampMs &&
      confusionSpeciesIds == other.confusionSpeciesIds;

  @override
  int get hashCode => model.hashCode ^ _lastAskedTimestampMs.hashCode ^ confusionSpeciesIds.hashCode;

  @override
  String toString() => '$model @ ${lastAskedTimestamp?.toIso8601String() ?? '<never asked>'} (confusions: $confusionSpeciesIds)';
}

BuiltList<int> decodeSpeciesIdList(Uint8List encoded) {
  // `encoded` may be a view into a larger buffer, and that view might not aligned to 2-byte boundaries.
  // So we need to make a copy. Conveniently, sublist does that: https://stackoverflow.com/a/45548181/14637
  return encoded.sublist(0).buffer.asUint16List().build();
}

Uint8List encodeSpeciesIdList(List<int> speciesIdList) {
  return Uint8List.sublistView(Uint16List.fromList(speciesIdList));
}