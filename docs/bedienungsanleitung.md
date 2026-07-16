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
- **Dokustand:** 14.07.2026

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

### Statuszeile im Dashboard

![Screenshot Statuszeile](../assets/screenshots/statuszeile.png)

Die Statuszeile ist die schnelle Funktionsanzeige am oberen Rand des Dashboards. Sie zeigt kompakt, ob die wichtigsten Datenquellen und Zustände verfügbar sind.

**Elemente der Statuszeile**
- `State` zeigt an, ob Statusdaten des Mähers empfangen werden. Damit lässt sich schnell erkennen, ob die App aktuelle Zustandsmeldungen erhält.
- `MQTT` zeigt den Zustand der MQTT-Verbindung beziehungsweise ob die Kommunikationsverbindung zum Backend plausibel verfügbar ist.
- `GPS` zeigt, ob Positionsdaten vorhanden sind. Bei fehlendem oder unplausiblem GPS sollte die Karten- und Navigationsanzeige kritisch geprüft werden.
- `Battery` zeigt, ob Akkudaten vorliegen; je nach App-Zustand kann die Darstellung auch optisch auf Warnungen oder besondere Zustände hinweisen.

**Typische Nutzung der Statuszeile**
- Vor einem Start zuerst prüfen, ob `MQTT` und `GPS` plausibel aktiv sind.
- Wenn Karten- oder Sensordaten fehlen, hilft die Statuszeile bei der Eingrenzung, ob eher die Verbindung oder die Datenquelle betroffen ist.
- Bei Verbindungsproblemen zuerst die Statuszeile prüfen, bevor einzelne Unterseiten neu geladen werden.

**Typische Bedienung**
- Zuerst Verbindungs- und Statussymbole prüfen.
- Karte auf Plausibilität kontrollieren und bei Bedarf zoomen oder verschieben.
- Erst dann `Start` auslösen oder eine Aufzeichnung beginnen.
- Wenn `Stop` oder `Start` ausgegraut sind, ist die Aktion im aktuellen Zustand nicht zulässig.


---

## Aktuell gemähte Fläche / Mähfortschritt

![Screenshot aktuell gemähte Fläche](../assets/screenshots/aktuell_gemaehte_flaeche.png)

**Wofür ist diese Anzeige gedacht?**

Diese Anzeige ist ein Karten-Layer im Dashboard. Sie macht sichtbar, welche Fläche beziehungsweise welcher Mähpfad gerade aktiv ist und welche Bahnen bereits gemeldet wurden. Dadurch lässt sich während des Mähens leichter prüfen, ob der Mäher in der erwarteten Fläche arbeitet und ob der Fortschritt plausibel aussieht.

**Legende und Bedeutung**
- **Hellgrüne Fläche:** bekannte Mähfläche aus der Karte.
- **Schwarzer Rahmen:** aktuell aktive Mähfläche. Der Rahmen wird um die Fläche gezeichnet, deren ID aktuell vom Mähfortschritt, vom Robot-State oder zuletzt aktivem Bereich gemeldet wird. Er ist kein Hindernis und keine Sperrfläche.
- **Schwarze Linien/Bahnen innerhalb der Fläche:** geplante, aktuelle und bereits gemeldete Mähpfade. Bereits gemeldete Pfade werden weiterhin angezeigt, damit der Fortschritt nachvollziehbar bleibt.
- **Runde Fortschrittsmarke:** zeigt Mähreihenfolge und, sofern verfügbar, den prozentualen Fortschritt der aktiven Fläche.
- **Dunkle gefüllte Formen:** Hindernisse oder nicht befahrbare Bereiche aus der Kartengeometrie.
- **Blauer Pfeil:** aktuelle Position und Fahrtrichtung des Mähers.

**Wann erscheint die Anzeige?**
- Der schwarze Rahmen erscheint, sobald eine aktuelle oder zuletzt aktive Mähflächen-ID bekannt ist.
- Die Mähpfade erscheinen nur, wenn das Backend Mähfortschrittsdaten liefert, zum Beispiel geplante Pfade, aktuelle Pfad-ID oder bereits gemähte Pfade.
- Direkt nach dem Öffnen der App, vor dem ersten Start oder bei fehlender MQTT-/Backend-Verbindung kann der Layer leer bleiben.
- Nach kurzen Zustandswechseln kann die zuletzt aktive Fläche noch sichtbar bleiben, damit die Anzeige nicht sofort verschwindet.

