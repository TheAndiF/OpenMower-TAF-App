# Expertenmodus: JSON-Feld `group` für alle Settings

Dieses Paket erweitert die zuvor umgesetzte Bearbeitung des JSON-Metadatenfelds `group` auf alle aktuell vorhandenen Settings-Bereiche der App.

## Enthaltene Bereiche

- Mäher-Logik aus `settings/mower_logic/json`
- Mäh-Lastregelung aus `settings/mower_logic/json`
- Low-Level-Board / Hardwarewerte aus `settings/ll_board/json`

## Verhalten

- Das Feld `group` wird nur im Expertenmodus angezeigt.
- Während der Eingabe wird das empfangene Setting-JSON nicht direkt verändert.
- Dadurch wird während des Tippens nicht lokal neu gruppiert oder neu sortiert.
- Die Änderung wird als Draft gehalten.
- Erst beim dauerhaften Speichern wird `group` zusammen mit optional geänderten Werten ans Backend gesendet.
- Nach der Backend-Rückmeldung und dem erneuten Status-JSON läuft die normale Gruppierung/Sichtung der UI.

## Beispiel-Payload

Nur Gruppe geändert:

```json
{
  "battery_full_voltage": {
    "group": "hardware_power"
  }
}
```

Wert und Gruppe geändert:

```json
{
  "mow_load_current_start": {
    "value": 0.75,
    "group": "mowing_load_control"
  }
}
```

## Wichtig

Das Backend muss Metadaten-Updates im Objektformat akzeptieren, also z. B. `{ "value": ..., "group": ... }`. Session-Anwenden sendet weiterhin nur live anwendbare Wertänderungen; `group` wird nur beim dauerhaften Speichern gesendet.
