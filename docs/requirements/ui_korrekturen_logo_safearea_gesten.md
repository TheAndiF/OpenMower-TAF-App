# Anforderungen: Logo, unterer Systemrand und Gesten

Stand: 08.06.2026

## Ziel

Die Android-App soll auf Tablet/Smartphone sauberer wirken und die wichtigsten Bediengesten sollen sich nicht gegenseitig stören. Besonders betroffen sind das Launcher-Icon, der untere Android-/Samsung-Navigationsbereich, die Dashboard-Kartenbedienung und das Öffnen des Seitenmenüs.

## 1. App-Logo / Launcher-Icon

### Problem

Das OpenMower-Icon erscheint im Android-Launcher mit einem sichtbaren weißen Rand bzw. weißem Hintergrund. Das wirkt besonders auffällig, wenn der Launcher das Icon rund maskiert.

### Anforderung

- Das Android-Icon soll als adaptives Icon bereitgestellt werden.
- Der sichtbare weiße Rand soll vermieden werden.
- Für runde Launcher-Darstellung soll ein `roundIcon` vorhanden sein.
- Das Icon soll weiterhin aus den Projekt-Assets erzeugbar bleiben.

### Umsetzung im Paket

- Neues Vordergrund-Asset: `assets/openmower_taf_icon_foreground.png`
- Neues randfreies Icon-Asset: `assets/openmower_taf_icon_round.png`
- Adaptive-Icon-Ressourcen unter `android/app/src/main/res/mipmap-anydpi-v26/`
- Hintergrundfarbe `ic_launcher_background` in `android/app/src/main/res/values/colors.xml`
- `android:roundIcon` im AndroidManifest ergänzt
- `flutter_launcher_icons`-Konfiguration um adaptive Icon-Felder erweitert

## 2. Unterer Bildschirmrand / Android-Navigationsleiste

### Problem

Am unteren Bildschirmrand wird die Android-/Samsung-Navigationsleiste unschön überblendet. Inhalte laufen optisch zu weit nach unten bzw. wirken abgeschnitten.

### Anforderung

- Der untere SafeArea-Bereich soll respektiert werden.
- Die App-Inhalte sollen nicht unter der Android-Navigationsleiste liegen.
- Die Navigationsleiste soll sauber und hell eingefärbt werden.

### Umsetzung im Paket

- `SafeArea(top: false, bottom: true)` um den App-Body ergänzt.
- Android-Systemleisten werden in `main.dart` explizit gesetzt.
- Die Navigationsleiste unten wird weiß mit dunklen Icons dargestellt.

## 3. Zoomen auf der ersten Seite / Dashboard

### Problem

Das Zoomen auf der Dashboard-/Startseite ist nicht zuverlässig möglich. Vermutlich fängt die übergeordnete Swipe-Geste die Karten-/Zoom-Gesten ab.

### Anforderung

- Pinch-Zoom und Kartenbedienung sollen Vorrang haben.
- Mehrfinger-Gesten dürfen keinen Seitenwechsel auslösen.
- Der Seitenswipe soll nur bei eindeutigen horizontalen Wischgesten reagieren.

### Umsetzung im Paket

- Die bisherige `GestureDetector`-Logik für Seitenswipe wurde durch eine `Listener`-basierte Erkennung ersetzt.
- Mehrfinger-Gesten werden erkannt und brechen den Seitenswipe ab.
- Der Seitenwechsel reagiert nur noch auf klare, schnelle horizontale Swipes.

## 4. Menü-Geste ändern

### Problem

Das Menü wird bisher durch einfaches Wischen vom linken Rand geöffnet. Diese Geste kollidiert mit normalem Swipen und der Kartenbedienung.

### Anforderung

- Der normale linke Rand-Swipe soll deaktiviert werden.
- Das Menü soll über eine bewusstere Spezialgeste geöffnet werden.
- Gewünschte Geste: von links unten diagonal nach rechts oben wischen.

### Umsetzung im Paket

- `drawerEnableOpenDragGesture: false` gesetzt.
- Neue Listener-Geste im Android-App-Body ergänzt.
- Die Geste startet nur im linken unteren Bildschirmbereich.
- Das Menü öffnet, wenn die Bewegung eindeutig diagonal nach rechts oben erfolgt.

## 5. Gestentrennung

### Anforderung

Menü öffnen, Seitenwechsel und Karten-Zoom sollen getrennt funktionieren:

- Menü: links unten diagonal nach rechts oben
- Seitenwechsel: eindeutiger horizontaler Swipe
- Karte/Zoom: normale Karten- und Pinch-Gesten ohne Blockade durch Drawer-Geste

## Geänderte Kern-Dateien

- `lib/main.dart`
- `lib/screens/main_screen.dart`
- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/colors.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
- `android/app/src/main/res/drawable/ic_launcher_foreground.png`
- `assets/openmower_taf_icon_foreground.png`
- `assets/openmower_taf_icon_round.png`
