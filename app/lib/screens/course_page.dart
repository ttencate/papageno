import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/controller/controller.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/quiz_page.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/settings.dart';
import 'package:papageno/services/user_db.dart';
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

  UserDb _userDb;
  Future<Knowledge> _knowledge;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userDb = Provider.of<UserDb>(context);
    _loadKnowledge();
  }

  void _loadKnowledge() async {
    setState(() {
      _knowledge = _userDb.knowledge(widget.profile.profileId);
    });
    await _knowledge;
    print(await _knowledge);
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final course = widget.course;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.courseName(course)),
      ),
      drawer: MenuDrawer(profile: widget.profile, course: widget.course),
      body: FutureBuilder<Knowledge>(
        future: _knowledge,
        builder: (context, snapshot) =>
          snapshot.hasData ?
          Container(
            color: Colors.grey.shade200,
            child: ListView.builder(
              itemCount: course.lessons.length,
              itemBuilder: (context, index) => _LessonCard(
                knowledge: snapshot.data,
                course: course,
                lesson: course.lessons[index],
                onStart: () { _startQuiz(course, course.lessons[index]); },
              ),
            ),
          ) :
          Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _startQuiz(Course course, Lesson lesson) async {
    final appDb = Provider.of<AppDb>(context, listen: false);
    final quiz = await createQuiz(appDb, course, lesson);
    final quizPageResult = await Navigator.of(context).push(QuizRoute(widget.profile, widget.course, quiz));
    if (quizPageResult is QuizPageResult && quizPageResult.restart) {
      _startQuiz(course, lesson);
    } else {
      await _loadKnowledge();
    }
  }
}

class _LessonCard extends StatelessWidget {
  final Knowledge knowledge;
  final Course course;
  final Lesson lesson;
  final void Function() onStart;

  const _LessonCard({Key key, @required this.knowledge, @required this.course, @required this.lesson, @required this.onStart}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Card(
      key: ObjectKey(lesson.index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.lessonTitle(lesson.number),
                      style: theme.textTheme.headline5,
                    ),
                    Text(
                      strings.lessonProgress(knowledge.lessonProgressPercent(lesson).round()),
                      style: theme.textTheme.caption,
                    )
                  ],
                ),
                RaisedButton(
                  child: Text(strings.startLesson.toUpperCase()),
                  onPressed: onStart,
                )
              ],
            ),
          ),
          Divider(height: 0.0),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final species in lesson.species) _SpeciesItem(
                  species: species,
                  knowledge: knowledge.ofSpecies(species),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesItem extends StatelessWidget {
  final Species species;
  final SpeciesKnowledge knowledge;

  const _SpeciesItem({Key key, this.species, this.knowledge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 40.0,
          child: Text(
            '${knowledge.scorePercent.round()}%',
            style: theme.textTheme.bodyText2.copyWith(fontWeight: FontWeight.bold, color: _percentageColor(knowledge.scorePercent.round())),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(width: 16.0),
        Expanded(
          child: Text(
            species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
            style: theme.textTheme.bodyText2,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  static Color _percentageColor(int percent) {
    // Conveniently, maps in Dart preserve their order.
    const stops = <int, Color>{
      0: Color.fromRGBO(0, 0, 0, 0.15),
      20: Colors.red,
      40: Colors.deepOrange,
      50: Colors.orange,
      60: Colors.yellow,
      75: Colors.lightGreen,
      100: Colors.green,
    };
    var prevLocation = stops.keys.first;
    var prevColor = stops.values.first;
    for (final stop in stops.entries.skip(1)) {
      if (percent <= stop.key) {
        return Color.lerp(prevColor, stop.value, (percent - prevLocation) / (stop.key - prevLocation));
      }
      prevLocation = stop.key;
      prevColor = stop.value;
    }
    return stops.values.last;
  }
}