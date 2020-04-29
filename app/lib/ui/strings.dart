import 'package:flutter/cupertino.dart';

import '../model/model.dart';

abstract class Strings {
  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings);
  }

  String get appTitle;

  String get createCourseTitle;
  String get createCourseInstructions;
  String courseLocation(String location);
  String get courseSearchingSpecies;
  String courseSpecies(String topSpecies, int count);
  String get createCourseButton;
  String courseTitle(String location);

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

  String latLon(LatLon latLon);
}

class Strings_en implements Strings {
  @override
  String appTitle = 'Papageno';

  @override
  String createCourseTitle = 'Start new course';
  @override
  String createCourseInstructions = 'Tap the map to choose the location whose birds you want to learn to recognize.';
  @override
  String courseLocation(String location) => 'Selected location: ${location}';
  @override
  String courseSearchingSpecies = 'Searching for bird species…';
  @override
  String courseSpecies(String topSpecies, int count) => 'Found ${count} species, such as: ${topSpecies}';
  @override
  String createCourseButton = 'Start course';
  @override
  String courseTitle(String location) => 'Birds near ${location}';

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

  // TODO make number formatting locale-sensitive (probably needs NumberFormat from intl package)
  @override
  String latLon(LatLon latLon) => '${latLon.lat.toStringAsFixed(3)}, ${latLon.lon.toStringAsFixed(3)}';
}

class Strings_nl implements Strings {
  @override
  String appTitle = 'Papageno';

  @override
  String createCourseTitle = 'Nieuwe cursus beginnen';
  @override
  String createCourseInstructions = 'Tik op de kaart om de omgeving te kiezen waarvan je de vogels wilt leren herkennen.';
  @override
  String courseLocation(String location) => 'Gekozen locatie: ${location}';
  @override
  String courseSearchingSpecies = 'Vogelsoorten worden opgezocht…';
  @override
  String courseSpecies(String topSpecies, int count) => '${count} soorten gevonden, waaronder: $topSpecies';
  @override
  String createCourseButton = 'Begin cursus';
  @override
  String courseTitle(String location) => 'Vogels in de omgeving van ${location}';

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

  // TODO make number formatting locale-sensitive (probably needs NumberFormat from intl package)
  @override
  String latLon(LatLon latLon) => '${latLon.lat.toStringAsFixed(3)}, ${latLon.lon.toStringAsFixed(3)}';
}