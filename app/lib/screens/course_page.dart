import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/controller/course_controller.dart';
import 'package:papageno/controller/knowledge_controller.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/add_species_dialog.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/string_utils.dart';
import 'package:papageno/widgets/chain_item_builder.dart';
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
  CourseController _courseController;
  KnowledgeController _knowledgeController;

  @override
  void initState() {
    super.initState();
    _userDb = Provider.of<UserDb>(context, listen: false);
    _courseController = CourseController(course: widget.course, userDb: _userDb);
    _knowledgeController = KnowledgeController(profile: widget.profile, userDb: _userDb);
  }

  @override
  void dispose() {
    _knowledgeController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return ChangeNotifierProvider<Settings>.value(
      value: widget.profile.settings,
      child: StreamBuilder<Course>(
        stream: _courseController.courseUpdates,
        initialData: _courseController.course,
        builder: (context, snapshot) {
          final course = snapshot.data;
          final unlockedSpecies = course.unlockedSpecies.toSet();
          final lockedSpecies = course.localSpecies.where((s) => !unlockedSpecies.contains(s)).toList();
          return Scaffold(
            appBar: AppBar(
              title: Text(strings.courseNameOrLocation(course)),
            ),
            drawer: MenuDrawer(profile: widget.profile, course: widget.course),
            body: StreamBuilder<Knowledge>(
              stream: _knowledgeController.knowledgeUpdates,
              initialData: _knowledgeController.knowledge,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final knowledge = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                        itemBuilder: ChainItemBuilder(
                          sections: <ChainSection>[
                            ChainSection.single(
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text(
                                  strings.unlockedSpeciesHeading(course.unlockedSpecies.length).toUpperCase(),
                                  style: theme.textTheme.subtitle2,
                                ),
                              ),
                            ),
                            ChainSection.listBuilder<Species>(
                              course.unlockedSpecies,
                              (context, species) =>_SpeciesItem(
                                species: species,
                                knowledge: knowledge.ofSpeciesOrNone(species),
                                locked: false,
                              ),
                            ),
                            ChainSection.single(
                              FlatButton(
                                onPressed: () { _addMoreSpecies(course); },
                                child: Text(strings.addSpeciesButton.toUpperCase()),
                              ),
                            ),
                            ChainSection.single(
                              SizedBox(height: 8.0),
                            ),
                            ChainSection.single(
                              Container(
                                color: Colors.grey.shade200,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 8.0),
                                  child: Text(
                                    strings.lockedSpeciesHeading(lockedSpecies.length).toUpperCase(),
                                    style: theme.textTheme.subtitle2,
                                  ),
                                ),
                              ),
                            ),
                            ChainSection.listBuilder<Species>(
                              lockedSpecies,
                              (context, species) => _SpeciesItem(
                                species: species,
                                knowledge: knowledge.ofSpeciesOrNull(species),
                                locked: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Material(
                      elevation: 16.0,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Center(
                          child: RaisedButton(
                            visualDensity: VisualDensity(horizontal: VisualDensity.maximumDensity, vertical: VisualDensity.maximumDensity),
                            onPressed: course.unlockedSpecies.isEmpty ? null : () { _startQuiz(course); },
                            child: Text(strings.startQuiz.toUpperCase()),
                          ),
                        ),
                      ),
                    )
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _startQuiz(Course course) async {
    // TODO move into a controller, then stop storing _userDb
    unawaited(_userDb.markProfileUsed(widget.profile));

    final quizPageResult = await Navigator.of(context).push(QuizRoute(widget.profile, _knowledgeController, course)) ?? AfterQuizOption.stop;

    switch (quizPageResult) {
      case AfterQuizOption.stop:
        break;
      case AfterQuizOption.retry:
        unawaited(_startQuiz(course));
        break;
      case AfterQuizOption.addSpecies:
        unawaited(_addMoreSpecies(course));
        break;
    }
  }

  Future<void> _addMoreSpecies(Course course) async {
    final newSpecies = await showDialog<List<Species>>(
      context: context,
      builder: (context) => AddSpeciesDialog(course: course, settings: widget.profile.settings),
    );
    if (newSpecies != null) {
      await _courseController.addSpecies(newSpecies);
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
                  starCount: SpeciesKnowledge.maxStarCount,
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

class _SpeciesDetailsDialog extends StatefulWidget {
  final Species species;
  final SpeciesKnowledge knowledge;
  final Settings settings;

  const _SpeciesDetailsDialog({Key key, @required this.species, @required this.knowledge, @required this.settings}) : super(key: key);

  @override
  State<_SpeciesDetailsDialog> createState() => _SpeciesDetailsDialogState();
}

class _SpeciesDetailsDialogState extends State<_SpeciesDetailsDialog> {
  Future<String> _confusionSpecies;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appDb = Provider.of<AppDb>(context);
    final locale = WidgetsBinding.instance.window.locale;
    _confusionSpecies = () async {
      final counts = <int, int>{};
      for (final speciesId in widget.knowledge?.confusionSpeciesIds ?? <int>[]) {
        counts.update(speciesId, (c) => c + 1, ifAbsent: () => 1);
      }
      counts.remove(widget.species.speciesId);
      final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      final speciesEntries = await Future.wait(entries.map((entry) async => MapEntry(await appDb.species(entry.key), entry.value)));
      final result = speciesEntries
          .where((MapEntry<Species, int> entry) => entry.key != null)
          .map((entry) => '${entry.key.commonNameIn(widget.settings.primarySpeciesLanguage.value.resolve(locale)).capitalize()} (${entry.value}×)')
          .join(', ');
      return result.isEmpty ? '—' : result;
    }();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final locale = WidgetsBinding.instance.window.locale;
    final now = DateTime.now();
    return AlertDialog(
      insetPadding: EdgeInsets.all(16.0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(
              widget.species.commonNameIn(widget.settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(),
              softWrap: true,
            ),
          ),
          if (widget.knowledge != null) _StarRating(starCount: 5, filledHalfStars: widget.knowledge.halfStars, size: 16.0),
        ],
      ),
      scrollable: true,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.knowledge != null && widget.knowledge.halfStars < SpeciesKnowledge.maxHalfStarCount) Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                strings.starRatingExplanation,
                style: theme.textTheme.caption,
              ),
            ),
            _KeyValueRow(
              keyText: strings.languageSettingName(widget.settings.primarySpeciesLanguage.value).capitalize(),
              value: Text(widget.species.commonNameIn(widget.settings.primarySpeciesLanguage.value.resolve(locale)).capitalize(), softWrap: true),
            ),
            if (widget.settings.secondarySpeciesLanguage.value != LanguageSetting.none) _KeyValueRow(
              keyText: strings.languageSettingName(widget.settings.secondarySpeciesLanguage.value).capitalize(),
              value: Text(widget.species.commonNameIn(widget.settings.secondarySpeciesLanguage.value.resolve(locale)).capitalize(), softWrap: true),
            ),
            _KeyValueRow(
              keyText: strings.scientificName,
              value: Text(widget.species.scientificName, softWrap: true, style: TextStyle(fontStyle: FontStyle.italic)),
            ),
            if (widget.knowledge != null) _KeyValueRow(
              keyText: strings.confusedWith,
              value: FutureBuilder<String>(
                future: _confusionSpecies,
                builder: (context, snapshot) => Text(snapshot.data ?? '…'),
              ),
            ),
            if (widget.knowledge?.model != null) _KeyValueRow(
              keyText: strings.learningStats,
              value: Text(
                  'α = ${widget.knowledge.model.alpha.toStringAsFixed(1)}, '
                  'β = ${widget.knowledge.model.beta.toStringAsFixed(1)}, '
                  't = ${widget.knowledge.model.time.toStringAsFixed(4)}\n'
                  'h = ${widget.knowledge.model.modelToPercentileDecay(percentile: 0.5).toStringAsFixed(4)}, '
                  'Δ = ${widget.knowledge.daysSinceAsked(now).toStringAsFixed(3)}, '
                  'p = ${(widget.knowledge.recallProbability(now) * 100).toStringAsFixed(2)}%'),
            ),
          ],
        ),
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