import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/views/emergency_widget.dart';
import 'package:niku/namespace.dart' as n;

class RobotStateWidget extends GetView<RobotStateController> {
  const RobotStateWidget({super.key});

  Widget getStateWidget() {
    final stateName = controller.robotState.value.currentState.toUpperCase();

    IconData iconData;
    switch (stateName) {
      case "IDLE":
        iconData = Icons.radio_button_unchecked;
        break;
      case "MOWING":
        iconData = MdiIcons.contentCut;
        break;
      case "PAUSED":
        iconData = Icons.pause;
        break;
      case "DOCKING":
        iconData = Icons.home_outlined;
        break;
      case "UNDOCKING":
        iconData = Icons.logout;
        break;
      case "AREA_RECORDING":
        iconData = Icons.edit_location_alt_outlined;
        break;
      default:
        iconData = Icons.help_outline;
        break;
    }

    final isAutoMow = controller.robotState.value.isAutoMow;
    final tooltipMessage = isAutoMow
        ? "${controller.robotState.value.currentState} · AutoMow"
        : controller.robotState.value.currentState;

    return Tooltip(
      message: tooltipMessage,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(iconData, color: Colors.black87)),
            if (isAutoMow)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green[200],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget getMqttIcon(BuildContext context, bool isConnected) {
    final icon = isConnected
        ? const Icon(Icons.link, color: Colors.black54)
        : Icon(Icons.link_off, color: Colors.red[200]);

    if (kIsWeb) {
      return Tooltip(message: 'MQTT-Verbindung', child: icon);
    }

    return Tooltip(
      message: 'MQTT-Verbindung einstellen',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showMqttSettingsDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: icon,
        ),
      ),
    );
  }

  void _showMqttSettingsDialog(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    // Ensure the text fields show the currently persisted MQTT values.
    settingsController.hostnameController.text = settingsController.hostname.value;
    settingsController.mqttUsernameController.text = settingsController.mqttUsername.value;
    settingsController.mqttPasswordController.text = settingsController.mqttPassword.value;
    settingsController.mqttPortController.text = settingsController.mqttPort.value.toString();

    String? portError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('MQTT-Verbindung'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: settingsController.hostnameController,
                        decoration: const InputDecoration(
                          labelText: 'Host / IP-Adresse',
                          hintText: 'z. B. 192.168.178.50',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: settingsController.mqttPortController,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          hintText: '1883',
                          errorText: portError,
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: settingsController.mqttUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Benutzername (optional)',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: settingsController.mqttPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Passwort (optional)',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hinweis: Auf Android darf hier nicht localhost stehen, sondern die IP-Adresse des MQTT-Brokers.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    settingsController.hostnameController.text = settingsController.hostname.value;
                    settingsController.mqttUsernameController.text = settingsController.mqttUsername.value;
                    settingsController.mqttPasswordController.text = settingsController.mqttPassword.value;
                    settingsController.mqttPortController.text = settingsController.mqttPort.value.toString();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final port = int.tryParse(settingsController.mqttPortController.text.trim());
                    if (port == null || port < 1 || port > 65535) {
                      setState(() => portError = 'Port muss zwischen 1 und 65535 liegen');
                      return;
                    }
                    portError = null;
                    settingsController.save();
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('MQTT-Einstellungen gespeichert. Verbindung wird neu aufgebaut.')),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Icon getGpsIcon(percent) {
    // TODO: Need gps_enabled flag for a reliable gps_not_fixed/gps_off icon
    if (percent > 0.75) {
      return Icon(Icons.gps_fixed, color: Colors.green[200]);
    } else if (percent >= 0.25) {
      return Icon(Icons.gps_not_fixed, color: Colors.orange[200]);
    }
    return Icon(Icons.gps_off, color: Colors.grey[400]);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        elevation: 5,
        child: Obx(() => n.Row([
          EmergencyWidget(emergency: controller.robotState.value.isEmergency),
          RichText(
              text: TextSpan(
                  style: const TextStyle(color: Colors.black87),
                  children: [
                const TextSpan(text: "State: "),
                WidgetSpan(
                    child: getStateWidget(),
                    alignment: PlaceholderAlignment.middle),
              ])),
          RichText(
              text: TextSpan(
                  style: const TextStyle(color: Colors.black87),
                  children: [
                const TextSpan(text: "MQTT: "),
                WidgetSpan(
                    child: getMqttIcon(context, controller.robotState.value.isConnected),
                    alignment: PlaceholderAlignment.middle),
              ])),
          RichText(
              text: TextSpan(
                  style: const TextStyle(color: Colors.black87),
                  children: [
                const TextSpan(text: "GPS: "),
                WidgetSpan(
                    child: getGpsIcon(controller.robotState.value.gpsPercent),
                    alignment: PlaceholderAlignment.middle),
              ])),
          RichText(
              text: TextSpan(
                  style: const TextStyle(color: Colors.black87),
                  children: [
                const TextSpan(text: "Battery: "),
                WidgetSpan(
                    child: getBatteryIcon(
                        controller.robotState.value.batteryPercent,
                        controller.robotState.value.isCharging),
                    alignment: PlaceholderAlignment.middle),
              ]))
        ])
          ..mainAxisAlignment = MainAxisAlignment.end
          ..m = 16
          ..gap = 8));
  }

  Icon getBatteryIcon(double percent, bool charging) {
    final IconData iconData;
    if (percent <= 0) {
      iconData = MdiIcons.batteryUnknown;
    } else if (charging) {
      if (percent >= 0.95) {
        iconData = MdiIcons.batteryCharging100;
      } else if (percent >= 0.85) {
        iconData = MdiIcons.batteryCharging90;
      } else if (percent >= 0.75) {
        iconData = MdiIcons.batteryCharging80;
      } else if (percent >= 0.65) {
        iconData = MdiIcons.batteryCharging70;
      } else if (percent >= 0.55) {
        iconData = MdiIcons.batteryCharging60;
      } else if (percent >= 0.45) {
        iconData = MdiIcons.batteryCharging50;
      } else if (percent >= 0.35) {
        iconData = MdiIcons.batteryCharging40;
      } else if (percent >= 0.25) {
        iconData = MdiIcons.batteryCharging30;
      } else if (percent >= 0.15) {
        iconData = MdiIcons.batteryCharging20;
      } else {
        iconData = MdiIcons.batteryCharging10;
      }
    } else if (percent >= 0.95) {
      iconData = MdiIcons.battery;
    } else if (percent >= 0.85) {
      iconData = MdiIcons.battery90;
    } else if (percent >= 0.75) {
      iconData = MdiIcons.battery80;
    } else if (percent >= 0.65) {
      iconData = MdiIcons.battery70;
    } else if (percent >= 0.55) {
      iconData = MdiIcons.battery60;
    } else if (percent >= 0.45) {
      iconData = MdiIcons.battery50;
    } else if (percent >= 0.35) {
      iconData = MdiIcons.battery40;
    } else if (percent >= 0.25) {
      iconData = MdiIcons.battery30;
    } else if (percent >= 0.15) {
      iconData = MdiIcons.battery20;
    } else {
      iconData = MdiIcons.battery10;
    }

    return Icon(
      iconData,
      color: percent > 0.4
          ? Colors.black54
          : percent > 0.2
              ? Colors.orange[300]
              : percent > 0
                  ? Colors.red[200]
                  : Colors.grey[400],
    );
  }

}
