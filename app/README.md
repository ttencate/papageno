Papageno: Birdsong Tutor
========================

This directory contains the Flutter project for the Papageno mobile app.

Getting started with Flutter
----------------------------

This project is a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view the
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

Debugging tricks
----------------

To drop into an SQLite shell running on the device (only works for debug builds
of the app):

    $ adb shell -t run-as com.frozenfractal.papageno sqlite3 databases/user.db
