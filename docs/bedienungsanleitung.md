---
layout: default
title: Bedienungsanleitung der App-Unterseiten
permalink: /bedienungsanleitung/
---

# Bedienungsanleitung der OpenMower App-Unterseiten

Diese Anleitung beschreibt die sichtbaren Unterseiten der OpenMower TAF App. Zu jeder beschriebenen Unterseite ist ein Screenshot enthalten. Die Anleitung erklärt den Zweck der Seite, wichtige Bedienelemente und die typische Bedienung.

## Gültigkeit / Release-Bezug

Diese Anleitung bezieht sich auf folgenden Stand:

- **App:** OpenMower-TAF-App `1.0.0+1`
- **ROS:** OpenMower mit **ROS Noetic / ROS 1**
- **Dokustand:** 08.06.2026

Wenn App- oder ROS-Stand abweichen, können Bezeichnungen, Funktionen oder Positionen einzelner Bedienelemente leicht unterschiedlich sein.

## Schnelle Links

- [PDF-Version herunterladen](../assets/OpenMower_App_Bedienungsanleitung_Unterseiten.pdf)
- [Zur Dokumentations-Startseite](../)
- [Privacy / Datenschutz](../google-play/privacy.html)

---

## Dashboard

![Screenshot Dashboard](../assets/screenshots/dashboard.png)

**Wofür ist diese Seite gedacht?**

Das Dashboard ist die zentrale Betriebsseite der App. Hier wird kontrolliert, ob der Mäher erreichbar ist, in welchem Zustand er sich befindet und wie die aktuelle Flächensituation aussieht.

**Wichtige Bedienelemente und Anzeigen**
- `Current State` zeigt den gemeldeten Hauptzustand, zum Beispiel `IDLE`, `MOWING`, `PAUSED` oder `DOCKING`.
- Der Kartenbereich zeigt Mähflächen, Hindernisse, Punkte und – sofern vorhanden – die aktuelle Mäherposition.
- `Start` sendet den Startbefehl für den Mähbetrieb.
- `Stop` stoppt oder pausiert den aktuellen Vorgang, sofern der Zustand das zulässt.
- `Area Recording` aktiviert oder beendet die Aufzeichnung einer Fläche beziehungsweise eines Verlaufs.
- Oben rechts zeigen die Statussymbole unter anderem MQTT, GPS und Batterie.

**Typische Bedienung**
- Zuerst Verbindungs- und Statussymbole prüfen.
- Karte auf Plausibilität kontrollieren und bei Bedarf zoomen oder verschieben.
- Erst dann `Start` auslösen oder eine Aufzeichnung beginnen.
- Wenn `Stop` oder `Start` ausgegraut sind, ist die Aktion im aktuellen Zustand nicht zulässig.

---

## Sensor Values

![Screenshot Sensor Values](../assets/screenshots/sensor_values.png)

**Wofür ist diese Seite gedacht?**

Diese Seite dient der Diagnose. Sie zeigt zentrale Sensordaten des Mähers in einzelnen Karten, damit technische Auffälligkeiten schnell erkannt werden können.

**Wichtige Bedienelemente und Anzeigen**
- `Mäh-Lastfaktor` zeigt die aktuelle Last des Mähers.
- `GPS Accuracy` hilft bei der Beurteilung der Positionsqualität.
- `V Battery`, `V Charge` und `Charge Current` zeigen Akku- und Ladezustand.
- `Mow Motor Revolutions` und `Mow Motor Current` zeigen Drehzahl und Stromaufnahme.
- Die Temperaturkarten zeigen Mähmotor-, ESC- und weitere Temperaturwerte.

**Typische Bedienung**
- Bei ungewöhnlichem Verhalten die Werte im Leerlauf, beim Mähen und beim Laden vergleichen.
- Hohe Ströme bei niedriger Drehzahl können auf Blockaden oder hohe Last hinweisen.
- Sehr schlechte GPS-Genauigkeit kann Navigationsprobleme erklären.
- Die Seite ist eine Anzeige- und Diagnoseansicht; Werte werden hier normalerweise nicht geändert.