**Typische Prüfung während des Mähens**
- Kontrollieren, ob der schwarze Rahmen zur erwarteten Fläche gehört.
- Prüfen, ob die Bahnen innerhalb der Fläche liegen und nicht durch Hindernisse oder Sperrflächen laufen.
- Den Fortschrittswert mit der real gemähten Fläche vergleichen.
- Wenn Rahmen oder Bahnen fehlen, zuerst MQTT-Verbindung, aktiven Mähzustand und Backend-Daten prüfen.

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


## GPS-State

> **JSON-Download:** Die Schaltfläche **Download** befindet sich im Bereich **JSON-Ansicht** und verwendet dieselbe Position, Darstellung und Beschriftung wie die JSON-Ansicht der Flächenseite. Beim Klick wird eine JSON-Datei mit dem exakt zu diesem Zeitpunkt lokal in der App vorhandenen Stand erstellt. Enthalten sind Settings, Definitionen und Status von State0 bis State4, Topics, Empfangszeiten, Validierungen, F9P-Neustartinformationen sowie ungespeicherte Einstellungsentwürfe. Der Download löst bewusst keine zusätzliche MQTT-Aktualisierung aus; für neue Backendwerte zuerst **Status neu laden** verwenden.

**Wofür ist diese Seite gedacht?**

Die GPS-State-Unterseite ist eine Diagnose- und Bedieneranzeige für GPS-Empfang, Satellitenqualität und Fahrfreigabe. Sie verarbeitet das einheitliche Schema `gps_state.v3`: Für State0 bis State4 werden statische Definition und dynamischer Status getrennt empfangen.

**Wichtige Bedienelemente und Anzeigen**
- `Status neu laden` sendet den zentralen State-Befehl `gps_state/set/renew/json` und fordert zusätzlich die GPS-State-Einstellungen über `gps_state/settings/set/renew/json` an.
- `Übersicht (State1)` zeigt oben die Fahrfreigabe-Karte. Grün bedeutet, dass `gps_drive_ready=true` gemeldet wurde. Bei blockierter Fahrfreigabe werden Bedienertext, Grund und optional ein technischer Blockiergrund angezeigt.
- In der State1-Karte werden zusätzlich `RTK`, Positionsgenauigkeit, Grenzwert, gültige Orientierung, aktuelle Pose, GPS-Timeout und Pose-Alter kompakt angezeigt.
- `Signalqualität (State2)` zeigt weiterhin C/N0-Minimum, C/N0-Maximum, schwache/gute Satelliten und die Systemverteilung.
- Wenn das Backend `drive_diagnostics` liefert, blendet State2 eine technische Fahrfreigabe-Diagnose mit Entscheidungsquelle, RTK-Quelle, Low-Level-GPS-Werten, Pose-Alter, Timeout und Grace-Zeit ein.
- `Verwendete Satelliten (State3)` listet die vom Backend verwendeten Satelliten.
- `Alle Satelliten (State4)` kann temporär aktiviert werden. Diese vollständige Liste erzeugt mehr MQTT-Daten und ist daher vor allem für Diagnose gedacht.
- `GPS-/RTK-Aufzeichnung` zeigt den tatsächlichen Laufzeitstatus, den übernommenen Trigger, den übernommenen Modus, die Session-ID und die Laufzeit.
- Im einklappbaren Bereich `Logging-Einstellungen` werden die Vorgaben für die nächste Aufzeichnung wie bei Software- und Hardwareeinstellungen bearbeitet:
  - `Startbedingung`: sofort, nächster Mähzyklus oder bestimmte Fläche.
  - `Aufzeichnungszeitraum`: manuell, bis zum Andocken, Arbeitsstart bis Andocken oder Docking bis Docking.
  - `Zielfläche`: nur sichtbar, wenn `Bestimmte Fläche` ausgewählt ist.
  - `Zurücksetzen` verwirft lokale Entwürfe.
  - `Jetzt anwenden` setzt die Vorgaben nur für die aktuelle Backend-Session.
  - `Dauerhaft speichern` übernimmt sie als persistenten Standard.
  - `Einstellungen neu laden` fordert ausschließlich `gps_state/settings/json` neu an.
