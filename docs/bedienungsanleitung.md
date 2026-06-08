---
layout: default
title: Bedienungsanleitung der App-Unterseiten
permalink: /bedienungsanleitung/
---

# Bedienungsanleitung der OpenMower App-Unterseiten

Diese Anleitung beschreibt die sichtbaren Unterseiten der OpenMower TAF App. Sie erklärt, wofür die jeweilige Seite gedacht ist, welche Bedienelemente vorhanden sind und wie die Seite typischerweise verwendet wird. Einzelne Schaltflächen können deaktiviert sein, wenn der aktuelle Mäherzustand, eine fehlende Verbindung oder eine fehlende Auswahl die Aktion nicht zulässt.

Oben in der App befindet sich die Kopfzeile mit Menü, Logo und Statussymbolen. Rechts werden Zustände wie State, MQTT, GPS und Batterie angezeigt. Unten zeigt ein blauer Balken die aktuell geöffnete Seite. Je nach App-Variante können die Hauptseiten per Wischgeste durchlaufen werden. Der Flächeneditor wird über die Flächen-Seite geöffnet und ist eine eigene Unterseite.

[PDF-Version herunterladen](../assets/OpenMower_App_Bedienungsanleitung_Unterseiten.pdf)

---

## Dashboard

Das Dashboard ist die zentrale Startseite für den laufenden Mäherbetrieb. Es zeigt den aktuellen Zustand des Mähers, die Karte mit Flächen, Hindernissen und Positionsinformationen sowie die wichtigsten Steueraktionen. Diese Seite wird normalerweise zuerst geöffnet, um zu prüfen, ob der Mäher erreichbar ist und ob die angezeigte Fläche zur realen Situation passt.

Im oberen Bereich steht die Statuskarte mit dem aktuellen Zustand, zum Beispiel `IDLE`, `MOWING`, `PAUSED` oder `DOCKING`. Dieser Zustand ist wichtig, weil viele Bedienaktionen davon abhängen. Wenn der Mäher gerade mäht, lädt, andockt oder pausiert, können bestimmte Schaltflächen aktiv oder gesperrt sein.

Der große Kartenbereich zeigt die Mähfläche auf einem Raster. Je nach verfügbaren Daten werden Mähflächen, bearbeitete Bereiche, Hindernisse, Positionspunkte, Wege oder die aktuelle Mäherposition dargestellt. Die Karte dient zur Kontrolle während des Betriebs. Mit Maus, Touchpad oder Touch-Gesten kann die Ansicht verschoben und gezoomt werden. So lassen sich auch große oder schmale Flächen genauer betrachten.

Am unteren Rand befinden sich die direkten Aktionsschaltflächen. `Start` startet den Mähbetrieb beziehungsweise sendet den Startbefehl an das Backend. `Stop` stoppt oder pausiert den aktuellen Vorgang, sofern der Zustand des Mähers diese Aktion zulässt. `Area Recording` dient zum Ein- und Ausschalten der Flächenaufzeichnung, zum Beispiel wenn ein Grenzverlauf oder eine neue Fläche aufgenommen werden soll.

Vor einem Start sollte zuerst geprüft werden, ob die Statussymbole oben rechts plausibel sind. MQTT sollte verbunden sein und GPS sollte gültige Daten liefern. Wenn die Karte nicht aktuell wirkt oder die GPS-Information fehlt, sollte keine unkontrollierte Aktion gestartet werden. Das Dashboard ist für Kontrolle und direkte Bedienung gedacht, nicht für die Detailbearbeitung von Polygonpunkten. Diese Bearbeitung erfolgt im Flächeneditor.

---

## Sensor Values

Die Seite `Sensor Values` ist eine Diagnoseansicht. Sie zeigt die aktuellen Messwerte des Mähers in einzelnen Karten. Dazu gehören Akkuspannung, Ladespannung, Ladestrom, GPS-Genauigkeit, Mähmotorwerte, Temperaturen und der Mäh-Lastfaktor. Die Seite wird verwendet, wenn der Mäher ungewöhnlich reagiert, stehen bleibt, nicht korrekt lädt oder wenn ein technischer Zustand überprüft werden soll.

