import 'package:flutter/material.dart';
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
    final appDb = Provider.of<AppDb>(context);
    final quiz = Quiz(appDb);
    return FutureBuilder<Course>(
      future: _course,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final course = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: Text(Strings.of(context).courseTitle(course.location)),
            ),
            body: ListView.separated(
              itemCount: course.speciesOrder.length,
              itemBuilder: (context, index) {
                var species = course.speciesOrder[index];
                return ListTile(
                  key: ObjectKey(species),
                  title: Text(
                      // TODO take language from settings
                      species.commonNameIn(LanguageCode.language_nl) +
                      ' (' + species.scientificName + ')'),
                );
              },
              separatorBuilder: (context, index) => Divider(),
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
}