- Aktive, gespeicherte und Standardwerte werden unter den Auswahlfeldern getrennt angezeigt. Änderungen gelten erst für eine neue Aufzeichnung; eine laufende oder bereits vorgemerkte Session behält ihre beim Start übernommenen Werte.
- Fehlen die erforderlichen Backendfelder, werden die Auswahlfelder deaktiviert und ein Kompatibilitätshinweis angezeigt. Die Starttaste verwendet dann weiterhin den bisherigen direkten Start mit `ad_hoc` und `until_docking`.
- `JSON-Ansicht / GPS-Diagnose` zeigt einen read-only Snapshot mit Settings sowie Definition und Status aller fünf States. Zu jedem Teil werden MQTT-Topic und lokale Empfangszeit gespeichert.
- `Download` speichert genau den aktuell angezeigten Snapshot als `openmower-gps-state-debug-YYYY-MM-DD_HH-mm-ss.json`. Aktualisieren und Herunterladen sind getrennte Aktionen; der Download löst keine neue MQTT-Anfrage aus.

**Typische Bedienung**
- Vor einer Fehlersuche zuerst `Status neu laden` drücken und prüfen, ob State1 eine aktuelle Fahrfreigabe-Aussage anzeigt.
- Bei `GPS reicht nicht zum Fahren aus` zuerst `gps_drive_reason` und `gps_drive_block_reason` lesen.
- Danach in State2 prüfen, ob RTK Fixed fehlt, die Pose zu alt ist, die Genauigkeit oberhalb des Grenzwerts liegt oder ein GPS-Timeout angezeigt wird.
- State4 nur vorübergehend einschalten, wenn eine vollständige Satellitenliste wirklich benötigt wird.
- Für einen vollständigen nächsten Mähzyklus im Bereich `Logging-Einstellungen` die Kombination `Nächster Mähzyklus` und `Arbeitsstart bis Andocken` wählen, anschließend `Jetzt anwenden` oder `Dauerhaft speichern` drücken und erst danach die Aufzeichnung starten.
- Während eine Aufzeichnung läuft oder vorgemerkt ist, können neue Vorgaben gespeichert werden; sie gelten aber erst für die nächste Aufzeichnung.


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

### Tasten im Bereich `Mähzeit aussetzen`

![Screenshot Timetable Aussetzen](../assets/screenshots/timetable_aussetzen.png)

Der obere Statusblock im Timetable zeigt, ob der Wochenplan aktuell aktiv ist oder vorübergehend ausgesetzt wurde.

**Bedeutung des Statusblocks**
- `Keine Aussetzung aktiv` bedeutet, dass der Zeitplan normal gilt.
- `AutoMow mäht nach Zeitplan.` beschreibt den aktuellen Automow-Grundzustand aus Sicht des Zeitplans.
- Das grüne Symbol links signalisiert einen unkritischen Zustand ohne aktive Aussetzung.

**Funktion der Tasten**
- `1 Tag aussetzen` pausiert die automatische Ausführung des Zeitplans für ungefähr einen Tag. Danach wird der Plan wieder normal verwendet.
- `3 Tage aussetzen` pausiert den Zeitplan für mehrere Tage, ohne dass die eigentlichen Wocheneinträge verändert werden.
- `Unbestimmt aussetzen` deaktiviert die automatische Ausführung zeitlich offen, bis die Aussetzung wieder aufgehoben wird.

**Wichtige Hinweise**
- Die Aussetzen-Tasten ändern normalerweise nicht die hinterlegten Zeitfenster, sondern nur deren vorübergehende Ausführung.
- Diese Funktion ist sinnvoll für Urlaub, Wartung, Besuch oder Schlechtwetterphasen, wenn der Wochenplan erhalten bleiben soll.
- Nach Ablauf von `1 Tag` oder `3 Tage` kehrt der Zeitplan automatisch zurück. Eine unbestimmte Aussetzung bleibt bestehen, bis sie aufgehoben wird.

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