Der `Mäh-Lastfaktor` zeigt, wie stark der Mäher aktuell belastet wird. Eine hohe Last kann auf dichtes Gras, mechanische Reibung oder blockierte Messer hinweisen. `GPS Accuracy` zeigt die Genauigkeit der Position. Sehr große Werte, wie zum Beispiel `999.000 m`, deuten darauf hin, dass keine brauchbare GPS-Genauigkeit vorliegt oder die Daten nicht aktuell sind.

`V Battery` zeigt die Batteriespannung, `V Charge` die Ladespannung und `Charge Current` den aktuellen Ladestrom. Diese Werte helfen beim Prüfen, ob der Mäher lädt, entlädt oder möglicherweise ein Problem mit Akku oder Ladestation hat. Die Karten für `Mow Motor Revolutions` und `Mow Motor Current` zeigen Drehzahl und Stromaufnahme des Mähmotors. Ein Stromanstieg bei niedriger Drehzahl kann auf hohe Belastung oder eine Blockade hindeuten.

Die Temperaturkarten zeigen Werte für Mähmotor, Mow ESC, Left ESC und Right ESC. Die farbigen Skalen helfen dabei, die Werte schnell einzuschätzen. Stark steigende Temperaturen sollten beobachtet werden, besonders wenn sie gleichzeitig mit hoher Motorlast oder hohem Strom auftreten.

Die Seite dient primär der Anzeige und Fehlersuche. Werte werden hier normalerweise nicht direkt geändert. Wenn Werte eingefroren wirken oder unplausibel sind, sollte zuerst die MQTT-Verbindung und der Backend-Status geprüft werden. Einzelne Ausreißer sind weniger wichtig als dauerhaft extreme oder wiederholt auffällige Werte.

---

## Timetable

Die Seite `Timetable` verwaltet, wann AutoMow planmäßig fahren darf. Sie ist für regelmäßige Mähzeiten und kurzfristige Pausen gedacht. Dadurch kann der automatische Betrieb gesteuert werden, ohne jedes Mal manuell am Dashboard starten zu müssen.

Oben befindet sich der Bereich `Mähzeit aussetzen`. Er zeigt, ob aktuell eine Aussetzung aktiv ist. Mit `1 Tag aussetzen`, `3 Tage aussetzen` oder `Unbestimmt aussetzen` kann der geplante Mähbetrieb vorübergehend pausiert werden. Das ist nützlich bei schlechtem Wetter, Gartenarbeiten oder wenn der Mäher für eine gewisse Zeit nicht fahren soll. Der eigentliche Wochenplan bleibt dabei erhalten.

Der Bereich `Time Settings` ist für Systemzeit und Zeitaktualisierung vorgesehen. Zeitfehler können dazu führen, dass Mähzeiten scheinbar zu früh oder zu spät ausgeführt werden. Wenn geplante Fahrten nicht wie erwartet starten, sollte neben dem Zeitplan auch die Systemzeit geprüft werden.

Im Abschnitt `Mähzeiten` sind die Zeit-Einträge pro Wochentag sichtbar. Jeder Eintrag enthält Tag, Startzeit, Endzeit, Verhalten bei Ende, zugeordnete Felder und einen Aktiv-Schalter. Start und Ende legen das erlaubte Zeitfenster fest. Das Feld `Verhalten bei Ende` bestimmt, was passieren soll, wenn das Zeitfenster endet, zum Beispiel den aktuellen Lauf noch beenden. Über `Felder` wird angezeigt oder ausgewählt, welche Mähflächen zu diesem Eintrag gehören.

