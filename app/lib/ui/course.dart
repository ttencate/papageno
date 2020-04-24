import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/ui/quiz.dart';
import 'package:provider/provider.dart';

import '../db/appdb.dart';
import '../model/model.dart';
import '../controller/controller.dart';
import 'strings.dart';

class CourseScreen extends StatefulWidget {
  @override
  _CourseScreenState createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  Future<Course> _course;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_course == null) {
      final appDb = Provider.of<AppDb>(context);
      _course = createCourse(appDb);
    }
  }

  @override
  Widget build(BuildContext context) {
    // final appDb = Provider.of<AppDb>(context);
    return FutureBuilder<Course>(
      future: _course,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final course = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: Text(Strings.of(context).courseTitle(course.location)),
            ),
            body: Container(
              color: Colors.grey.shade200,
              child: ListView.builder(
                itemCount: course.lessons.length,
                itemBuilder: (context, index) => _buildLesson(context, course.lessons[index]),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          throw snapshot.error;
        } else {
          return Container(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }

  Widget _buildLesson(BuildContext context, Lesson lesson) {
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
                      color: Colors.blue,
                      textColor: Colors.white,
                      child: Text(Strings.of(context).startLesson.toUpperCase()),
                      onPressed: () { _startQuiz(lesson); },
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
                        species.commonNameIn(LanguageCode.language_nl),
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

  void _startQuiz(Lesson lesson) async {
    final appDb = Provider.of<AppDb>(context, listen: false);
    final course = await _course;
    final quiz = await createQuiz(appDb, course, lesson);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => QuizScreen(quiz)
    ));
  }
}