### Aufbau der Protokoll-Abteilung

![Screenshot Protokoll Detail](../assets/screenshots/protokoll_detail.png)

Die Protokoll-Abteilung ist in mehrere Ebenen gegliedert: eine Statuszeile für den Datenabruf, den Gruppenblock `Protokolldaten` und darunter einzelne Protokollkarten für jeden Statuswechsel.

**Oberer Informationsbalken**
- Die grüne Hinweiszeile zeigt, wie viele Protokoll-Einträge aktuell geladen wurden, zum Beispiel `20 von 300 Protokoll-Einträgen empfangen`.
- Zusätzlich werden das verwendete MQTT-Topic und der Zeitpunkt der letzten Aktualisierung angezeigt.
- Diese Zeile hilft zu erkennen, ob die Daten frisch sind und ob das erwartete Topic verwendet wurde.

**Bereich `Protokolldaten`**
- Die Überschrift `Protokolldaten` beschreibt die Historie der per MQTT gemeldeten Statuswechsel.
- Der Pfeil rechts oben klappt den gesamten Bereich ein oder aus.
- Innerhalb des Bereichs wird jeder Statuswechsel als eigene Karte angezeigt.

**Aufbau einer einzelnen Protokollkarte**
- Die Kopfzeile zeigt den Statuswechsel, zum Beispiel `MOWING → DOCKING`.
- Das Badge `Aktiv` kennzeichnet den aktuell relevanten oder zuletzt laufenden Eintrag.
- In der Symbolzeile darunter werden unter anderem Zeitpunkt, Dauer, Akkustand und GPS-Wert zusammengefasst.
- Der Pfeil rechts an der Karte klappt den Eintrag selbst ein oder aus.

**Detailkarten innerhalb eines Eintrags**
- `Statuswechsel` zeigt den vorherigen und den neuen Zustand.
- `Kontext` enthält Begleitinformationen wie Akkustand, GPS, Ladezustand, Emergency und Drehrichtung.
- `Automow` zeigt Automow-bezogene Zusatzinformationen wie Status, Automow-ID oder aktuelle Fläche.
- `Position` enthält Koordinaten, Heading und Genauigkeiten.
- `Temperaturen` listet relevante Temperaturwerte der Komponenten.

**Typische Bedienung**
- Für schnelle Analysen mit kleinem Limit starten, zum Beispiel 20 Einträge.
- Rot markierte Emergency-Einträge zuerst prüfen.
- Zeitstempel, Akkustand, GPS und Position mit der realen Situation vergleichen.
- Das Protokoll ist eine reine Analyseansicht und steuert den Mäher nicht direkt.

---

## Einstellungen auf Android

Die Einstellungsseiten sind auf Android in der Regel stärker vertikal aufgebaut als in der Webansicht. Dadurch können dieselben Inhalte auf kleineren Bildschirmen gut gelesen und bearbeitet werden, erfordern aber etwas mehr Scrollen.

**Allgemeine Hinweise für Android**
- Einstellungen werden auf Android typischerweise über die Navigation der App geöffnet und dann als eigene Seite dargestellt.
- Wegen der kleineren Bildschirmbreite werden Karten und Parameter häufiger untereinander statt nebeneinander angezeigt.
- Lange Listen oder große Gruppen sollten Abschnitt für Abschnitt bearbeitet werden, damit Änderungen übersichtlich bleiben.
- Nach Eingaben kann die Bildschirmtastatur einen Teil des unteren Bereichs verdecken. Gegebenenfalls erst die Tastatur schließen und dann zu `Jetzt anwenden`, `Dauerhaft speichern` oder `Entwürfe zurücksetzen` scrollen.
- Bei sehr vielen Gruppen ist es sinnvoll, nur die gerade benötigte Gruppe geöffnet zu lassen.

**Besonders wichtig auf Android**
- Vor Änderungen immer `Status neu laden` verwenden.
- Nach einer Zahlenänderung prüfen, ob der neue Wert als `Entwurf` sichtbar ist.
- Änderungen möglichst einzeln testen, insbesondere bei Expertenparametern.
- Wenn der `Expertenmodus` aktiviert wird, können zusätzliche Parameter oder Metadaten sichtbar werden. Diese sollten nur geändert werden, wenn ihre Wirkung bekannt ist.

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

