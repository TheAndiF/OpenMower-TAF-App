import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:niku/namespace.dart' as n;
import 'package:niku/niku.dart';
import 'package:open_mower_app/models/sensor_state.dart';
import 'current_gauge_widget.dart';
import 'rpm_gauge_widget.dart';
import 'temperature_gauge.dart';
import 'voltage_gauge_widget.dart';

class SensorWidget extends StatelessWidget {
  final SensorState? sensor;

  const SensorWidget({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    final sensor = this.sensor;

    if (sensor is StringSensorState) {
      return Material(
        color: const Color(0xFFEAEAEA),
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        child: n.Column([
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: sensor.name.bodyMedium
                ..color = Colors.black54
                ..textAlign = TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: AutoSizeText(
                sensor.value.isNotEmpty ? sensor.value : 'N/A',
                maxLines: 2,
                minFontSize: 12,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ])
          ..p = 12
          ..center,
      );
    }

    if (sensor is! DoubleSensorState) {
      return Material(
        color: const Color(0xFFEAEAEA),
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        child: n.Column([
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: (sensor?.name ?? 'N/A').bodyMedium
                ..color = Colors.black54
                ..textAlign = TextAlign.center,
            ),
          ),
          Expanded(
            child: AutoSizeText(
              'N/A',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ])
          ..p = 12
          ..center,
      );
    }

    switch (sensor.unit.toUpperCase()) {
      case 'RPM':
        return Material(
          color: const Color(0xFFEAEAEA),
        elevation: 1,
        surfaceTintColor: Colors.transparent,
          // RadialGauge Widget has issues with GaugeSegments when used in Column and most other widgets.
          // But ListView is working
          child: n.ListView.children([RpmGaugeWidget(sensor: sensor)])
            ..p = 12
            ..primary = false, // Disable scroll
        );
      case 'A':
      case 'V':
        // Vertical linear gauges
        return Material(
          color: const Color(0xFFEAEAEA),
        elevation: 1,
        surfaceTintColor: Colors.transparent,
          child: n.Row([
            // 2 rows in 3/1 flex
            Expanded(
              flex: 3,
              child: n.Column([
                // 3 columns, evenly distributed
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: sensor.name.bodyMedium
                      ..color = Colors.black54
                      ..textAlign = TextAlign.center,
                  ),
                ),
                Expanded(
                  child: AutoSizeText(
                    '${sensor.value.toStringAsFixed(2)} ${sensor.unit}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                Expanded(child: Container()),
              ])
                ..center,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: sensor.unit.toUpperCase() == 'V'
                    ? VoltageGaugeWidget(sensor: sensor)
                    : CurrentGaugeWidget(sensor: sensor),
              ),
            ),
          ])
            ..p = 12
            ..center,
        );
      default:
        // No, or horizontal gauge
        return Material(
          color: const Color(0xFFEAEAEA),
        elevation: 1,
        surfaceTintColor: Colors.transparent,
          child: n.Column([
            // 3 columns, evenly distributed
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: sensor.name.bodyMedium
                  ..color = Colors.black54
                  ..textAlign = TextAlign.center,
              ),
            ),
            Expanded(
              child: AutoSizeText(
                '${sensor.value.toStringAsFixed(
                  sensor.unit.toUpperCase() == 'M' ? 3 : 2,
                )} ${sensor.unit.replaceAll('deg.C', '°C')}',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
            Expanded(
              child: Container(
                child: sensor.unit.toUpperCase() == 'DEG.C'
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: TemperatureGauge(sensor: sensor),
                      )
                    : null,
              ),
            ),
          ])
            ..p = 12
            ..center,
        );
    }
  }
}