Mit dem Stift-Symbol wird ein Eintrag bearbeitet. Mit dem Papierkorb wird ein Eintrag gelöscht. Vor dem Löschen sollte geprüft werden, ob dadurch ein Wochentag ohne Mähfenster bleibt. Der Aktiv-Schalter legt fest, ob ein Eintrag tatsächlich verwendet wird. Die Timetable-Seite steuert geplante Fahrten; ein manueller Sofortstart erfolgt weiterhin über das Dashboard.

---

## Flächen

Die Seite `Flächen` ist die Verwaltungsansicht für Mähflächen. Sie zeigt die aktuell gemeldete oder aktive Fläche, die Liste der bekannten Flächen und deren Mähreihenfolge. Außerdem führt sie zum getrennten Flächeneditor und enthält die JSON-Funktionen für Import, Export und Speichern.

Im oberen Bereich `Fläche anzeigen` wird angezeigt, ob der Mäher aktuell eine zuordenbare Mähfläche meldet. Wenn keine aktive Fläche vorhanden ist, erscheint eine Meldung wie `robot_state/json keine zuordenbare Mähfläche`. In diesem Zustand kann die App keine aktuelle Fläche zuordnen und die Schaltfläche `Fläche skippen` ist möglicherweise deaktiviert. Wenn eine Fläche aktiv ist, kann `Fläche skippen` genutzt werden, um die aktuelle Fläche zu überspringen, sofern das Backend diese Aktion erlaubt.

Der Abschnitt `Flächen` zeigt die vorhandenen Flächen. Jede Zeile enthält den Namen, die Mähreihenfolge, einen Aktiv-Schalter und ein Bearbeiten-Symbol. Der Name dient der Erkennung der Fläche. Die Mähreihenfolge steuert, in welcher Reihenfolge Flächen abgearbeitet werden. Der Aktiv-Schalter legt fest, ob die Fläche für die Bearbeitung berücksichtigt wird. Das Bearbeiten-Symbol dient zum Anpassen der Verwaltungsdaten der Fläche, nicht zur detaillierten Polygonbearbeitung.

Der Bereich `Flächeneditor` enthält die Schaltfläche `Öffnen`. Damit wird die separate Editor-Unterseite gestartet. Dort werden Polygonpunkte, Auswahl und Geometrie bearbeitet. Die Trennung ist wichtig: Die Flächen-Seite verwaltet Namen, Reihenfolge, Aktivierung und Datenaustausch; der Flächeneditor bearbeitet die Form der Fläche.

Im Bereich `JSON-Ansicht` stehen Funktionen wie `Download`, `Upload`, `JSON entsperren` und `Speichern` bereit. `Download` erstellt eine Sicherung der aktuellen Flächendaten. `Upload` importiert Flächendaten aus einer Datei. `JSON entsperren` erlaubt das Bearbeiten der JSON-Daten. `Speichern` schreibt die Änderungen zurück. Vor Upload oder direktem JSON-Speichern sollte immer eine Sicherung erstellt werden.

---

## Protokoll

Die Seite `Protokoll` zeigt Statuswechsel und Übergänge des Mähers. Sie ist eine rückblickende Diagnoseansicht und hilft dabei, Fehler oder ungewöhnliche Abläufe nachzuvollziehen. Anstatt nur den aktuellen Zustand zu sehen, kann hier geprüft werden, wann der Mäher von einem Zustand in den nächsten gewechselt ist und welche Kontextdaten zu diesem Zeitpunkt vorhanden waren.

Im oberen Bereich stehen Kennzahlen wie `Geliefert`, `Gesamt` und `Limit`. Sie zeigen, wie viele Einträge geladen wurden und wie viele insgesamt verfügbar sind. Mit `Anzahl Einträge` wird begrenzt, wie viele Einträge geladen werden. Für eine schnelle Diagnose reichen oft die letzten 20 Einträge. Über `Tag` kann ein bestimmter Tag oder `Alle Tage` gewählt werden. Mit `Protokoll erneuern` werden die Daten erneut vom Backend geladen.

