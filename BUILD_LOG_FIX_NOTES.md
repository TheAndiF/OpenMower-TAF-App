# Build-Log-Fixes

Stand: 08.06.2026

Die aktuellen GitHub-Actions-Logs wurden berücksichtigt.

## Android-Build

Fehler aus den Logs:

```text
Execution failed for task ':app:checkDebugAarMetadata'.
Dependency 'androidx.browser:browser:1.9.0' requires Android Gradle plugin 8.9.1 or higher.
Dependency 'androidx.core:core-ktx:1.17.0' requires Android Gradle plugin 8.9.1 or higher.
Dependency 'androidx.core:core:1.17.0' requires Android Gradle plugin 8.9.1 or higher.
This build currently uses Android Gradle plugin 8.7.3.
```

Umgesetzt:

- Android Gradle Plugin in `android/settings.gradle` von `8.7.3` auf `8.11.1` angehoben.
- Kotlin Gradle Plugin in `android/settings.gradle` von `2.1.0` auf `2.2.20` angehoben.
- Gradle Wrapper in `android/gradle/wrapper/gradle-wrapper.properties` von `8.10.2` auf `8.14.3` angehoben.

## Docker/Web-Build

Der vorherige Fehler bei `dart run flutter_launcher_icons` im Docker/Web-Build wurde weiterhin berücksichtigt:

- `flutter_launcher_icons_web.yaml` erzeugt nur Web-Icons.
- `Dockerfile` nutzt `dart run flutter_launcher_icons -f flutter_launcher_icons_web.yaml`.

## GitHub Actions / Node

Die Workflows enthalten weiterhin:

```yaml
FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

Damit wird die Node-20-Deprecation-Warnung der GitHub Actions berücksichtigt.
