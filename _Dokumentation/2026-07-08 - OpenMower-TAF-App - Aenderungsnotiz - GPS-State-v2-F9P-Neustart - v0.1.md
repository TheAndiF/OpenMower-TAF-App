# OpenMower-TAF-App - Änderungsnotiz - GPS-State v2 und F9P-Neustart

Datum: 2026-07-08  
Version: v0.1  
Bezug: Anpassung der App an die bereitgestellten OpenMower-TAF-ROS-PDFs zu GPS-State-Trennung und F9P-Neustart unter `gps_state`.

## Umgesetzte Punkte

- `gps_state/state0` wird abonniert und als Experten-/Debugtabelle für die Fahrfähigkeits-Entscheidungskette angezeigt.
- State1 wurde auf die kompakte Bedieneranzeige reduziert: Fahrfreigabe, Grund, Blockiergrund, RTK-Zustand, Genauigkeit, Grenzwert, Pose-Alter und `quality_class`.
- State2 zeigt die technische GNSS-/Pose-Zusammenfassung mit Aggregaten, C/N0-Werten, Systemverteilung, Pose-/Timeout-Diagnose und `drive_diagnostics`.
- State3 zeigt ausschließlich aktiv verwendete Satelliten; die Used-Spalte ist dort bewusst ausgeblendet.
- State4 zeigt die Expertenliste aller sichtbaren Satelliten inklusive `used=true/false` und aggregierten Kennwerten.
- F9P-Neustart wurde in die GPS-State-Seite integriert: Hot Start, Warm Start, Cold Start und Reset-Mode-Auswahl.
- MQTT-Topics für Restart-Status, Restart-Validierung und Restart-Renew wurden ergänzt.
- Dokumentation in `docs/mqtt-schnittstelle.md` und `docs/bedienungsanleitung.md` wurde ergänzt.

## Geänderte Dateien

- `lib/controllers/gps_state_controller.dart`
- `lib/io/mqtt_connection.dart`
- `lib/screens/gps_state.dart`
- `docs/mqtt-schnittstelle.md`
- `docs/bedienungsanleitung.md`
- `commit_message_gps_state_v2_f9p_app.txt`
