#!/usr/bin/env bash
set -euo pipefail

flutter pub get
dart run flutter_launcher_icons
flutter build apk

echo ""
echo "APK erstellt: build/app/outputs/flutter-apk/app-release.apk"
