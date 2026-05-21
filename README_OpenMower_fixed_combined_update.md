# OpenMowerApp fixed combined update

Dieses Paket ersetzt das vorherige kombinierte Update und korrigiert den Build-Fehler.

## Enthaltene Änderungen

1. **Fix für Sensor-Values Build-Fehler**
   - Entfernt die fehlerhafte Verwendung von `..insert(...)` an `NikuGridView`.
   - Die Load-Factor-Kachel wird jetzt zuerst in einer normalen `List<Widget>` aufgebaut und dann an `..children` übergeben.

2. **Fix für `flutter_material_design_icons` / `IconData`**
   - Entfernt die Abhängigkeit `flutter_material_design_icons` aus `pubspec.yaml`.
   - `RobotStateWidget` verwendet jetzt nur noch Flutter-Material-Icons.
   - Dadurch wird der Fehler `IconData can't be implemented outside of its library because it's a final class` vermieden.

3. **Load-Factor-Kachel auf Sensor Values**
   - Neue Kachel `LoadFactorStatusWidget`.
   - Anzeige von effektivem Faktor, berechnetem Faktor und Ein/Aus-Status.

4. **Stabile Flutter-Keys**
   - Area-Eingaben verwenden stabile `area-$id-...` Keys.
   - Timetable-Eingaben verwenden stabile `timetable-$id-...` Keys.
   - Dadurch sollte das Textfeld beim Tippen nicht mehr den Fokus verlieren.

5. **Advanced Options Layout**
   - Advanced Options verwendet jetzt ebenfalls das Robot-State-Widget oben.
   - Layout wurde an die anderen Unterseiten angepasst.

## Dateien

- `pubspec.yaml`
- `lib/screens/advanced_options.dart`
- `lib/screens/mqtt_areas.dart`
- `lib/screens/timetable.dart`
- `lib/screens/sensor_values.dart`
- `lib/views/load_factor_status_widget.dart`
- `lib/views/robot_state_widget.dart`
- `openmower_fixed_combined_update.patch`

## Nach dem Einspielen

Bitte `flutter pub get` laufen lassen, damit die entfernte Icon-Abhängigkeit aus dem Dependency-Graph verschwindet.

Im Container stand kein Flutter/Dart SDK zur Verfügung, daher konnte kein lokaler Build ausgeführt werden. Die beiden gemeldeten Compiler-Ursachen wurden direkt adressiert.
