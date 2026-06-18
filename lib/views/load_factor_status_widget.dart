import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_mower_app/controllers/mow_load_factor_settings_controller.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';

class LoadFactorStatusWidget extends StatelessWidget {
  const LoadFactorStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final robotStateController = Get.find<RobotStateController>();
    final mowLoadFactorController = Get.find<MowLoadFactorSettingsController>();

    return Material(
      color: const Color(0xFFEAEAEA),
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      child: Obx(() {
        final robotState = robotStateController.robotState.value;
        final enabled = _enabledFromSettings(mowLoadFactorController.settings);
        final statusText = enabled == null ? 'Status unbekannt' : (enabled ? 'Eingeschaltet' : 'Ausgeschaltet');
        final statusIcon = enabled == null
            ? Icons.help_outline
            : enabled
                ? Icons.check_circle_outline
                : Icons.power_settings_new;
        final statusColor = enabled == null
            ? Colors.black38
            : enabled
                ? Colors.green[600]
                : Colors.grey[600];

        return n.Column([
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: 'Mäh-Lastfaktor'.bodyMedium
                ..color = Colors.black54
                ..textAlign = TextAlign.center,
            ),
          ),
          Expanded(
            child: AutoSizeText(
              _formatFactor(robotState.loadFactorEffective),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: AutoSizeText(
                        statusText,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AutoSizeText(
                  'berechnet ${_formatFactor(robotState.loadFactorComputed)}',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        ])
          ..p = 12
          ..center;
      }),
    );
  }

  bool? _enabledFromSettings(Map<String, Map<String, dynamic>> settings) {
    final setting = settings['enabled'] ??
        settings['mow_load_factor_enabled'] ??
        settings['load_factor_enabled'];
    if (setting == null) {
      return null;
    }
    return _boolOrNull(setting['active'] ?? setting['value'] ?? setting['persistent']);
  }

  bool? _boolOrNull(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
        case 'on':
        case 'enabled':
        case 'ein':
        case 'an':
          return true;
        case 'false':
        case '0':
        case 'no':
        case 'off':
        case 'disabled':
        case 'aus':
          return false;
      }
    }
    return null;
  }

  String _formatFactor(double value) {
    final text = value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }
}
