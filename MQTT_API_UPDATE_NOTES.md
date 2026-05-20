# MQTT API Update - 2026-05-20

Dieses Paket passt die OpenMower-App an die Kommunikationsstruktur vom 20.05.2026 an und trennt die Einstellungsnavigation in hardware- und softwarenahe Bereiche.

## Menü und Seitenstruktur

Unter dem Trennstrich im linken Menü liegen nun:

- **Hardwarenahe Einstellungen** mit Schraubenschlüssel-/Mutter-Piktogramm
- **Softwarenahe Einstellungen** mit Schieberegler-Piktogramm

### Hardwarenahe Einstellungen

Enthält ausschließlich:

- `settings/ll_board`

### Softwarenahe Einstellungen

Enthält:

- `settings/mow_load_factor`
- `settings/mower_logic`

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

Der Mäh-Lastfaktor bleibt als eigener Settings-Bereich erhalten:

- `settings/mow_load_factor/json`
- `settings/mow_load_factor/set/session/json`
- `settings/mow_load_factor/set/persistent/json`
- `settings/mow_load_factor/set/renew/json`

## Robot State

Die App verarbeitet zusätzlich die laufenden Lastfaktor-Zustandswerte aus `robot_state/json`:

- `load_factor_computed`
- `load_factor_effective`

Diese Werte werden auf der Seite **Softwarenahe Einstellungen** im Bereich **Mäh-Lastregelung** angezeigt.

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
