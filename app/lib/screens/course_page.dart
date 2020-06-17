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
    final theme = Theme.of(context);
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
                    padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          strings.unlockedSpeciesHeading.toUpperCase(),
                          style: theme.textTheme.subtitle2,
                        ),
                      ),
                      for (final species in course.unlockedSpecies) _SpeciesItem(
                        species: species,
                        knowledge: snapshot.data.ofSpecies(species),
                        locked: false,
                      ),
                      SizedBox(height: 8.0),
                      Container(
                        color: Colors.grey.shade200,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 8.0),
                          child: Text(
                            strings.lockedSpeciesHeading.toUpperCase(),
                            style: theme.textTheme.subtitle2,
                          ),
                        ),
                      ),
                      for (final species in course.lockedSpecies) _SpeciesItem(
                        species: species,
                        knowledge: snapshot.data.ofSpecies(species),
                        locked: true,
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
    return Container(
      color: locked ? Colors.grey.shade200 : null,
      // Workaround for ink not appearing on Containers with a background color:
      // https://github.com/flutter/flutter/issues/3782#issuecomment-217566214
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () { _showDetailsDialog(context); },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    final settings = Provider.of<Settings>(context, listen: false);
    showDialog<void>(
      context: context,
      builder: (context) => _SpeciesDetailsDialog(species: species, knowledge: knowledge, settings: settings),
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

class _SpeciesDetailsDialog extends StatelessWidget {
  final Species species;
  final SpeciesKnowledge knowledge;
  final Settings settings;

  const _SpeciesDetailsDialog({Key key, @required this.species, @required this.knowledge, @required this.settings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final locale = WidgetsBinding.instance.window.locale;
    return AlertDialog(
      insetPadding: EdgeInsets.all(16.0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(
              species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
              softWrap: true,
            ),
          ),
          _StarRating(starCount: 5, filledHalfStars: knowledge.halfStars, size: 16.0),
        ],
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _KeyValueRow(
            keyText: strings.languageSettingName(settings.primarySpeciesLanguage.value).capitalize(),
            value: Text(species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(), softWrap: true),
          ),
          if (settings.secondarySpeciesLanguage.value != LanguageSetting.none) _KeyValueRow(
            keyText: strings.languageSettingName(settings.secondarySpeciesLanguage.value).capitalize(),
            value: Text(species.commonNameIn(settings.secondarySpeciesLanguage.value.resolve(locale)).capitalize(), softWrap: true),
          ),
          _KeyValueRow(
            keyText: strings.scientificName,
            value: Text(species.scientificName, softWrap: true, style: TextStyle(fontStyle: FontStyle.italic)),
          ),
          _KeyValueRow(
            keyText: strings.learningStats,
            value: Text(
                'α = ${knowledge.ebisuModel.alpha.toStringAsFixed(1)}, '
                'β = ${knowledge.ebisuModel.beta.toStringAsFixed(1)}, '
                'h = ${knowledge.ebisuModel.time.toStringAsFixed(4)}'),
          ),
        ],
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () { Navigator.of(context).pop(); },
          child: Text(strings.close.toUpperCase()),
        )
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String keyText;
  final Widget value;

  const _KeyValueRow({Key key, @required this.keyText, @required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            keyText.toUpperCase(),
            style: theme.textTheme.caption,
          ),
          value,
        ],
      ),
    );
  }
}