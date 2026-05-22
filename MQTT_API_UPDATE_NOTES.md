# MQTT API Update - 2026-05-21

Dieses Paket passt die OpenMower-App an die aktualisierte Kommunikationsstruktur vom 21.05.2026 an und trennt die Einstellungsnavigation in hardware- und softwarenahe Bereiche.

## Menü und Seitenstruktur

Unter dem Trennstrich im linken Menü liegen nun:

- **Einstellungen Hardware** mit Schraubenschlüssel-Piktogramm
- **Einstellungen Software** mit Schieberegler-Piktogramm

### Einstellungen Hardware

Enthält ausschließlich:

- `settings/ll_board`

### Einstellungen Software

Enthält:

- `settings/mower_logic`

Die Mäh-Lastregelung wird weiterhin als eigener UI-Abschnitt dargestellt, kommt aber aus `settings/mower_logic` und nicht mehr aus einem eigenen MQTT-Namespace.

Die Softwareseite gliedert die Inhalte in:

- **Mäh-Lastregelung**
- **Mäher-Logik**

## MQTT-Anpassungen

### Mäher-Logik

Die dynamischen Mäher-Logik-Settings werden jetzt über die vorgesehenen Topics verarbeitet:

- `settings/mower_logic/json`
- `settings/mower_logic/set/session/json`
- `settings/mower_logic/set/persistent/json`
- `settings/mower_logic/set/renew/json`
- `settings/mower_logic/validation/json`

### Mäh-Lastregelung

Der Mäh-Lastfaktor ist kein eigener Settings-Hauptbereich mehr. Die App filtert die `mow_load_*`-Einträge aus `settings/mower_logic/json` heraus und zeigt sie im Abschnitt **Mäh-Lastregelung** an.

Schreiben und Renew laufen über:

- `settings/mower_logic/json`
- `settings/mower_logic/set/session/json`
- `settings/mower_logic/set/persistent/json`
- `settings/mower_logic/set/renew/json`
- `settings/mower_logic/validation/json`

Auf `settings/mow_load_factor/...` wird nicht mehr abonniert. Alte retained Werte werden damit nicht mehr als dritter Settings-Bereich angezeigt.

## Robot State

Die App verarbeitet die laufenden Lastfaktor-Zustandswerte aus `robot_state/json`:

- `load_factor_computed`
- `load_factor_effective`

Diese Werte werden auf der Seite **Einstellungen Software** im Bereich **Mäh-Lastregelung** angezeigt.

## Neue Einstellung

`mow_motor_direction_mode` wird als Auswahlfeld angeboten:

- `-1` feste Richtung reverse/left
- `0` bei echtem Motorstart wechseln
- `1` feste Richtung forward/right

## Validierungsantworten

Die Verarbeitung von Rückmeldungen wurde robuster gemacht. `rejected` wird nun sowohl als Liste als auch als Map unterstützt, beispielsweise:

```json
{
  "rejected": {
    "motor_hot_temperature": "80"
  }
}
```

## UI-Texte

Veraltete Hinweise auf YAML-Persistenz wurden ersetzt. Die Oberfläche spricht nun von dauerhaftem Speichern in der persistenten Settings-Struktur.

## Hinweis zur Prüfung

Die Änderungen wurden statisch in den Projektstand eingearbeitet. Ein Flutter-/Dart-Build konnte in dieser Bearbeitungsumgebung nicht ausgeführt werden, weil die `flutter`- und `dart`-CLI nicht verfügbar waren.
