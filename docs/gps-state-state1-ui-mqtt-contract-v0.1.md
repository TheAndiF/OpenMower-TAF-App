# OpenMower-TAF-App - GPS-State State1 UI und MQTT-Struktur - v0.1

Stand: 2026-07-15

## UI-Verhalten

- Die bisherigen oberen Zusammenfassungskacheln (`Status`, `RTK`, `Genauigkeit`, `Grenzwert`, `Pose-Alter`, `Quality`) entfallen.
- Vor Prüfstufe 1 wird eine rein informative, nicht nummerierte Zeile `Current Status` angezeigt.
- Zwischen Prüfstufe 1 und Prüfstufe 2 wird eine rein informative Zeile `GPS Quality` angezeigt.
- Informationszeilen verwenden ein blaues Info-Symbol und nehmen nicht an der Freigabeentscheidung teil.
- In der Spalte `Aktueller Wert` wird nur der Ist-Wert angezeigt. Grenzwerte und Sollbedingungen stehen ausschließlich in der Spalte `Bedingung`.
- Meterwerte unter 1 m werden für die Anzeige in Zentimeter umgerechnet; Sekundenwerte werden kompakt formatiert.
- Prüfstufe 12 wird aus denselben Root-Feldern `drive_ready` und `drive_state` abgeleitet wie der Fahrfreigabe-Banner. Dadurch können Banner, Abschnittssymbol und Prüfstufe 12 nicht mehr unterschiedliche Freigabezustände anzeigen.

## Erwartete MQTT-Topics

- Definition, retained: `gps_state/state1/definition`
- Live-Status, retained bzw. periodisch/eventbasiert: `gps_state/state1/status`
- Aktualisierungsanforderung: bestehendes kanonisches State1-Request-/Renew-Topic der App

## Erwartete Root-Felder in `gps_state/state1/status`

```json
{
  "schema": "gps_state.v3",
  "state": "state1",
  "type": "status",
  "definition_version": 3,
  "timestamp": 1784143378.2118914,
  "current_status": "mowing",
  "quality_class": "very_good",
  "drive_ready": true,
  "drive_state": "ready",
  "severity": 0,
  "blocking_stage": null,
  "blocking_key": null,
  "blocking_title": null,
  "summary": "GPS-Fahrfreigabe erteilt",
  "checks": {},
  "available": true,
  "stale": false,
  "status": "ok"
}
```

### Feldbedeutung

| Feld | Typ | Pflicht | Verwendung |
|---|---|---:|---|
| `current_status` | String | empfohlen | Informative Zeile 0. Beispielwerte: `mowing`, `idle`, `docking`, `charging`, `paused`, `unknown`. |
| `quality_class` | String | empfohlen | Informative Zeile zwischen 1 und 2. Beispiel: `very_good`. |
| `drive_ready` | Boolean | ja | Kanonische Fahrfreigabe für Banner, Abschnittssymbol und Prüfstufe 12. |
| `drive_state` | String | ja | Kanonischer textueller Fahrzustand, z. B. `ready`, `blocked`, `stop`, `unknown`. |
| `severity` | Integer | ja | `0` bei eindeutig freigegebenem Zustand; größer 0 bei Warnung/Fehler. |
| `blocking_stage` | Integer/null | ja | Nummer des ersten Blockierers oder `null`. |
| `blocking_key` | String/null | ja | Schlüssel des ersten Blockierers oder `null`. |
| `summary` | String | empfohlen | Kurze Gesamterklärung für den Banner. |
| `checks` | Object | ja | Live-Werte der 12 Entscheidungsknoten. |
| `available` | Boolean | empfohlen | Muss bei verwertbarem Status `true` sein. |
| `stale` | Boolean | empfohlen | Kennzeichnet veraltete Daten. |
| `status` | String | empfohlen | Zusammenfassender Transportstatus, z. B. `ok`, `warning`, `error`, `unknown`. |

Die App akzeptiert für eine Übergangszeit auch `mowing_status` als Fallback für `current_status` sowie die Legacy-Felder `gps_drive_ready` und `gps_drive_state`.

## Konsistenzregeln

1. `drive_ready == true` verlangt `drive_state == "ready"`, `severity == 0`, keinen Blockierer und eine erfolgreiche Prüfstufe 12.
2. `drive_ready == false` verlangt einen blockierten/gestoppten `drive_state`; Prüfstufe 12 wird rot dargestellt.
3. Ein unbekannter oder fehlender `drive_ready`-Wert führt zu `nicht eindeutig` in Prüfstufe 12.
4. `current_status` und `quality_class` sind Informationen und dürfen `drive_ready` nicht eigenständig verändern.
5. Bedingungen werden aus der Definition gelesen; der Status liefert den aktuellen `value`. Das optionale Feld `display` darf ausführlicher sein, wird für die kompakte Tabellenanzeige aber nicht als primärer Ist-Wert verwendet.

## Beispiel für Checks

```json
{
  "checks": {
    "01_gps_enabled": {
      "stage": 1,
      "key": "gps_enabled",
      "status": "ok",
      "severity": 0,
      "value": true,
      "expected": true
    },
    "03_gps_input_accuracy": {
      "stage": 3,
      "key": "gps_input_accuracy",
      "status": "ok",
      "severity": 0,
      "value": 0.014,
      "threshold": 0.2
    },
    "12_gps_drive_ready": {
      "stage": 12,
      "key": "gps_drive_ready",
      "status": "ok",
      "severity": 0,
      "value": true,
      "expected": true
    }
  }
}
```

Für Prüfstufe 12 gelten die Root-Felder als kanonisch. Abweichende Werte im Check werden in der App nicht mehr als eigenständige Fahrfreigabe dargestellt.


## UI-Ergänzung v0.2

- `Current Status` wird ohne Stufennummer dargestellt und vorrangig aus `current_status` gelesen.
- Der Gesamtbanner verwendet `drive_ready`, `drive_state`, `blocking_stage` und `blocking_title` als fachlich führende Werte.
- Bei vorhandenem Blockierer werden erfolgreiche Stufen vor dem Blockierer durch einen ausgefüllten Kreis in der jeweiligen Statusfarbe gekennzeichnet.
- `gps_quality` wird als aktuelle Qualitätsquelle unterstützt; `quality_class` bleibt als Kompatibilitätsrückfall erhalten.
