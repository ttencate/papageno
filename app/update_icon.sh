#!/usr/bin/env bash
cd "$(dirname "$0")"
inkscape --without-gui --export-area-page --export-png=artwork/icon.png artwork/icon.svg
flutter pub run flutter_launcher_icons:main