Unterhalb der Filter erscheint eine Statusmeldung, die angibt, wie viele Protokolleinträge empfangen wurden und von welchem MQTT-Topic die Daten stammen. Danach folgt der Bereich `Protokolldaten`. Jeder Eintrag beschreibt einen Zustandswechsel, zum Beispiel `DOCKING → IDLE`, `MOWING → DOCKING` oder `MOWING → PAUSED`. Einträge können aufgeklappt werden, um Details zu sehen.

In den Details werden Informationen wie Statuswechsel, Kontext, Automow-Status, Position und Temperaturen angezeigt. Dazu gehören Akku, GPS, Ladezustand, Emergency-Status, Drehrichtung, aktuelle Fläche, Koordinaten, Positionsgenauigkeit und Temperaturwerte. Rot markierte Emergency-Einträge sind besonders relevant für die Fehlersuche.

Das Protokoll steuert den Mäher nicht direkt. Es dient dazu, Ereignisse mit realen Beobachtungen abzugleichen. Zeitstempel, Dauerangaben und Kontextdaten sind dabei besonders wichtig. Bei sehr vielen Einträgen sollte lieber gefiltert werden, statt unnötig große Datenmengen zu laden.

---

## Einstellungen Hardware

Die Seite `Einstellungen Hardware` verwaltet Low-Level-Board-Grenzwerte und Schutzparameter. Sie ist für hardware-nahe Einstellungen gedacht, zum Beispiel Akku- und Ladegrenzen. Änderungen auf dieser Seite können das Ladeverhalten, Rückkehrverhalten und Schutzabschaltungen beeinflussen. Deshalb sollten Werte nur geändert werden, wenn ihre Bedeutung klar ist.

Oben befindet sich die Schaltfläche `Status neu laden`. Damit werden die aktuellen Werte vom Backend abgerufen. Die Karten `Parameter` und `Entwürfe` zeigen, wie viele Parameter vorhanden sind und ob es noch nicht dauerhaft gespeicherte Änderungen gibt. Eine Statusmeldung bestätigt, ob der Low-Level-Board-Status vom Backend empfangen wurde.

Der Abschnitt `Low-Level Board` enthält die eigentlichen Parameter. Jede Parameterkarte zeigt einen Namen, den technischen Schlüssel, eine Beschreibung, den aktuellen aktiven Wert und ein Eingabefeld für den neuen Wert. Beispiele sind `Akku kritisch`, `Akku leer`, `Akku voll`, `Akku Hochspannung kritisch`, `Ladespannung kritisch` und `Ladestrom kritisch`. Rechts im Eingabefeld steht die Einheit, zum Beispiel Volt oder Ampere.

Vor Änderungen sollte immer `Status neu laden` ausgeführt werden, damit die angezeigten Werte dem aktuellen Stand entsprechen. Danach kann ein neuer Wert eingetragen werden. Werte, die nur für eine laufende Session gesendet werden, sind als Test zu verstehen. Dauerhaftes Speichern sollte nur erfolgen, wenn der Wert fachlich geprüft wurde und nach einem Neustart erhalten bleiben soll.

Nach dem Speichern sollte erneut geladen und kontrolliert werden, ob der Wert übernommen wurde. Vor jeder Änderung empfiehlt es sich, den alten Wert zu notieren oder einen Screenshot zu machen. Falsche Grenzwerte können zu unerwartetem Ladeverhalten oder zu fehlenden Schutzabschaltungen führen.

---

## Einstellungen Software

Die Seite `Einstellungen Software` verwaltet Parameter der Mäher-Logik. Diese Einstellungen beeinflussen Verhalten und Strategie des Systems, zum Beispiel Mähen, Regenverhalten, Andocken, Notfallzustände, GPS, Lastfaktor, Pfadoptimierung und Abdocken.

