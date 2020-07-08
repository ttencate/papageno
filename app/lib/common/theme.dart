import 'package:flutter/material.dart';

final appTheme = ThemeData(
  brightness: Brightness.light,
  // Circle in icon: green 500 - green 900.
  primarySwatch: Colors.green,
  primaryColor: Colors.green.shade800,
  primaryColorLight: Colors.green.shade500,
  primaryColorDark: Colors.green.shade900,
  primaryColorBrightness: Brightness.dark,
  // Question mark in icon: yellow 500 - yellow 800.
  // Using the dark end because it needs to contrast well with white.
  accentColor: Colors.yellow.shade800,
  accentColorBrightness: Brightness.light,
  buttonTheme: ButtonThemeData(
    buttonColor: Colors.green.shade600,
    textTheme: ButtonTextTheme.primary,
  ),
  iconTheme: IconThemeData(
    color: Colors.green.shade500,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.green.shade800,
    foregroundColor: Colors.white,
  ),
);