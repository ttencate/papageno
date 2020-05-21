import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/app_model.dart';

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
@immutable
class Profile {
  final int profileId;
  final String name;

  Profile(this.profileId, this.name);

  Profile.fromMap(Map<String, dynamic> map) :
        profileId = map['profile_id'] as int,
        name = map['name'] as String;
}

class Course {
  static const minProgressPercentToUnlockNextLesson = 60;

  int courseId;
  final int profileId;
  final LatLon location;
  final BuiltList<Lesson> lessons;
  int _unlockedLessonCount; // At least 1.

  Course({this.courseId, this.profileId, this.location, this.lessons, int unlockedLessonCount}) :
    _unlockedLessonCount = max(1, unlockedLessonCount ?? 1);

  int get lessonCount => lessons.length;

  int get speciesCount => lessons.map((lesson) => lesson.species.length).fold(0, (a, b) => a + b);

  int get unlockedLessonCount => _unlockedLessonCount;

  Lesson get lastUnlockedLesson => lessons[_unlockedLessonCount - 1];
  BuiltList<Lesson> get unlockedLessons => lessons.sublist(0, _unlockedLessonCount);
  BuiltList<Lesson> get lockedLessons => lessons.sublist(_unlockedLessonCount);

  bool unlockLessons(Knowledge knowledge) {
    final prevUnlockedLessonCount = _unlockedLessonCount;
    print('Prev: ${prevUnlockedLessonCount}');
    while (_unlockedLessonCount < lessonCount) {
      if (lastUnlockedLesson.progressPercent(knowledge) < minProgressPercentToUnlockNextLesson) {
        break;
      }
      _unlockedLessonCount++;
    }
    return _unlockedLessonCount != prevUnlockedLessonCount;
  }
}

@immutable
class Lesson {
  final int index;
  final BuiltList<Species> species;

  Lesson({this.index, this.species});

  int get number => index + 1;

  double progressPercent(Knowledge knowledge) {
    return species.map((species) => knowledge.ofSpecies(species).scorePercent).fold(100.0, (a, b) => min(a, b));
  }
}

class Quiz {
  final BuiltList<Question> questions;
  int _currentQuestionIndex = 0;

  Quiz(this.questions);

  int get questionCount => questions.length;

  bool get isComplete => _currentQuestionIndex >= questionCount;

  int get currentQuestionIndex => _currentQuestionIndex;
  int get currentQuestionNumber => _currentQuestionIndex + 1;

  Question get currentQuestion => isComplete ? null : questions[_currentQuestionIndex];

  void proceedToNextQuestion() {
    assert(!isComplete);
    _currentQuestionIndex++;
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

  void answerWith(Species answer) {
    assert(_givenAnswer == null);
    assert(answer != null);
    _givenAnswer = answer;
    _answerTimestamp = DateTime.now();
  }
}

/// Represents how much the user knows about each species.
@immutable
class Knowledge {
  final Map<Species, SpeciesKnowledge> _ofSpecies;

  Knowledge(this._ofSpecies);

  SpeciesKnowledge ofSpecies(Species species) {
    return _ofSpecies[species] ?? SpeciesKnowledge.none;
  }

  @override
  String toString() => _ofSpecies.toString();
}

@immutable
class SpeciesKnowledge {
  static const int _minAnswerCountForFullScore = 4;

  static final none = SpeciesKnowledge(correctAnswerCount: 0, totalAnswerCount: 0);

  final int correctAnswerCount;
  final int totalAnswerCount;

  SpeciesKnowledge({@required this.correctAnswerCount, @required this.totalAnswerCount});

  double get scorePercent => 100.0 * correctAnswerCount.toDouble() / max(totalAnswerCount, _minAnswerCountForFullScore).toDouble();

  @override
  String toString() => '${correctAnswerCount}/${totalAnswerCount} (${scorePercent.round()}%)';
}