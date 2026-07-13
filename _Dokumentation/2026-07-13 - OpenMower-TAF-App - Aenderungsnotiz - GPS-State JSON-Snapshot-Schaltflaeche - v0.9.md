# OpenMower-TAF-App – GPS-State JSON-Snapshot-Schaltfläche

**Datum:** 2026-07-13  
**Version:** v0.9  
**Bereich:** GPS-State-Unterseite

## Änderung

Im Kopfbereich der GPS-State-Seite wurde eine deutlich sichtbare Schaltfläche **JSON-Snapshot** ergänzt. Der Export wird genau beim Betätigen der Schaltfläche erzeugt und speichert den zu diesem Zeitpunkt lokal in der App vorhandenen Datenstand.

## Inhalt des Snapshots

- GPS-State-Settings einschließlich Metadaten
- Definition und Status von State0 bis State4
- zugehörige MQTT-Topics und Empfangszeitpunkte
- Settings-Validierung
- F9P-Neustartstatus und Neustartvalidierung
- letzter App-Status und letztes Topic
- State0-Aktualisierungszustand
- noch nicht gespeicherte Einstellungsentwürfe

## Verhalten

Der Snapshot löst bewusst keine zusätzliche MQTT-Anfrage aus. Dadurch bleibt eindeutig nachvollziehbar, welche Daten zum Klickzeitpunkt bereits in der App vorlagen. Für einen vorherigen Neuabruf kann weiterhin **Status neu laden** verwendet werden.

## Dateiname

`openmower-gps-state-snapshot-YYYY-MM-DD_HH-mm-ss.json`

## Geänderte Dateien

- `lib/screens/gps_state.dart`
- `lib/controllers/gps_state_controller.dart`
- `docs/bedienungsanleitung.md`
- `docs/mqtt-schnittstelle.md`
