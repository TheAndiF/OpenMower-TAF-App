# OpenMowerApp Update: Expertenmodus + MDI-Batterieicons

Dieses Paket basiert auf dem zuletzt kombinierten Update und ergänzt/korrigiert:

## Enthalten

1. **Advanced Options standardmäßig ausgeblendet**
   - Der Menüpunkt `Advanced Options` wird im linken Menü nur angezeigt, wenn der Expertenmodus aktiv ist.
   - Standardwert nach Erstinstallation/Update: ausgeschaltet.

2. **Expertenmodus in Einstellungen Software**
   - Auf der Seite `Einstellungen Software` gibt es jetzt eine neue Kachel `Expertenmodus`.
   - Über den Schalter wird `Advanced Options` ein- oder ausgeblendet.
   - Die Einstellung wird lokal in `GetStorage` unter `expert_mode_enabled` gespeichert.

3. **Material Design Icons bleiben erhalten**
   - `flutter_material_design_icons` wird wieder verwendet.
   - Die Abhängigkeit wurde in `pubspec.yaml` auf `^3.1.0` gesetzt.
   - Das Robot-Widget nutzt wieder die abgestuften MDI-Batteriesymbole:
     - `MdiIcons.batteryCharging100` ... `batteryCharging10`
     - `MdiIcons.battery` ... `battery10`
     - `MdiIcons.batteryUnknown`
   - Für den Mähstatus wird wieder `MdiIcons.contentCut` verwendet.

4. **Vorherige kombinierte Änderungen bleiben enthalten**
   - stabile Flutter-Keys für Flächen und Timetable
   - Load-Factor-Kachel in Sensor Values
   - Advanced-Options-Seite im gleichen Stil mit Robot-Widget

## Einspielen

Im Projekt-Hauptverzeichnis entpacken, also dort, wo auch `pubspec.yaml` liegt:

```bash
unzip OpenMowerApp_expertmode_mdi_combined_update.zip
flutter pub get
```

Danach den Build erneut starten.

## Hinweis

Im Container war kein Flutter/Dart SDK verfügbar. Daher konnte kein lokaler `flutter build` oder `dart analyze` ausgeführt werden.