Auf dieser Seite werden Parameter der Mäher-Logik verwaltet. Sie beeinflussen Verhalten und Strategie des Systems, zum Beispiel Mähen, Andocken, GPS-Verhalten, Regenverhalten, Lastregelung oder Pfadoptimierung.

**Grundprinzip der Seite**
- Die Software-Einstellungen sind in **Gruppen** gegliedert. Jede Gruppe fasst zusammengehörige Parameter zusammen, zum Beispiel `Allgemein`, `Mowing`, `Rain`, `Docking`, `Emergency`, `GPS`, `Load_Factor`, `path_order_optimizer` oder `Undocking`.
- Gruppen werden als ausklappbare Karten angezeigt. Über den Pfeil rechts oben an der Gruppenkopfzeile wird eine Gruppe **aufgeklappt** oder **eingeklappt**.
- Eingeklappte Gruppen sparen Platz und zeigen nur die Überschrift sowie vorhandene Kennzeichnungen, zum Beispiel Entwürfe, Abweichungen oder Session-Fähigkeit.
- Aufgeklappte Gruppen zeigen die einzelnen Parameterkarten mit aktivem Wert, gespeichertem Wert, Entwurf und Eingabefeld.
- `Allgemein` beziehungsweise häufig benötigte Gruppen können beim Öffnen der Seite bereits aufgeklappt sein. Alle anderen Gruppen werden bei Bedarf geöffnet.

**Wichtige Bedienelemente und Anzeigen**
- `Status neu laden` synchronisiert die Parameter mit dem Backend. Dies sollte vor Änderungen ausgeführt werden, damit aktive und gespeicherte Werte aktuell sind.
- Die Übersicht zeigt Anzahl Parameter, Abweichungen, Entwürfe und Neustart-Hinweise.
- `Aktiv` zeigt den aktuell laufenden Wert.
- `Gespeichert` zeigt den persistent abgelegten Wert. Dieser Wert ist nach einem Neustart maßgeblich.
- `Entwurf` ist das Eingabefeld für den neuen Wert. Ein Entwurf ist noch nicht automatisch aktiv.
- `Jetzt anwenden` überträgt geeignete Entwürfe in die laufende Session. Nicht jeder Parameter unterstützt diese Live-Übernahme.
- `Dauerhaft speichern` schreibt die Entwürfe persistent. Je nach Parameter kann zusätzlich ein Neustart erforderlich sein.
- `Entwürfe zurücksetzen` verwirft noch nicht gespeicherte Änderungen.

**Expertenmodus**
- Der `Expertenmodus` blendet erweiterte Optionen ein. Dazu gehören insbesondere editierbare JSON-Metadaten wie `group` und die Experten-Kennzeichnung.
- Der Expertenmodus ist für Diagnose und Strukturpflege gedacht. Er sollte nur verwendet werden, wenn klar ist, welche Wirkung die Metadaten haben.
- Wird im Expertenmodus die Gruppe eines Parameters geändert, bleibt die Anzeige während der Eingabe stabil. Die neue Gruppierung wird erst nach dem Speichern und nach der Rückmeldung des Backends sauber neu aufgebaut.
- Parameter, die als Expertenparameter gekennzeichnet sind, können im normalen Modus ausgeblendet sein und erscheinen erst im Expertenmodus.

**Gruppen, Aufklappen und Einklappen**
- Eine Gruppe wird über den kleinen Pfeil in der Kopfzeile geöffnet oder geschlossen.
- Beim Aufklappen werden die enthaltenen Parameter sichtbar. Beim Einklappen bleiben die Werte erhalten; es wird nur die Anzeige reduziert.
- Sinnvoll ist, immer nur die Gruppe zu öffnen, die gerade geprüft oder geändert werden soll. Das reduziert Verwechslungen bei vielen Parametern.
- Badges in den Karten zeigen an, ob ein Wert `Session-fähig` ist, ob eine Abweichung besteht oder ob Änderungen offen sind.

### Einstellungen Software - Gruppe `Load_Factor`

