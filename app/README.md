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

To build the app bundle:

    $ flutter build appbundle

To build APKs out of this bundle for testing (needs
[bundletool](https://developer.android.com/studio/command-line/bundletool)):

    # Note: resulting APKS are signed with a debug key; not suitable for deployment.
    $ bundletool build-apks --bundle build/app/outputs/bundle/release/app-release.aab --output /tmp/papageno.apks

To measure the size of the resulting APKs:

    $ bundletool get-size total --apks=/tmp/set.apks

The MAX must remain below 150 MB for the app bundle to be accepted by the Play
Store. Whether this is binary megabytes (1024² bytes) or SI megabytes (1000²
bytes) is unknown.

To test the built app on a connected device:

    $ bundletool install-apks --apks /tmp/papageno.apks
