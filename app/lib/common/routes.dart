/// Contains the routes used in the application.
/// We don't use named routes, because frankly, they are a silly thing from web development land.
/// Using a class for each route type is much nicer!

import 'package:flutter/material.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/screens/about_page.dart';
import 'package:papageno/screens/course_page.dart';
import 'package:papageno/screens/courses_page.dart';
import 'package:papageno/screens/create_course_page.dart';
import 'package:papageno/screens/profiles_page.dart';
import 'package:papageno/screens/quiz_page.dart';
import 'package:papageno/screens/settings_page.dart';

class ProfilesRoute extends MaterialPageRoute<void> {
  ProfilesRoute({bool proceedAutomatically = false}) :
      super(builder: (context) => ProfilesPage(proceedAutomatically: proceedAutomatically));
}

class CoursesRoute extends MaterialPageRoute<void> {
  CoursesRoute(Profile profile, {bool proceedAutomatically = false}) :
      super(builder: (context) => CoursesPage(profile, proceedAutomatically: proceedAutomatically));
}

class CreateCourseRoute extends MaterialPageRoute<Course> {
  CreateCourseRoute(Profile profile) :
      super(builder: (context) => CreateCoursePage(profile));
}

class CourseRoute extends MaterialPageRoute<void> {
  CourseRoute(Profile profile, Course course) :
      super(builder: (context) => CoursePage(profile, course));
}

class QuizRoute extends MaterialPageRoute<QuizPageResult> {
  QuizRoute(Profile profile, Course course, Quiz quiz) :
      super(builder: (context) => QuizPage(profile, course, quiz));
}

class SettingsRoute extends MaterialPageRoute<void> {
  SettingsRoute(Settings settings) :
      super(builder: (context) => SettingsPage(settings));
}

class AboutRoute extends MaterialPageRoute<void> {
  AboutRoute() :
      super(builder: (context) => AboutPage());
}