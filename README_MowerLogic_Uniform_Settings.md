# Mower-Logic-Einstellungen einheitlich behandelt

Diese Paketversion entfernt die Frontend-Sonderbehandlung der Mäh-Lastregelung innerhalb der Software-Einstellungen.

## Änderung

Alle Einträge aus `settings/mower_logic/json` werden jetzt im `MowerLogicSettingsController` gleich behandelt.

Vorher wurden Einträge mit Keys/Gruppen wie `mow_load_*`, `load_factor_*`, `mow_load_factor` oder `mowing_load_control` aus der normalen Mower-Logic-Liste herausgefiltert und in einem separaten Mäh-Lastregelungsbereich angezeigt.

Jetzt gilt:

```text
settings/mower_logic/json
  -> alle settings-Einträge
  -> ein Controller
  -> Gruppierung ausschließlich nach JSON-Feld group
  -> Expertenmodus kann group editieren
  -> Speichern ans Backend
  -> Neuordnung erst nach Backend-Rückmeldung
```

## Betroffene Dateien

- `lib/controllers/mower_logic_settings_controller.dart`
  - Filter auf Mäh-Lastregelung entfernt.
  - `setStatusPayload()` übernimmt jetzt alle Map-Einträge aus `settings`.

- `lib/screens/mower_logic_settings.dart`
  - Separater Mäh-Lastregelungsbereich entfernt.
  - Beim Öffnen wird nur noch der normale Mower-Logic-Status angefordert.
  - Alle Mower-Logic-Werte erscheinen im normalen Gruppierungsprozess.

## Ergebnis

Eine Mäh-Lastregelung mit z. B.

```json
{
  "group": "mowing_load_control"
}
```

erscheint als normale Gruppe innerhalb der Software-Einstellungen. Wird `group` im Expertenmodus geändert, bleibt die UI während des Edits stabil und wird erst nach dem Speichern und nach der Backend-Rückmeldung neu sortiert.
