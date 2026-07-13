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

## GPS-State0 Web-Build - 09.07.2026

Die Logs `logs_78453450581.zip` und `logs_78453450581(1).zip` enthielten für amd64 und arm64 denselben abbrechenden Dart-Compilerfehler:

```text
lib/screens/gps_state.dart:1399:16: Error: '_state0DecisionRow' is already declared in this scope.
lib/screens/gps_state.dart:1376:10: Error: A value of type 'List<dynamic>' can't be returned from a function with return type 'List<_DecisionRow>'.
```

Ursache war eine Namenskollision zwischen dem Widget-Builder für eine sichtbare State0-Zeile und der Hilfsfunktion zum Erzeugen des zugehörigen `_DecisionRow`-Datenobjekts. Dadurch konnte Dart den Aufruf im `map` nicht eindeutig typisieren.

Umgesetzt:

- Daten-Hilfsfunktion eindeutig in `_buildState0DecisionRowData` umbenannt.
- `map<_DecisionRow>` explizit typisiert, sodass die Rückgabe garantiert `List<_DecisionRow>` bleibt.
- Klammerbilanz und eindeutige Methodendeklarationen statisch geprüft.

Die Hinweise zu WebAssembly/`dart:html`, Windows-Anforderungen sowie GitHub-Actions-Deprecations waren Warnungen und nicht die Ursache des fehlgeschlagenen Web-Builds.

## Web-Dateiimport - FileReader-Buildfehler - 11.07.2026

Die Logs `logs_78925048811.zip` enthielten fuer amd64 und arm64 denselben abbrechenden Dart2JS-Fehler:

```text
lib/services/platform_text_file_web.dart:64:12:
Error: The getter 'onError' isn't defined for the type 'FileReader'.
    reader.onError.listen((_) {
           ^^^^^^^
```

Ursache war die Umstellung des Web-Dateizugriffs von `dart:html` auf `package:web`. Fuer `FileReader` stellt `package:web` den Stream `onLoadEnd` bereit, aber keinen Stream-Getter `onError`. Ein Lesefehler kann nach dem `loadend`-Ereignis ueber `FileReader.error` erkannt werden.

Umgesetzt:

- Nicht vorhandenen Aufruf `reader.onError.listen(...)` entfernt.
- Fehlerauswertung in den vorhandenen `reader.onLoadEnd`-Handler verlagert.
- Bei `reader.error != null` wird der bestehende deutsche Lesefehler als Future-Fehler weitergegeben.
- Erfolgreiche Textdateiimporte und die bisherige Validierung des Rueckgabetyps bleiben unveraendert.

Die WebAssembly-Meldung zu `get_storage` ist weiterhin nur ein Hinweis aus dem optionalen Wasm-Dry-Run und war nicht die Ursache des fehlgeschlagenen Dart2JS-Web-Builds.
