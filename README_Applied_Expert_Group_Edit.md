# Applied: Expertenmodus `group`-Metadaten-Edit

Diese Paketversion enthält die Änderung für den Expertenmodus:

- In den Mäher-Logik-Einstellungen kann im Expertenmodus das JSON-Feld `group` bearbeitet werden.
- Während der Eingabe wird nur ein Draft gehalten; die UI wird dadurch nicht sofort neu gruppiert.
- Beim dauerhaften Speichern wird `group` zusammen mit optional geänderten Werten an `settings/mower_logic/set/persistent/json` gesendet.
- Nach der Backend-Rückmeldung und neu empfangenem `settings/mower_logic/json` sortiert sich die Oberfläche wieder über den normalen Darstellungsprozess.

Hinweis: Das Backend muss `group` als persistentes Metadatum akzeptieren und erneut ausliefern.
