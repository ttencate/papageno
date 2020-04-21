import 'package:flutter/cupertino.dart';

import '../model/model.dart';

abstract class Strings {
  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings);
  }

  String get appTitle;
  String courseTitle(LatLon location);
  String lessonTitle(int lessonNumber);
  String questionIndex(int currentQuestionIndex, int totalQuestionCount);
  String get rightAnswerInstructions;
  String get wrongAnswerInstructions;
}

class Strings_en implements Strings {
  @override
  String get appTitle => 'Papageno';
  @override
  String courseTitle(LatLon location) => 'Birds near ${location.lat}, ${location.lon}';
  @override
  String lessonTitle(int lessonNumber) => 'Lesson ${lessonNumber}';
  @override
  String questionIndex(int currentQuestionIndex, int totalQuestionCount) => 'Question $currentQuestionIndex of $totalQuestionCount';
  @override
  String rightAnswerInstructions = 'Tap to continue';
  @override
  String wrongAnswerInstructions = 'Tap to continue';
}

class Strings_nl implements Strings {
  @override
  String get appTitle => 'Papageno';
  @override
  String courseTitle(LatLon location) => 'Vogels in de omgeving van ${location.lat}, ${location.lon}';
  @override
  String lessonTitle(int lessonNumber) => 'Les ${lessonNumber}';
  @override
  String questionIndex(int currentQuestionIndex, int totalQuestionCount) => 'Vraag $currentQuestionIndex van $totalQuestionCount';
  @override
  String rightAnswerInstructions = 'Tik om verder te gaan';
  @override
  String wrongAnswerInstructions = 'Tik om verder te gaan';
}