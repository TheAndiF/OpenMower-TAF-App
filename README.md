# OpenMower TAF App

**Dokumentation:** [Startseite](https://theandif.github.io/OpenMower-TAF-App/) · [Bedienungsanleitung](https://theandif.github.io/OpenMower-TAF-App/bedienungsanleitung/) · [Privacy](https://theandif.github.io/OpenMower-TAF-App/google-play/privacy.html) · [PDF-Anleitung](https://theandif.github.io/OpenMower-TAF-App/assets/OpenMower_App_Bedienungsanleitung_Unterseiten.pdf)

OpenMower TAF App ist eine erweiterte Flutter-Oberfläche für ein OpenMower-System. Die App verbindet sich mit dem OpenMower-Backend über MQTT und stellt Dashboard, Sensordaten, Zeitplan, Flächenverwaltung, Protokollanzeige sowie Hardware- und Softwareeinstellungen in einer gemeinsamen Oberfläche bereit.

> Hinweis: Dieses Repository enthält die App-Oberfläche. Für den Mähbetrieb wird ein kompatibles OpenMower-System mit laufendem `open_mower_ros` benötigt.

## Dokumentation

Die Dokumentation liegt im Repository unter `docs/` und ist bei aktivierten GitHub Pages auch direkt im Browser erreichbar.

- [Dokumentations-Startseite](https://theandif.github.io/OpenMower-TAF-App/)
- [Bedienungsanleitung](https://theandif.github.io/OpenMower-TAF-App/bedienungsanleitung/)
- [Bedienungsanleitung als PDF](https://theandif.github.io/OpenMower-TAF-App/assets/OpenMower_App_Bedienungsanleitung_Unterseiten.pdf)
- [Datenschutzerklärung / Privacy](https://theandif.github.io/OpenMower-TAF-App/google-play/privacy.html)

Die gleichen Inhalte sind lokal im Repository erreichbar:

- [Bedienungsanleitung](docs/bedienungsanleitung.md)
- [PDF-Anleitung](docs/assets/OpenMower_App_Bedienungsanleitung_Unterseiten.pdf)
- [Privacy-Seite](docs/google-play/privacy.html)

## GitHub About ausfüllen

Für den rechten GitHub-Bereich **About** kann die Datei [`GITHUB_ABOUT_SETTINGS.md`](GITHUB_ABOUT_SETTINGS.md) verwendet werden. Dort stehen Description, Website-Link und optionale Topics. Da GitHub im About-Bereich nur ein Website-Feld anbietet, sollte dort die Dokumentations-Startseite eingetragen werden. Von dieser Startseite sind Bedienungsanleitung und Privacy klickbar erreichbar.

## Was kann die App?

Die App dient zur Bedienung, Überwachung und Konfiguration eines OpenMower-Systems. Sie ist nicht nur eine einfache Statusanzeige, sondern bündelt mehrere Bedien- und Diagnosebereiche.

### Dashboard

Das Dashboard zeigt den aktuellen Roboterzustand, die Karte mit Flächen, Hindernissen und Positionsinformationen sowie direkte Steueraktionen. Darüber können unter anderem Start, Stop und Area Recording bedient werden. Die Karte kann verschoben und gezoomt werden.

### Advanced Options

Die Seite `Advanced Options` enthält erweiterte Aktionen für Mählogik und manuelle Flächensteuerung. Sie ist für Funktionen gedacht, die nicht auf dem Hauptdashboard liegen sollen, aber im Betrieb oder bei Tests schnell erreichbar sein müssen.

### Sensor Values

Die Sensorseite zeigt Diagnosewerte wie GPS-Genauigkeit, Akkuspannung, Ladespannung, Ladestrom, Mähmotor-Drehzahl, Motorstrom und Temperaturen von Motor und ESCs. Sie hilft bei der Fehlersuche, zum Beispiel bei Ladeproblemen, GPS-Problemen, Überlast oder Temperaturauffälligkeiten.

### Timetable

Die Zeitplanseite verwaltet die Mähzeiten. Mähfenster können pro Wochentag gesetzt, aktiviert, deaktiviert, bearbeitet oder gelöscht werden. Zusätzlich kann der automatische Mähbetrieb temporär für einen Tag, drei Tage oder unbestimmt ausgesetzt werden.

### Flächen

Die Flächenseite zeigt die bekannten Mähflächen, deren Namen, Aktivstatus und Mähreihenfolge. Flächen können verwaltet, übersprungen und als JSON exportiert oder importiert werden. Dadurch ist eine Sicherung und Wiederherstellung der Flächendaten möglich.

### Protokoll

Die Protokollseite zeigt Statuswechsel des Roboters, zum Beispiel `MOWING → PAUSED` oder `DOCKING → IDLE`. Zu jedem Eintrag werden Kontextdaten wie Akku, GPS, Position, Temperaturen und Automow-Informationen angezeigt. Das erleichtert die Analyse von Fehlern und ungewöhnlichen Abläufen.

### Einstellungen Hardware

Die Hardwareeinstellungen verwalten Grenzwerte und Schutzparameter des Low-Level-Boards. Dazu gehören zum Beispiel kritische Akku- und Ladespannungen oder Ladestromgrenzen. Änderungen sollten nur vorgenommen werden, wenn die Auswirkung bekannt ist.

### Einstellungen Software

Die Softwareeinstellungen verwalten Parameter der Mäherlogik. Die Werte sind in Gruppen wie `mower_logic`, `Mowing`, `Rain`, `Docking`, `Emergency`, `GPS`, `Load_Factor`, `path_order_optimizer` und `Undocking` organisiert. Der Expertenmodus blendet zusätzliche Metadaten und erweiterte Optionen ein.

### Flächeneditor

Der Flächeneditor ist eine eigene Unterseite zum Bearbeiten von Polygonen. Er ist getrennt von Dashboard und Flächenübersicht, damit die normale Bedienung nicht durch den Editor blockiert wird. Bearbeiten, Rückgängig, Verwerfen, Speichern, Mehrfachauswahl, Punkte abwählen und Punkt löschen sind als eigene Werkzeuge vorgesehen.

## Unterschiede zur bisherigen OpenMower-App

Diese Variante erweitert die bisherige OpenMower-Oberfläche vor allem in Bedienung, Diagnose und Verwaltung:

- eigene Unterseiten für Dashboard, Advanced Options, Sensor Values, Timetable, Flächen, Protokoll, Hardwareeinstellungen, Softwareeinstellungen und Flächeneditor
- Wisch-Navigation durch die wichtigsten Hauptseiten in der App-Variante
- getrennte Flächenverwaltung und separater Flächeneditor
- erweiterte JSON-Funktionen für Flächenimport, Flächenexport und Speichern
- eigene Protokollansicht für Statuswechsel und Fehleranalyse
- deutlich ausgebaute Hardware- und Softwareparameterseiten
- angepasste OpenMower-TAF-Optik mit OpenMower-Logo und eigener Farbgestaltung
- Datenschutzseite und Bedienungsanleitung als GitHub-Pages-Unterseiten

## Benötigte ROS-Version

OpenMower setzt auf `open_mower_ros` und benötigt ROS Noetic. ROS Noetic ist ROS 1 und wird typischerweise mit Ubuntu 20.04 verwendet.

Für den produktiven Einsatz sollte die App zu der OpenMower-/`open_mower_ros`-Version passen, die auf dem Mäher beziehungsweise im Docker-Setup läuft. Die App kommuniziert über die vom Backend bereitgestellten MQTT-Topics und erwartet die passenden JSON-/BSON-Strukturen.

## Build & Deploy

### Voraussetzungen

- Flutter SDK
- ein geklontes `open_mower_ros`-Repository im übergeordneten Ordner
- kompatibles OpenMower-Backend mit MQTT-Anbindung

Beispielstruktur:

```text
parent-folder/
├── OpenMower-TAF-App/
└── open_mower_ros/
```

`open_mower_ros` kann beispielsweise so geklont werden:

```bash
cd ..
git clone git@github.com:ClemensElflein/open_mower_ros.git
```

### Build ausführen

```bash
./build_and_deploy.sh
```

Das Skript baut die Flutter-Web-App und kopiert das Ergebnis in den `web`-Ordner des benachbarten `open_mower_ros`-Repositorys.

## GitHub Pages

Die Dokumentation liegt im Ordner `docs/`. Für GitHub Pages kann in den Repository-Einstellungen als Quelle der Branch `main` und der Ordner `/docs` gewählt werden.

Danach sind Bedienungsanleitung und Datenschutzseite direkt als Unterseiten des Repositories erreichbar.

## Sicherheitshinweis

Die App kann Mähbetrieb starten, stoppen und Konfigurationswerte verändern. Vor Änderungen an Hardware- oder Softwareparametern sollten die aktuellen Werte gesichert und die Bedeutung der Parameter geprüft werden. Falsche Grenzwerte können zu unerwartetem Verhalten führen.
