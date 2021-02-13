import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/widgets/confirmation_dialog.dart';
import 'package:papageno/widgets/egg_progress_indicator.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:provider/provider.dart';

class CoursesPage extends StatefulWidget {
  final Profile profile;
  final bool proceedAutomatically;

  const CoursesPage(this.profile, {this.proceedAutomatically = false});

  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  UserDb _userDb;

  Future<List<Course>> _courses;
  bool _proceedAutomatically;

  @override
  void initState() {
    super.initState();
    _proceedAutomatically = widget.proceedAutomatically;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userDb = Provider.of<UserDb>(context);
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() { _courses = _userDb.courses(widget.profile.profileId); });
    final courses = await _courses;
    if (_proceedAutomatically) {
      _proceedAutomatically = false;
      if (courses.isEmpty) {
        _createCourse(); // ignore: unawaited_futures
      } else if (courses.length == 1) {
        _openCourse(courses.single); // ignore: unawaited_futures
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.courses),
      ),
      drawer: MenuDrawer(profile: widget.profile),
      body: Column(
        children: <Widget>[
          Expanded(
            child: FutureBuilder<List<Course>>(
              future: _courses,
              builder: (context, snapshot) =>
                snapshot.hasData ?
                ListView(
                  children: ListTile.divideTiles(context: context, tiles: <Widget>[
                    for (final course in snapshot.data) ListTile(
                      title: Text(strings.courseNameOrLocation(course)),
                      subtitle: Text(strings.courseDetails(course.unlockedSpecies.length, course.localSpecies.length)),
                      onTap: () { _openCourse(course); },
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () { _editCourse(course); },
                      ),
                    ),
                  ]).toList(),
                ) :
                Center(child: EggProgressIndicator())
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: RaisedButton(
              onPressed: _createCourse,
              child: Text(strings.startCreatingCourseButton.toUpperCase()),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _createCourse() async {
    final course = await Navigator.of(context).push(CreateCourseRoute(widget.profile));
    if (course != null) {
      await _loadCourses();
      _openCourse(course);
    }
  }

  Future<void> _editCourse(Course course) async {
    final result = await showDialog<_CourseDialogResult>(
      context: context,
      builder: (BuildContext context) => _CourseDialog(course: course),
    );
    if (result == null) {
      return;
    }
    if (result.name != null) {
      await _userDb.renameCourse(course.courseId, result.name);
      await _loadCourses();
    } else if (result.delete) {
      await _maybeDeleteCourse(course);
    }
  }

  void _openCourse(Course course) {
    Navigator.of(context).push(CourseRoute(widget.profile, course));
  }

  Future<void> _maybeDeleteCourse(Course course) async {
    final strings = Strings.of(context);
    final reallyDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ConfirmationDialog(
        content: Text(strings.deleteCourseConfirmation(strings.courseNameOrLocation(course))),
      ),
    ) ?? false;
    if (reallyDelete) {
      await _userDb.deleteCourse(course);
      await _loadCourses();
    }
  }
}

@immutable
class _CourseDialogResult {
  final String name;
  final bool delete;

  _CourseDialogResult({this.name, this.delete});
}

class _CourseDialog extends StatefulWidget {
  final Course course;

  const _CourseDialog({Key key, this.course}) : super(key: key);

  @override
  State<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<_CourseDialog> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strings = Strings.of(context);
    if (_controller.text.isEmpty) {
      _controller.text = strings.courseNameOrLocation(widget.course);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(strings.editCourseTitle),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(_CourseDialogResult(delete: true)),
            icon: Icon(Icons.delete),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: strings.courseNameLabel.toUpperCase(),
          hintText: strings.courseNamePlaceholder,
        ),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel.toUpperCase()),
        ),
        FlatButton(
          onPressed: () => Navigator.of(context).pop(_CourseDialogResult(name: _controller.text)),
          child: Text(strings.ok.toUpperCase()),
        ),
      ],
    );
  }
}