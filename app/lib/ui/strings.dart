import 'package:flutter/cupertino.dart';

import '../model/model.dart';

abstract class Strings {
  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings);
  }

  String get appTitle;

  String courseTitle(LatLon location);

  String lessonTitle(int lessonNumber);
  String get startLesson;

  String questionIndex(int currentQuestionIndex, int totalQuestionCount);
  String get rightAnswerInstructions;
  String get wrongAnswerInstructions;

  String recordingCreator(String name);
  String imageCreator(String name);
  String get unknownCreator;
  String source(String url);
  String license(String name);
  String get ok;
}

class Strings_en implements Strings {
  @override
  String appTitle = 'Papageno';

  @override
  String courseTitle(LatLon location) => 'Birds near ${location.lat}, ${location.lon}';

  @override
  String lessonTitle(int lessonNumber) => 'Lesson ${lessonNumber}';
  @override
  String startLesson = 'Start';

  @override
  String questionIndex(int currentQuestionIndex, int totalQuestionCount) => 'Question $currentQuestionIndex of $totalQuestionCount';
  @override
  String rightAnswerInstructions = 'Tap anywhere to continue';
  @override
  String wrongAnswerInstructions = 'Tap anywhere to continue';

  @override
  String recordingCreator(String name) => 'Audio recording by ${name}';
  @override
  String imageCreator(String name) => 'Photo by ${name}';
  @override
  String unknownCreator = '[unknown, see source page]';
  @override
  String source(String url) => 'Source: ${url}';
  @override
  String license(String name) => 'License: ${name}';
  @override
  String ok = 'OK';
}

class Strings_nl implements Strings {
  @override
  String appTitle = 'Papageno';

  @override
  String courseTitle(LatLon location) => 'Vogels in de omgeving van ${location.lat}, ${location.lon}';

  @override
  String lessonTitle(int lessonNumber) => 'Les ${lessonNumber}';
  @override
  String startLesson = 'Start';

  @override
  String questionIndex(int currentQuestionIndex, int totalQuestionCount) => 'Vraag $currentQuestionIndex van $totalQuestionCount';
  @override
  String rightAnswerInstructions = 'Tik ergens om verder te gaan';
  @override
  String wrongAnswerInstructions = 'Tik ergens om verder te gaan';

  @override
  String recordingCreator(String name) => 'Geluidsopname door ${name}';
  @override
  String imageCreator(String name) => 'Foto door ${name}';
  @override
  String unknownCreator = '[onbekend, zie bronpagina]';
  @override
  String source(String url) => 'Bron: ${url}';
  @override
  String license(String name) => 'Licensie: ${name}';
  @override
  String ok = 'OK';
}