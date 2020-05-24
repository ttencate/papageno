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

Releasing
---------

### Android

Signing configuration should be present in `android/key.properties` as per
[the Flutter deployment guide](https://flutter.dev/docs/deployment/android#reference-the-keystore-from-the-app).

We use the new
[Android App Bundles](https://developer.android.com/guide/app-bundle#size_restrictions)
delivery method, combined with
[Dynamic Asset Delivery](https://developer.android.com/guide/app-bundle/asset-delivery)
because the assets weigh about 300 MB, but APKs are limited to 100 MB and App
Bundles to 150 MB. Flutter
[has no support for this yet](https://github.com/flutter/flutter/issues/43548)
so we wrapped the Android API for it ourselves.