![Screenshot Software Load Factor](../assets/screenshots/software_load_factor.png)

**Wofür ist die Gruppe `Load_Factor` gedacht?**

Die Gruppe `Load_Factor` enthält Parameter der Mäh-Lastregelung. Diese Funktion bewertet die Belastung des Mähsystems und kann abhängig von Strom, Temperatur oder berechnetem Lastfaktor das Fahr- beziehungsweise Mähverhalten beeinflussen. Ziel ist, Überlast zu vermeiden und den Mäher bei höherer Last kontrollierter arbeiten zu lassen.

**Typische Parameter in `Load_Factor`**
- `mow_load_factor_enabled` aktiviert oder deaktiviert die Mäh-Lastregelung.
- `mow_load_factor_min` definiert den unteren Bereich beziehungsweise Mindestwert des Lastfaktors.
- `mow_load_current_start` und `mow_load_current_end` beschreiben den Strombereich, ab dem Last berücksichtigt wird beziehungsweise ab dem der maximale Lastfaktor erreicht ist.
- `mow_load_motor_temp_start` und `mow_load_motor_temp_end` beschreiben den Temperaturbereich des Mähmotors für die Lastbewertung.
- `mow_load_esc_temp_start` und `mow_load_esc_temp_end` beschreiben den Temperaturbereich des Motorcontrollers / ESC.
- `mow_load_factor_smoothing_enabled` aktiviert eine Glättung des berechneten Lastfaktors.
- `mow_load_factor_smoothing_down_alpha` und `mow_load_factor_smoothing_up_alpha` bestimmen, wie schnell der geglättete Wert fällt oder steigt.
- `mow_load_status_publish_period` legt fest, wie häufig Statuswerte zur Lastregelung veröffentlicht werden.

**Legende der Parameterkarten**
- `Aktiv`: aktuell laufender Wert im System.
- `Gespeichert`: persistenter Wert, der nach Neustart wieder geladen wird.
- `Default`: Standardwert aus der Backend-Definition.
- `Session-fähig`: der Wert kann ohne dauerhaftes Speichern in der laufenden Session angewendet werden.
- Einheit rechts am Eingabefeld, zum Beispiel `A`, `°C` oder `s`, zeigt die erwartete Einheit.

**Wann sollte `Load_Factor` angepasst werden?**
- Wenn der Mäher bei dichterem Gras, Steigungen oder hohem Schnittwiderstand zu aggressiv oder zu vorsichtig reagiert.
- Wenn Strom- oder Temperaturwerte regelmäßig in kritische Bereiche laufen.
- Wenn der angezeigte Lastfaktor stark springt und deshalb die Glättung angepasst werden soll.
- Wenn Diagnosewerte häufiger oder seltener veröffentlicht werden sollen.

**Vorsicht bei Änderungen**
- Strom- und Temperaturgrenzen beeinflussen Schutz- und Regelverhalten. Zu hohe Grenzwerte können Überlastsituationen später erkennen lassen.
- Änderungen zuerst klein wählen und im Betrieb beobachten.
- Nach jeder Änderung prüfen, ob `Aktiv` und `Gespeichert` den erwarteten Stand zeigen.
- Bei unklarem Verhalten Entwürfe zurücksetzen oder auf bekannte Werte zurückgehen.

**Typische Bedienung**
- Zuerst `Status neu laden` drücken.
- Gruppe `Load_Factor` aufklappen.
- Einen einzelnen Wert ändern, nicht mehrere unbekannte Werte gleichzeitig.
- Falls der Parameter `Session-fähig` ist, mit `Jetzt anwenden` testen.
- Bei erfolgreichem Test mit `Dauerhaft speichern` sichern.
- Nach dem Speichern erneut laden und prüfen, ob die Werte übernommen wurden.

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

### GPS-State v3, Diagnoseexport und F9P-Neustart

