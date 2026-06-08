$ErrorActionPreference = "Stop"

flutter pub get
dart run flutter_launcher_icons
flutter build apk

Write-Host ""
Write-Host "APK erstellt: build/app/outputs/flutter-apk/app-release.apk"
