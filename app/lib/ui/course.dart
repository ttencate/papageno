import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
                itemBuilder: (context, index) => _buildLessonTile(context, course.lessons[index]),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          throw snapshot.error;
        } else {
          return Container(child: Center(child: CircularProgressIndicator()));
        }
      },
    );
  }

  Widget _buildLessonTile(BuildContext context, Lesson lesson) {
    return Card(
      key: ObjectKey(lesson.index),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          children: <Widget>[
            Text(
              Strings.of(context).lessonTitle(lesson.number),
              style: TextStyle(fontSize: 24.0),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 8.0,
            ),
            Wrap(
              children: lesson.species.map((species) =>
                  Chip(
                    label: Text(
                      species.commonNameIn(LanguageCode.language_nl),
                      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w300),
                    ),
                    backgroundColor: Colors.grey.shade200,
                    visualDensity: VisualDensity(vertical: VisualDensity.minimumDensity),
                  )).toList(),
              spacing: 4.0,
              alignment: WrapAlignment.center,
            ),
          ],
        ),
      ),
    );
  }
}