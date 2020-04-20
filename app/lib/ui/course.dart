import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/appdb.dart';
import '../model/model.dart';
import 'quiz.dart';
import 'errors.dart';

class CourseScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appDb = Provider.of<AppDb>(context);
    final quiz = Quiz(appDb);
    return FutureBuilder<Question>(
      future: quiz.getNextQuestion(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return QuizScreen(quiz);
        } else if (snapshot.hasError) {
          return ErrorScreen('Error creating question', snapshot.error);
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}