Die GPS-State-Seite unterscheidet klar zwischen Bedieneranzeige und Experten-/Debugdaten. **State1** zeigt nur die kompakte Fahrfreigabe mit Grund, RTK-Zustand, Genauigkeit und Pose-Alter; eine zusätzliche Aktualisiert-Anzeige wird dort bewusst nicht wiederholt. **State2** zeigt die technische GNSS-/Pose-Zusammenfassung einschließlich des gemeinsamen `age_ms`-/`stale`-Status. **State3** zeigt nur aktiv verwendete Satelliten. **State4** zeigt alle sichtbaren Satelliten inklusive Used-Status und sollte nur bei Diagnose aktiv sein. Wenn State2 bis State4 nach einem F9P-Neustart als `stale` beziehungsweise `available=false` gemeldet werden, zeigt die App einen orangefarbenen Warnhinweis und graut die alten Werte aus; frühere RTK-, C/N0- oder Satellitenwerte gelten dann nicht als aktuelle Qualitätsaussage. **State0** zeigt die vollständige Fahrfähigkeits-Entscheidungskette als Expertenansicht. Die App liest für jeden State ausschließlich die kanonischen Topics `gps_state/stateN/definition` und `gps_state/stateN/status`.

In **State0** wird die bisherige, überladene Kennzahlen-Zusammenfassung durch einen kompakten Freigabe-Banner ersetzt. Die 12 Prüfpunkte erscheinen darunter als einzeilige Diagnosezeilen mit Stufennummer, Entscheidungsknoten, aktuellem Wert, Bedingung und Ergebnis. Die technische Quelle wird in der normalen Ansicht nicht mehr angezeigt; die Beschreibung bleibt als Tooltip verfügbar. Grün bedeutet erfüllt, gelb bedeutet nicht aktuell beziehungsweise nicht bewertet und rot bedeutet blockiert. Wenn das Backend `blocking_stage` oder `blocking_key` liefert, markiert die App den ersten blockierenden Prüfschritt zusätzlich mit **BLOCKIERT ZUERST**.

Beim Aufklappen von State0 fordert die App automatisch einen neuen Snapshot an. Über die Taste **State0 aktualisieren** kann derselbe Vorgang jederzeit manuell ausgelöst werden. Während die Antwort aussteht, werden vorhandene Werte bewusst gelb als **Aktualisierung** beziehungsweise **Nicht aktuell** dargestellt. Ein grüner Gesamtstatus erscheint erst, wenn ein nach der Anforderung empfangener State0-Status vorliegt und die Einzelprüfungen nicht im Widerspruch zum Gesamtstatus stehen.

Die App verwendet keine dezentralen State-Renew-Topics mehr. Die allgemeine Aktualisierung sendet `{}` an `gps_state/set/renew/json`. Beim Öffnen oder manuellen Aktualisieren von State0 wird gezielt `{"states":[0],"parts":["status"]}` an dasselbe zentrale Topic gesendet. Erst eine danach empfangene Nachricht auf `gps_state/state0/status` gilt für die Freigabeanzeige als aktueller Snapshot.

Unterhalb der GPS-Anzeigen befindet sich eine einklappbare read-only **JSON-Ansicht**. Wie auf der Flächenseite steht die Aktion **Download** rechts im Abschnittskopf; auf schmalen Ansichten wird sie als breite Schaltfläche **Herunterladen** unter der Überschrift dargestellt. Der Export enthält die GPS-State-Settings sowie Definition und Status von State0 bis State4, jeweils mit dem tatsächlich verwendeten Topic und der lokalen Empfangszeit. Validierungs- und F9P-Neustartantworten werden als Zusatzdaten beigefügt. Der Download nutzt den plattformabhängigen Textdatei-Service der App und verändert keine MQTT-Daten.

Im Bereich **F9P-Neustart und Recovery** können Hot Start, Warm Start und Cold Start ausgelöst werden. Als Reset-Modus ist `controlled_software` voreingestellt. Die App zeigt den Live-Ablauf `resetting`, `waiting_for_receiver`, `validating`, `success` oder `failed` und sperrt während der Recovery weitere Neustartbefehle.

Die Prüfkette zeigt getrennt, ob die Neustartanforderung empfangen, der Reset ausgeführt, neue NAV-PVT-Daten empfangen, neue NAV-SAT-Daten empfangen und der Receiver-Neustart bestätigt wurde. Angezeigt werden außerdem Restart-Sequenz, Startart, Reset-Modus, Anforderungszeit, Abschlusszeit und Dauer. Ein Neustart gilt erst bei `success` und bestätigten neuen NAV-PVT-/NAV-SAT-Ausgaben als erfolgreich; RTK Fixed ist dafür nicht erforderlich.

