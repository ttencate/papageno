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
import 'package:papageno/widgets/inner_shadow.dart';
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

  Future<Knowledge> _loadKnowledge() async {
    setState(() {
      _knowledge = _userDb.knowledge(widget.profile.profileId);
    });
    return await _knowledge;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final course = widget.course;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.courseName(course)),
      ),
      drawer: MenuDrawer(profile: widget.profile, course: widget.course),
      body: FutureBuilder<Knowledge>(
        future: _knowledge,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final lessonScore = course.lastUnlockedLesson.score(snapshot.data);
          final unlockScore = course.lastUnlockedLesson.scoreToUnlockNext;
          return Container(
            color: Colors.grey.shade200,
            child: ListView(
              children: <Widget>[
                for (final lesson in course.unlockedLessons) _LessonCard(
                  knowledge: snapshot.data,
                  course: course,
                  lesson: lesson,
                  onStart: () { _startQuiz(course, lesson); },
                ),
                if (course.hasAnyLockedLessons) Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        strings.unlockProgress,
                        style: theme.textTheme.bodyText1,
                        softWrap: true,
                      ),
                      SizedBox(height: 8.0),
                      _FancyProgressBar(
                        value: lessonScore / unlockScore,
                        backgroundColor: Colors.grey.shade400,
                        valueColor: _percentageColor(
                          (lessonScore / unlockScore * 100.0).round()),
                        child: Text(
                          '${lessonScore}/${unlockScore}',
                        ),
                      ),
                    ],
                  ),
                ),
                for (final lesson in course.lockedLessons) _LessonCard(
                  knowledge: snapshot.data,
                  course: course,
                  lesson: lesson,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startQuiz(Course course, Lesson lesson) async {
    final appDb = Provider.of<AppDb>(context, listen: false);
    final quiz = await createQuiz(appDb, course, lesson);
    final quizPageResult = await Navigator.of(context).push(QuizRoute(widget.profile, course, quiz));
    final knowledge = await _loadKnowledge();
    var unlockedAnyLessons = false;
    setState(() { unlockedAnyLessons = course.unlockLessons(knowledge); });
    if (unlockedAnyLessons) {
      await _userDb.updateCourseUnlockedLessons(course);
      // TODO show a nice message!
    }
    if (quizPageResult is QuizPageResult && quizPageResult.restart) {
      _startQuiz(course, lesson);
    }
  }
}

class _LessonCard extends StatelessWidget {
  final Knowledge knowledge;
  final Course course;
  final Lesson lesson;
  final void Function() onStart;

  const _LessonCard({Key key, @required this.knowledge, @required this.course, @required this.lesson, this.onStart}) : super(key: key);

  bool get _locked => onStart == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Card(
      key: ObjectKey(lesson.index),
      child: Opacity(
        opacity: _locked ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    strings.lessonTitle(lesson.number),
                    style: theme.textTheme.headline5,
                  ),
                  if (!_locked) RaisedButton(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final species in lesson.species) _SpeciesItem(
                    species: species,
                    knowledge: knowledge.ofSpecies(species),
                    locked: _locked,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesItem extends StatelessWidget {
  final Species species;
  final SpeciesKnowledge knowledge;
  final bool locked;

  const _SpeciesItem({Key key, this.species, this.knowledge, this.locked}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<Settings>(context);
    final locale = WidgetsBinding.instance.window.locale;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
              style: theme.textTheme.bodyText2,
              softWrap: true,
            ),
          ),
          SizedBox(width: 16.0),
          Text(
            locked ? '' : '${knowledge.correctAnswerCount}',
            style: theme.textTheme.bodyText2.copyWith(fontWeight: FontWeight.bold, color: _percentageColor(knowledge.scorePercent.round())),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _FancyProgressBar extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final Color valueColor;
  final Widget child;

  const _FancyProgressBar({Key key, @required this.value, this.backgroundColor, this.valueColor, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InnerShadow(
      shadows: <Shadow>[
        Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4.0, offset: Offset(0.0, 1.0)),
      ],
      child: Container(
        height: 32.0,
        decoration: BoxDecoration(
          color: backgroundColor,
        ),
        child: Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.center,
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(color: valueColor),
              ),
            ),
            if (child != null) Center(
              child: DefaultTextStyle(
                style: theme.textTheme.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2.0),
                    Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 8.0),
                  ],
                ),
                child: child,
              ),
            ),
          ]
        ),
      ),
    );
  }

}

Color _percentageColor(int percent) {
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