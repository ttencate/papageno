import 'package:flutter/material.dart';

import '../model/model.dart';
import 'strings.dart';
import 'question.dart';

class QuizScreen extends StatefulWidget {

  QuizScreen(this.quiz);

  final Quiz quiz;

  @override
  State<StatefulWidget> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {

  Future<Question> _currentQuestion;

  @override
  void initState() {
    super.initState();
    _currentQuestion = widget.quiz.getNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.of(context).questionIndex(widget.quiz.currentQuestionIndex + 1, widget.quiz.totalQuestionCount)),
        // TODO show some sort of progress bar
      ),
      body: FutureBuilder<Question>(
        future: _currentQuestion,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return QuestionScreen(
                key: ObjectKey(snapshot.data),
                question: snapshot.data,
                onProceed: _showNextQuestion
            );
          } else {
            return Container();
          }
        },
      ),
    );
  }

  void _showNextQuestion() {
    // TODO this only slides the new question in; also slide the old one out
    final route = PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => QuizScreen(widget.quiz),
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