Der retained MQTT-Stand `gps_state/restart/last/json` erscheint als eigener Bereich **Letzter abgeschlossener Neustart** und bleibt damit auch nach erneutem Öffnen der Seite nachvollziehbar. Technische Fehlergründe werden verständlich erklärt, der Originalcode bleibt unter **Technische Details** sichtbar.

### Geordneter F9P-Neustartdialog

Der Bereich **F9P-Neustart und Recovery** folgt nun einer festen Bedienreihenfolge:

1. Reset-Modus auswählen.
2. Starttyp (Hot, Warm oder Cold Start) auswählen.
3. **Neustart ausführen** betätigen.

Unterhalb der Bedienelemente wird nur noch der aktuell relevante Recovery-Schritt angezeigt. Die bisherige gleichzeitige Darstellung aller Prüfschritte entfällt. Mögliche Anzeigen sind unter anderem `Befehl gesendet`, `Empfänger antwortet`, `NAV-PVT empfangen`, `NAV-SAT empfangen` und `Empfängerausgaben bestätigt`.

Nach einem erfolgreich abgeschlossenen Neustart zeigt dasselbe Statusfeld zusätzlich den Abschlusszeitpunkt aus `completed_at` an. Ist kein aktueller Ablauf aktiv, bleibt der letzte Abschlusszeitpunkt sichtbar, sofern das Backend einen Wert über `gps_state/restart/last/json` geliefert hat.


### F9P-Reset-Auswahl und State1-Statusdarstellung (2026-07-16)

Der Bereich **F9P-Neustart und Recovery** verwendet für Reset-Modus und Starttyp nun dieselbe direkte Auswahlart. Die vier Reset-Modi werden als Auswahl-Chips dargestellt; das bisherige Ausklappfeld entfällt. Neben **Neustart ausführen** zeigt ein farblich hervorgehobenes Feld die Eingriffsstärke des gewählten Reset-Modus: `gnss_only` = niedrig bis mittel, `controlled_software` = mittel, `hardware_after_shutdown` und `hardware_watchdog` = hoch.

In der Fahrfähigkeitsansicht ist **Current Status** eine nicht nummerierte Informationszeile. Der Wert wird aus `current_status` des State1-Statuspayloads gelesen; der verschachtelte `data.current_status`-Wert dient nur als kompatibler Rückfallwert. Das obere Fahrfreigabefeld richtet seinen Haupttext an `drive_ready`, `drive_state`, `blocking_stage` und `blocking_title` aus. Ein widersprüchlicher allgemeiner Summary-Text überschreibt daher keine eindeutige Fahrfreigabe mehr.

Liegt ein erster Blockierer vor, erhalten alle davor liegenden und erfolgreich erfüllten Prüfstufen einen ausgefüllten Kreis in ihrer Statusfarbe. Der Blockierer selbst behält seine rote Blockiermarkierung; nachfolgende Stufen werden weiterhin nach ihrem eigenen Status dargestellt.

### Darstellung der erfolgreichen State1-Entscheidungskette

Die Kreise vor den nummerierten Entscheidungsknoten zeigen jetzt den bereits erfolgreich abgeschlossenen Teil der Fahrfähigkeitsprüfung:

- Sind alle Prüfschritte erfolgreich und existiert kein Blockierer, werden die Kreise der Stufen 1 bis 12 grün ausgefüllt dargestellt.
- Existiert ein erster Blockierer, werden nur die erfolgreichen Stufen vor diesem Blockierer ausgefüllt dargestellt.
- Der blockierende Prüfschritt behält seine eigene Fehler- beziehungsweise Blockierdarstellung.
- Rein informative Zeilen wie `Current Status` und `GPS Quality` bleiben von dieser Fortschrittsdarstellung ausgenommen.

Die Füllung ergänzt die Ergebnisanzeige rechts und macht auf einen Blick sichtbar, wie weit die Entscheidungskette erfolgreich durchlaufen wurde.
