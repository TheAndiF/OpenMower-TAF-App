# OpenMowerApp als Android-App bauen

Dieses Projekt enthält bereits die Android-Struktur (`android/`) und kann direkt als APK gebaut werden.

## Debug/Test auf einem Android-Handy

```bash
flutter pub get
flutter run
```

## Release-APK bauen

Für eine lokale Test-APK reicht:

```bash
flutter pub get
flutter build apk
```

Die Datei liegt danach unter:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## AppBundle für Google Play

```bash
flutter build appbundle
```

Die Datei liegt danach unter:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Signierung für echte Releases

1. Keystore erzeugen:

```bash
keytool -genkey -v -keystore android/app/openmower-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias openmower
```

2. Vorlage kopieren:

```bash
cp android/key.properties.example android/key.properties
```

Unter Windows PowerShell:

```powershell
Copy-Item android/key.properties.example android/key.properties
```

3. `android/key.properties` mit den echten Passwörtern füllen.

Danach nutzt Gradle automatisch die Release-Signierung. Ohne `key.properties` fällt das Projekt bewusst auf die Debug-Signierung zurück, damit Test-Builds weiterhin funktionieren.

## Kommunikation mit OpenMower/MQTT

Auf Android darf als MQTT-Host nicht `localhost` verwendet werden. `localhost` wäre das Handy selbst.

Im Heimnetz oder per WireGuard/VPN muss stattdessen die interne Adresse verwendet werden, z. B.:

```text
192.168.178.xx
```

Typischer Aufbau:

```text
Android-App -> WLAN/WireGuard -> MQTT-Broker/OpenMower
```

Der MQTT-Port `1883` sollte nicht direkt ins Internet freigegeben werden. Für Zugriff von unterwegs ist WireGuard/Tailscale die sinnvollere Variante.

## Android applicationId

Die feste Android App-ID / der Google-Play-Paketname der TAF-App lautet:

```text
de.theandif.openmower.taf
```

Diese ID ist die dauerhafte technische Identität der App im Play Store und sollte nach der Veröffentlichung nicht mehr geändert werden.
