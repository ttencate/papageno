import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/model/model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/ui/question.dart';
import 'package:papageno/ui/strings.g.dart';
import 'package:papageno/utils/iterable_utils.dart';
import 'package:provider/provider.dart';

class QuizResult extends StatelessWidget {
  final Quiz quiz;
  final void Function() onRetry;
  final void Function() onBack;

  const QuizResult({Key key, this.quiz, this.onRetry, this.onBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
    final primarySpeciesLanguageCode = settings.primarySpeciesLanguage.value.resolve(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Text(
                      strings.quizScore,
                      style: theme.textTheme.headline4,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${quiz.scorePercent}%',
                      style: theme.textTheme.headline1.copyWith(fontSize: 92.0),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      strings.quizScoreDetails(quiz.correctAnswerCount, quiz.questionCount),
                      style: theme.textTheme.subtitle1,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (quiz.fullyCorrectSpecies.isNotEmpty) Container(
                color: Colors.green.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          AnswerIcon(correct: true),
                          SizedBox(width: 4.0),
                          Text(
                            strings.strongPoints,
                            style: theme.textTheme.headline6,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        quiz.fullyCorrectSpecies
                            .map((species) => species.commonNameIn(primarySpeciesLanguageCode))
                            .sorted()
                            .join(', '),
                      ),
                    ],
                  ),
                ),
              ),
              if (quiz.incorrectQuestions.isNotEmpty) Container(
                color: Colors.red.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          AnswerIcon(correct: false),
                          SizedBox(width: 4.0),
                          Text(
                            strings.weakPoints,
                            style: theme.textTheme.headline6,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.0),
                      for (final question in quiz.incorrectQuestions) Text(
                        strings.confusionText(
                            question.correctAnswer.commonNameIn(primarySpeciesLanguageCode),
                            question.givenAnswer.commonNameIn(primarySpeciesLanguageCode)),
                        style: theme.textTheme.bodyText2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: <Widget>[
              FlatButton(
                child: Text(strings.backButton.toUpperCase()),
                onPressed: onBack,
              ),
              Spacer(),
              RaisedButton(
                child: Text(strings.retryQuizButton.toUpperCase()),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }

}