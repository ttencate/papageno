import 'package:flutter/material.dart';
import 'package:papageno/model/model.dart';
import 'package:papageno/ui/menu_drawer.dart';
import 'package:papageno/ui/question.dart';
import 'package:papageno/ui/quiz_result.dart';
import 'package:papageno/ui/strings.g.dart';

class QuizPage extends StatefulWidget {
  // TODO actually use this (+ route arguments) for navigation
  static const route = '/quiz';

  final Quiz quiz;
  final void Function() onRetry;

  QuizPage(this.quiz, {this.onRetry});

  @override
  State<StatefulWidget> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {

  PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  Quiz get quiz => widget.quiz;

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return WillPopScope(
      onWillPop: _willPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            !quiz.isComplete ?
            strings.questionIndex(quiz.currentQuestionNumber, quiz.questionCount) :
            strings.quizResultsTitle
          ),
          // TODO show some sort of progress bar
        ),
        drawer: MenuDrawer(),
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          itemCount: quiz.questionCount + 1,
          itemBuilder: (BuildContext context, int index) =>
            index < quiz.questionCount ?
            QuestionScreen(
              key: ObjectKey(quiz.questions[index]),
              question: quiz.questions[index],
              onProceed: _showNextQuestion,
            ) :
            QuizResult(
              quiz: quiz,
              onRetry: _retry,
              onBack: _back,
            ),
        ),
      ),
    );
  }

  Future<void> _showNextQuestion() async {
    if (!quiz.isComplete) {
      setState(() {
        quiz.proceedToNextQuestion();
      });
      print('Animate to page ${quiz.currentQuestionIndex}');
      await _pageController.animateToPage(
          quiz.currentQuestionIndex,
          duration: Duration(milliseconds: 400),
          curve: Curves.ease);
    }
  }

  void _retry() async {
    await Navigator.of(context).pop();
    if (widget.onRetry != null) {
      widget.onRetry();
    }
  }

  void _back() {
    Navigator.of(context).pop();
  }

  Future<bool> _willPop() async {
    if (quiz.isComplete) {
      return true;
    } else {
      final strings = Strings.of(context);
      final abortQuiz = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(strings.abortQuizTitle),
          content: Text(strings.abortQuizContent),
          actions: <Widget>[
            FlatButton(
              child: Text(strings.no.toUpperCase()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            FlatButton(
              child: Text(strings.yes.toUpperCase()),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      return abortQuiz ?? false;
    }
  }
}