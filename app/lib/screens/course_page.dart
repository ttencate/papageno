import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/controller/controller.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/quiz_page.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/settings.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:provider/provider.dart';

class CoursePage extends StatefulWidget {
  final Profile profile;
  final Course course;

  const CoursePage(this.profile, this.course);

  @override
  _CoursePageState createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final course = widget.course;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.courseName(course)),
      ),
      drawer: MenuDrawer(profile: widget.profile, course: widget.course),
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
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
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
                      strings.lessonTitle(lesson.number),
                      style: theme.textTheme.headline6,
                    ),
                    RaisedButton(
                      child: Text(strings.startLesson.toUpperCase()),
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
                        species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
                        style: theme.textTheme.bodyText2,
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
    final quizPageResult = await Navigator.of(context).push(QuizRoute(widget.profile, widget.course, quiz));
    if (quizPageResult is QuizPageResult && quizPageResult.restart) {
      _startQuiz(course, lesson);
    }
  }
}