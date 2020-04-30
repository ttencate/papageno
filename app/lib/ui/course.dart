import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/ui/quiz.dart';
import 'package:provider/provider.dart';

import '../db/appdb.dart';
import '../model/model.dart';
import '../controller/controller.dart';
import 'settings.dart';
import 'strings.dart';

class CoursePage extends StatefulWidget {
  static const route = '/course';

  @override
  _CoursePageState createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  @override
  Widget build(BuildContext context) {
    // final appDb = Provider.of<AppDb>(context);
    final strings = Strings.of(context);
    final course = ModalRoute.of(context).settings.arguments as Course;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.courseTitle(strings.latLon(course.location))),
      ),
      body: Container(
        color: Colors.grey.shade200,
        child: ListView.builder(
          itemCount: course.lessons.length,
          itemBuilder: (context, index) => _buildLesson(context, course, course.lessons[index]),
        ),
      ),
    );
  }

  Widget _buildLesson(BuildContext context, Course course, Lesson lesson) {
    final primarySpeciesLanguageCode = Provider.of<Settings>(context).primarySpeciesLanguageCode;
    return Card(
      key: ObjectKey(lesson.index),
      // We need IntrinsicHeight here because the inner Row has CrossAxisAlignment.stretch,
      // which we want so that its child Columns are stretched across the full height.
      child: IntrinsicHeight(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      Strings.of(context).lessonTitle(lesson.number),
                      style: TextStyle(fontSize: 24.0),
                    ),
                    RaisedButton(
                      color: Colors.blue, // TODO take from theme
                      textColor: Colors.white,
                      child: Text(Strings.of(context).startLesson.toUpperCase()),
                      onPressed: () { _startQuiz(course, lesson); },
                    )
                  ],
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lesson.species
                    .map((species) =>
                      Text(
                        species.commonNameIn(primarySpeciesLanguageCode),
                        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w300),
                      ),
                    )
                    .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startQuiz(Course course, Lesson lesson) async {
    final appDb = Provider.of<AppDb>(context, listen: false);
    final quiz = await createQuiz(appDb, course, lesson);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => QuizPage(quiz)
    ));
  }
}