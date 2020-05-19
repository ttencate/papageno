import 'package:flutter/material.dart';
import 'package:papageno/screens/course_page.dart';
import 'package:papageno/screens/create_course_page.dart';
import 'package:papageno/screens/settings_page.dart';

abstract class Routes {
  static const createCourse = '/createCourse';
  static const course = '/course';
  static const settings = '/settings';
}

final appRoutes = <String, WidgetBuilder>{
  Routes.createCourse: (context) => CreateCoursePage(),
  Routes.course: (context) => CoursePage(),
  Routes.settings: (context) => SettingsPage(),
};