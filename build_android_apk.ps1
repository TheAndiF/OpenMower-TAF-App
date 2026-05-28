$ErrorActionPreference = "Stop"

flutter pub get
flutter build apk

Write-Host ""
Write-Host "APK erstellt: build/app/outputs/flutter-apk/app-release.apk"