---

## Timetable

![Screenshot Timetable](../assets/screenshots/timetable.png)

**Wofür ist diese Seite gedacht?**

Auf dieser Unterseite wird der automatische Mähbetrieb zeitlich geplant. Zusätzlich kann der Wochenplan vorübergehend ausgesetzt werden, ohne ihn zu löschen.

**Wichtige Bedienelemente und Anzeigen**
- Im Bereich `Mähzeit aussetzen` kann der Betrieb für 1 Tag, 3 Tage oder unbestimmt pausiert werden.
- `Time Settings` dient zum Prüfen oder Aktualisieren der Zeitbasis.
- Unter `Mähzeiten` sind die Wochen-Einträge mit Start, Ende, Verhalten bei Ende und Aktiv-Schalter sichtbar.
- Mit Stift und Papierkorb werden Einträge bearbeitet oder gelöscht.
- `Felder` zeigt zugeordnete Flächen zu einem Zeitplan-Eintrag.

**Typische Bedienung**
- Für kurzfristige Pausen zuerst eine Aussetzen-Funktion verwenden.
- Für regelmäßige Zeiten vorhandene Einträge mit dem Stift anpassen.
- Darauf achten, dass Start- und Endzeiten logisch sind und der Aktiv-Schalter passend gesetzt ist.
- Bei Zeitproblemen immer auch Systemzeit und Zeitzone prüfen.

---

## Flächen

![Screenshot Flächen](../assets/screenshots/flaechen.png)

**Wofür ist diese Seite gedacht?**

Die Flächen-Seite verwaltet bekannte Mähflächen. Hier werden Namen, Reihenfolge, Aktivierung sowie Import/Export der Flächendaten bedient.

**Wichtige Bedienelemente und Anzeigen**
- Im oberen Bereich wird angezeigt, ob aktuell eine aktive Mähfläche gemeldet wird.
- `Fläche skippen` überspringt eine aktuell zugeordnete Fläche, wenn das Backend dies erlaubt.
- In der Flächenliste stehen Name, Mähreihenfolge, Aktiv-Schalter und ein Bearbeiten-Symbol pro Fläche.
- Mit `Öffnen` wird der separate Flächeneditor gestartet.
- In der `JSON-Ansicht` stehen `Download`, `Upload`, `JSON entsperren` und `Speichern` zur Verfügung.

**Typische Bedienung**
- Reihenfolge und Aktivierung direkt in der Liste pflegen.
- Geometrieänderungen nicht hier, sondern im Flächeneditor durchführen.
- Vor Upload oder direktem JSON-Speichern immer zuerst einen Download als Sicherung machen.
- Wenn keine aktive Fläche gemeldet wird, ist ein Skippen nicht möglich.

---

## Protokoll

![Screenshot Protokoll](../assets/screenshots/protokoll.png)

**Wofür ist diese Seite gedacht?**

Die Protokoll-Seite dient der Fehlersuche und Nachvollziehbarkeit von Statuswechseln. Sie zeigt, wann der Mäher von einem Zustand in den nächsten gewechselt hat und welche Begleitdaten dabei vorhanden waren.

**Wichtige Bedienelemente und Anzeigen**
- `Geliefert`, `Gesamt` und `Limit` geben Überblick über geladene Einträge.
- Mit `Anzahl Einträge` und `Tag` werden Protokolle gefiltert.
- `Protokoll erneuern` lädt die Daten neu vom Backend.
- Die Eintragskarten zeigen Zustandswechsel wie `MOWING → DOCKING` oder `DOCKING → IDLE`.
- Aufgeklappte Einträge enthalten Kontext, Automow-Status, Position und Temperaturen.

**Typische Bedienung**
- Für schnelle Analysen mit kleinem Limit starten, zum Beispiel 20 Einträge.
- Rot markierte Emergency-Einträge zuerst prüfen.
- Zeitstempel, Akkustand, GPS und Position mit der realen Situation vergleichen.
- Das Protokoll ist eine reine Analyseansicht und steuert den Mäher nicht direkt.

---

## Einstellungen Hardware

