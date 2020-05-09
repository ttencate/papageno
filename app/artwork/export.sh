#!/usr/bin/env bash
cd "$(dirname "$0")/.."

# Used as source for flutter_launcher_icons
inkscape --without-gui --export-area-page --export-png=artwork/icon.png artwork/icon.svg
flutter pub run flutter_launcher_icons:main

# Used in the splash screen; currently the same source file as the icon
inkscape --without-gui --export-area-page --export-png=assets/logo.png --export-width=512 --export-height=512 artwork/icon.svg

# Used in question screens
inkscape --without-gui --export-area-page --export-png=assets/question.png artwork/question.svg
