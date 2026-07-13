# OpenMower-TAF-App - GPS-State JSON-Download UI-Angleichung

**Datum:** 2026-07-13  
**Version:** v0.10  
**Status:** In Prüfung  
**Projekt:** OpenMower-TAF-App

## Ziel

Der JSON-Download auf der GPS-State-Seite soll dem bereits bekannten Bedienmuster der Flächenseite möglichst genau entsprechen. Dadurch befinden sich gleichartige Funktionen an derselben Stelle und verwenden dieselbe Beschriftung.

## Umsetzung

- Die bisherige Kopfaktion **JSON-Snapshot** wurde entfernt.
- Der Download befindet sich jetzt im Abschnitt **JSON-Ansicht**.
- Desktop: rechts im Abschnittskopf als umrandete Schaltfläche **Download** mit Download-Symbol.
- Mobile: unter der Überschrift als breite Schaltfläche **Herunterladen**.
- Farbe, Abschnittsaufbau und Auf-/Zuklapp-Schaltfläche orientieren sich an der JSON-Ansicht der Flächenseite.
- Der bestehende Snapshot-Inhalt, Zeitstempel im Dateinamen, Doppelklickschutz und die Trennung vom MQTT-Refresh bleiben unverändert.
- Ein Quelltextkommentar dokumentiert die beabsichtigte UI-Konsistenz zur Flächenseite.

## Geänderte Dateien

- `lib/screens/gps_state.dart`
- `docs/bedienungsanleitung.md`
- `docs/mqtt-schnittstelle.md`

## Prüfung

- Klammer- und Strukturprüfung der geänderten Dart-Datei: bestanden.
- Whitespace-Prüfung mit `git diff --check`: bestanden.
- ZIP-Integritätsprüfung: bestanden; `unzip -t` meldet keine Fehler und der Root-Ordner bleibt `OpenMower-TAF-App`.
- Flutter-/Dart-Build: in der Bearbeitungsumgebung nicht möglich, weil Flutter- und Dart-SDK nicht installiert sind.