![Screenshot Einstellungen Hardware](../assets/screenshots/hardware_settings.png)

**Wofür ist diese Seite gedacht?**

Hier werden Low-Level-Board-Grenzwerte und Schutzparameter gepflegt. Dazu gehören insbesondere Akku- und Ladegrenzen, die das Schutz- und Ladeverhalten des Systems beeinflussen.

**Wichtige Bedienelemente und Anzeigen**
- `Status neu laden` ruft den aktuellen Stand vom Backend ab.
- `Parameter` und `Entwürfe` geben Überblick über vorhandene Werte und offene Änderungen.
- Jede Karte zeigt den Parameternamen, den technischen Schlüssel, den aktiven Wert und ein Eingabefeld für einen neuen Wert.
- Typische Parameter sind `Akku kritisch`, `Akku leer`, `Akku voll`, `Ladespannung kritisch` und `Ladestrom kritisch`.

**Typische Bedienung**
- Vor jeder Änderung zuerst `Status neu laden` ausführen.
- Werte nur anpassen, wenn deren Bedeutung eindeutig bekannt ist.
- Vor Änderungen alte Werte notieren oder einen Screenshot machen.
- Nach dem Speichern erneut laden und kontrollieren, ob der neue Wert übernommen wurde.

---

## Einstellungen Software

![Screenshot Einstellungen Software](../assets/screenshots/software_settings.png)

**Wofür ist diese Seite gedacht?**

Auf dieser Seite werden Parameter der Mäher-Logik verwaltet. Sie beeinflussen Verhalten und Strategie des Systems, zum Beispiel Mähen, Andocken, GPS-Verhalten, Regenverhalten oder Pfadoptimierung.

**Wichtige Bedienelemente und Anzeigen**
- `Status neu laden` synchronisiert die Parameter mit dem Backend.
- Die Übersicht zeigt Anzahl Parameter, Abweichungen, Entwürfe und Neustart-Hinweise.
- `Expertenmodus` blendet erweiterte Optionen und JSON-Metadaten ein.
- Die Gruppen `mower_logic`, `Mowing`, `Rain`, `Docking`, `Emergency`, `GPS`, `Load_Factor`, `path_order_optimizer` und `Undocking` können einzeln aufgeklappt werden.

**Typische Bedienung**
- Nur die Gruppe öffnen, die tatsächlich bearbeitet werden soll.
- Änderungen vorsichtig testen und größere Änderungen dokumentieren.
- Bei Abweichungen prüfen, ob aktive und gespeicherte Werte bewusst unterschiedlich sind.
- Neustart-Hinweise beachten, da manche Änderungen erst danach vollständig wirken.

---

## Flächeneditor

![Screenshot Flächeneditor](../assets/screenshots/flaecheneditor.png)

**Wofür ist diese Seite gedacht?**

Der Flächeneditor ist die getrennte Detailseite zur Polygonbearbeitung. Hier werden Punktgeometrien verändert, ohne die normale Flächenübersicht zu blockieren.

**Wichtige Bedienelemente und Anzeigen**
- `Bearbeiten` aktiviert den Editiermodus.
- `Rückgängig`, `Verwerfen` und `Speichern` steuern den Umgang mit Änderungen.
- `Mehrfachauswahl`, `Punkte abwählen` und `Punkt löschen` sind Werkzeuge zur Punktbearbeitung.
- Im Feld `Fläche zur Bearbeitung` wird zuerst die gewünschte Fläche gewählt.
- Die Statusleiste und die Werkzeuge rechts im Kartenbereich zeigen Synchronstatus, Auswahl, Raster sowie Zoom- und Navigationsfunktionen.

**Typische Bedienung**
- Zuerst eine Fläche auswählen und dann `Bearbeiten` aktivieren.
- Mit Zoom und Verschieben an die gewünschte Stelle navigieren.
- Punkte gezielt bearbeiten und das Ergebnis visuell prüfen.
- Nur speichern, wenn die Fläche weiterhin plausibel und geschlossen ist; sonst `Rückgängig` oder `Verwerfen` verwenden.
