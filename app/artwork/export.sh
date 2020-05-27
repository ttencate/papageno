#!/usr/bin/env bash
cd "$(dirname "$0")/.."

# Used as source for flutter_launcher_icons
inkscape --export-area-page --export-filename=artwork/icon.png artwork/icon.svg
flutter pub run flutter_launcher_icons:main

# Used in the splash screen; currently the same source file as the icon
inkscape --export-area-page --export-filename=assets/logo.png --export-width=512 --export-height=512 artwork/icon.svg

# Used in question screens
inkscape --export-area-page --export-filename=assets/question.png artwork/question.svg

# Google Play Store
inkscape --export-area-page --export-filename=artwork/play_store/icon.png artwork/play_store/icon.svg
inkscape --export-area-page --export-filename=artwork/play_store/feature_graphic.png artwork/play_store/feature_graphic.svg
