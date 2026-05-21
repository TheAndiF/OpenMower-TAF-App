import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
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
        iconData = Icons.content_cut;
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

    return Tooltip(
      message: controller.robotState.value.currentState,
      child: Icon(iconData, color: Colors.black87),
    );
  }

  Icon getMqttIcon(bool isConnected) {
    return isConnected
        ? const Icon(Icons.link, color: Colors.black54)
        : Icon(Icons.link_off, color: Colors.red[200]);
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
                    child: getMqttIcon(controller.robotState.value.isConnected),
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
    if (charging) {
      return Icon(
        Icons.battery_charging_full,
        color: percent > 0.4
            ? Colors.black54
            : percent > 0.2
                ? Colors.orange[300]
                : Colors.red[200],
      );
    }

    if (percent > 0.4) {
      return const Icon(Icons.battery_full, color: Colors.black54);
    } else if (percent > 0.2) {
      return Icon(Icons.battery_alert, color: Colors.orange[300]);
    } else if (percent > 0) {
      return Icon(Icons.battery_alert, color: Colors.red[200]);
    }

    return Icon(Icons.battery_unknown, color: Colors.grey[400]);
  }

}
