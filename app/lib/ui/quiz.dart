import 'package:flutter/material.dart';

import '../model/model.dart';
import 'strings.dart';
import 'question.dart';

class QuizScreen extends StatefulWidget {

  QuizScreen(this.quiz, {this.questionIndex = 0});

  final Quiz quiz;
  final int questionIndex;

  Question get currentQuestion => quiz.questions[questionIndex];

  @override
  State<StatefulWidget> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.of(context).questionIndex(widget.questionIndex + 1, widget.quiz.questions.length)),
        // TODO show some sort of progress bar
      ),
      body: QuestionScreen(
        key: ObjectKey(widget.currentQuestion),
        question: widget.currentQuestion,
        onProceed: _showNextQuestion
      ),
    );
  }

  void _showNextQuestion() {
    final nextQuestionIndex = widget.questionIndex + 1;
    if (nextQuestionIndex >= widget.quiz.questions.length) {
      Navigator.of(context).pop();
      return;
    }

    // TODO this only slides the new question in; also slide the old one out
    final route = PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => QuizScreen(
        widget.quiz,
        questionIndex: nextQuestionIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(begin: Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          textDirection: Directionality.of(context),
          child: child,
        );
      },
    );
    Navigator.of(context).pushReplacement(route);
  }
}