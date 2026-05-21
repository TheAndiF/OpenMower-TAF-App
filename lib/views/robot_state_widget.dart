import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
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
