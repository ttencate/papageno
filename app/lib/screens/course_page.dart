import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/controller/controller.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/quiz_page.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/color_utils.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:pedantic/pedantic.dart';
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
    final strings = Strings.of(context);
    final course = widget.course;
    return ChangeNotifierProvider<Settings>.value(
      value: widget.profile.settings,
      child: Scaffold(
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
            return Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(16.0),
                    children: <Widget>[
                      for (final species in course.unlockedSpecies) _SpeciesItem(
                        species: species,
                        knowledge: snapshot.data.ofSpecies(species),
                        locked: false,
                      ),
                      Divider(),
                      for (final species in course.lockedSpecies) _SpeciesItem(
                        species: species,
                        knowledge: snapshot.data.ofSpecies(species),
                        locked: false,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: RaisedButton(
                    visualDensity: VisualDensity(horizontal: VisualDensity.maximumDensity, vertical: VisualDensity.maximumDensity),
                    onPressed: () { _startQuiz(course); },
                    child: Text(strings.startQuiz.toUpperCase()),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _startQuiz(Course course) async {
    unawaited(_userDb.markProfileUsed(widget.profile));
    final appDb = Provider.of<AppDb>(context, listen: false);
    final quiz = await createQuiz(appDb, _userDb, course);
    final quizPageResult = await Navigator.of(context).push(QuizRoute(widget.profile, course, quiz));
    unawaited(_loadKnowledge());
//    if (await maybeUnlockNextLesson(_userDb, course, quiz)) {
//      setState(() {});
//      // TODO show a nice message!
//    }
    if (quizPageResult is QuizPageResult && quizPageResult.restart) {
      unawaited(_startQuiz(course));
    }
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
          if (knowledge != null) _StarRating(
            starCount: 5,
            filledHalfStars: knowledge.halfStars,
            size: 16.0,
          ),
          SizedBox(width: 16.0),
          Text(
            // TODO show star rating
            knowledge == null ? '' : '${(knowledge.halflifeDays * 24).toStringAsFixed(2)}h   ${(knowledge.recallProbability(DateTime.now()) * 100).toStringAsFixed(2)}%',
            // style: theme.textTheme.bodyText2.copyWith(fontWeight: FontWeight.bold, color: _percentageColor(knowledge.scorePercent.round())),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int starCount;
  final int filledHalfStars;
  final double size;
  final Color color;

  const _StarRating({Key key, @required this.starCount, @required this.filledHalfStars, this.size, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var i = 0; i < filledHalfStars ~/ 2; i++) Icon(
          Icons.star,
          color: color,
          size: size,
        ),
        if (filledHalfStars.isOdd) Icon(
          Icons.star_half,
          color: color,
          size: size,
        ),
        for (var i = (filledHalfStars + 1) ~/ 2; i < starCount; i++) Icon(
          Icons.star_border,
          color: color,
          size: size,
        )
      ],
    );
  }
}