Oben befindet sich `Status neu laden`. Damit werden die aktuellen Parameter vom Backend abgerufen. Die Übersichtskarten zeigen Anzahl der Parameter, Abweichungen, Entwürfe und Neustart-Hinweise. Eine grüne Statusmeldung bestätigt, dass Daten der Mäher-Logik empfangen wurden. Wenn Werte nicht aktuell wirken, sollte zuerst neu geladen werden.

Der `Expertenmodus` blendet zusätzliche Optionen ein. Er zeigt erweiterte, editierbare JSON-Metadaten wie Gruppenzuordnung. Die Gruppierung wird erst nach dem Speichern und nach Rückmeldung des Backends neu aufgebaut. Der Expertenmodus sollte nur verwendet werden, wenn die erweiterten Metadaten wirklich verstanden und benötigt werden.

Die eigentlichen Einstellungen sind in Gruppen organisiert. Sichtbar sind zum Beispiel `mower_logic`, `Mowing`, `Rain`, `Docking`, `Emergency`, `GPS`, `Load_Factor`, `path_order_optimizer` und `Undocking`. Jede Gruppe kann mit dem Pfeil aufgeklappt werden. Dadurch bleibt die Seite trotz vieler Parameter übersichtlich.

Änderungen sollten vorsichtig getestet werden. Manche Werte wirken sofort in der laufenden Session, andere erst nach dauerhaftem Speichern oder nach einem Neustart. Wenn Abweichungen angezeigt werden, sollte geprüft werden, ob aktive und gespeicherte Werte bewusst unterschiedlich sind. Vor größeren Änderungen sollten alte Werte dokumentiert werden, damit ein Rücksetzen möglich bleibt.

---

## Flächeneditor

Der `Flächeneditor` ist die getrennte Detailseite für Polygonbearbeitung. Hier werden Punkte, Auswahl und Geometrie einer Fläche bearbeitet. Er ist bewusst von Dashboard, Steuerung und Flächenübersicht getrennt, damit die normale Anzeige nicht durch den Bearbeitungsmodus blockiert wird.

Oben befindet sich die Werkzeugleiste. `Bearbeiten` aktiviert den Editiermodus für die ausgewählte Fläche. `Rückgängig` nimmt die letzte Änderung zurück, sofern eine Änderung verfügbar ist. `Verwerfen` verwirft ungespeicherte Änderungen. `Speichern` übernimmt die Änderungen. `Mehrfachauswahl`, `Punkte abwählen` und `Punkt löschen` dienen zur gezielten Punktbearbeitung.

Unter der Werkzeugleiste befindet sich das Auswahlfeld `Fläche zur Bearbeitung`. Hier muss zuerst die gewünschte Fläche ausgewählt werden. Wenn keine Fläche ausgewählt ist, bleiben viele Werkzeuge deaktiviert. Das ist normal und verhindert unbeabsichtigte Änderungen.

Die Statusleiste zeigt wichtige Bearbeitungsinformationen: Synchronstatus, ausgewählte Fläche, Typ, Punktanzahl, aktuelle Auswahl, Mehrfachauswahl und Rasterstatus. Im Kartenbereich wird die Fläche mit Punkten und Raster angezeigt. Rechts stehen Kartenwerkzeuge zum Zoomen, Verschieben, Zentrieren, zur Rasteranzeige und zur Zoomstufe bereit.

Der typische Ablauf ist: Fläche auswählen, `Bearbeiten` aktivieren, Ansicht passend zoomen, Punkte verändern, Ergebnis prüfen und danach speichern. Für mehrere Punkte kann die Mehrfachauswahl aktiviert werden. Nicht benötigte Auswahl wird über `Punkte abwählen` zurückgesetzt. Bei Punktlöschungen ist besondere Vorsicht nötig, weil wenige falsche Punkte die Fläche stark verändern können.

Der Editor verändert die Geometrie. Name, Reihenfolge und Aktiv-Schalter werden auf der Flächen-Seite gepflegt. Wenn eine Änderung nicht korrekt ist, sollte `Rückgängig` oder `Verwerfen` genutzt werden, bevor gespeichert wird.
