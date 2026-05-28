#!/usr/bin/env bash
set -euo pipefail

flutter pub get
flutter build apk

echo ""
echo "APK erstellt: build/app/outputs/flutter-apk/app-release.apk"
