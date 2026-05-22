# Expertenmodus: JSON-Feld `group` editieren

Dieses Update erweitert die Mäher-Logik-Einstellungsseite im Expertenmodus.

## Verhalten

- Im Expertenmodus erscheint pro Mäher-Logik-Einstellung ein zusätzliches Textfeld **JSON-Feld „group“**.
- Der Wert wird als Draft im Controller gehalten und ändert nicht sofort `setting['group']`.
- Während der Eingabe wird die Liste deshalb nicht lokal neu gruppiert oder umsortiert.
- Erst **Dauerhaft speichern** sendet die Änderung an `settings/mower_logic/set/persistent/json`.
- Nach der Backend-Rückmeldung und dem nächsten `settings/mower_logic/json` wird die Oberfläche wie bisher aus dem Backend-Status neu aufgebaut und dadurch normal neu gruppiert.

## Payload für Gruppen-Metadaten

Wenn nur die Gruppe geändert wurde, sendet die App z. B.:

```json
{
  "motor_hot_temperature": {
    "group": "mower_logic"
  }
}
```

Wenn Wert und Gruppe gleichzeitig geändert wurden, sendet die App:

```json
{
  "motor_hot_temperature": {
    "value": 80,
    "group": "mower_logic"
  }
}
```

Dafür muss das Backend Metadaten-Updates in dieser Form akzeptieren, speichern und anschließend über `settings/mower_logic/json` wieder ausliefern.

## Geänderte Dateien

- `lib/controllers/mower_logic_settings_controller.dart`
- `lib/screens/mower_logic_settings.dart`
