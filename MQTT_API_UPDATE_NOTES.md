# MQTT API Update - 2026-05-19

Dieses Projekt wurde an die aktualisierte OpenMower-MQTT-Spezifikation angepasst.

## Umgestellt

- Mäh-Lastfaktor-Settings von `settings/mower_logic/...` auf `settings/mow_load_factor/...`
- Low-Level-Board-Settings von `ll_power/...` auf `settings/ll_board/...`
- LL-Board Statusverarbeitung für das neue `settings_v1`-Schema mit `default`, `persistent`, `active`, `different`
- LL-Board Schreiboperationen getrennt in:
  - `settings/ll_board/set/session/json`
  - `settings/ll_board/set/persistent/json`
- Verarbeitung der Settings-Validierungsantworten mit `mode`, `accepted`, `rejected`
- Map-Overlay Unterstützung für:
  - `map/overlay/json`
  - `map/overlay/bson`
  - Legacy-Aliase `map_overlay/json` und `map_overlay/bson`
- Empfang von `map/bson` und `map/validation/bson`
- Renew-Aufrufe für Timetable, Map und Settings senden nun leere JSON-Objekte `{}`

## UI-Anpassungen

- Texte und JSON-Hinweise auf die neuen Settings-Topics aktualisiert
- Low-Level-Board kann live getestet oder dauerhaft gespeichert werden
- Validierungsrückmeldungen werden im LL-Board-Status sichtbar gemacht
- Min-/Max-Hinweise aus den Settings-Metadaten werden in der LL-Board-Oberfläche angezeigt

## Hinweis zur Prüfung

Die Änderungen wurden statisch gegen die MQTT-Spezifikation eingepflegt. Ein Flutter/Dart-Build konnte in der Bearbeitungsumgebung nicht ausgeführt werden, da die Flutter-/Dart-CLI dort nicht verfügbar war.
