import 'package:flutter/cupertino.dart';

abstract class Strings {
  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings);
  }

  String get appTitle;
  String questionIndex(int currentQuestionIndex, int totalQuestionCount);
  String get rightAnswerInstructions;
  String get wrongAnswerInstructions;
}

class Strings_en implements Strings {
  @override
  String get appTitle => 'Papageno';
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
  String questionIndex(int currentQuestionIndex, int totalQuestionCount) => 'Vraag $currentQuestionIndex van $totalQuestionCount';
  @override
  String rightAnswerInstructions = 'Tik om verder te gaan';
  @override
  String wrongAnswerInstructions = 'Tik om verder te gaan';
}