import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/common/strings_extensions.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:provider/provider.dart';

class CoursesPage extends StatefulWidget {
  final Profile profile;

  const CoursesPage(this.profile);

  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  UserDb _userDb;

  Future<List<Course>> _courses;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userDb = Provider.of<UserDb>(context);
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() { _courses = _userDb.courses(widget.profile.profileId); });
    await _courses;
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
                      title: Text(strings.courseName(course)),
                      subtitle: Text(strings.lessonCount(course.lessons.length, course.speciesCount)),
                      onTap: () { _openCourse(course); },
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () { _maybeDeleteCourse(course); },
                      ),
                    ),
                  ]).toList(),
                ) :
                Center(child: CircularProgressIndicator())
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: RaisedButton(
              child: Text(strings.startCreatingCourseButton.toUpperCase()),
              onPressed: _createCourse,
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

  void _openCourse(Course course) {
    Navigator.of(context).push(CourseRoute(widget.profile, course));
  }

  Future<void> _maybeDeleteCourse(Course course) async {
    final strings = Strings.of(context);
    final reallyDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(strings.deleteCourseConfirmation(strings.courseName(course))),
        actions: <Widget>[
          FlatButton(
            child: Text(strings.no.toUpperCase()),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FlatButton(
            child: Text(strings.yes.toUpperCase()),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
    if (reallyDelete) {
      await _userDb.deleteCourse(course);
      await _loadCourses();
    }
  }
}