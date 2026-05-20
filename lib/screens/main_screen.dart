import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/screens/dashboard.dart';
import 'package:open_mower_app/screens/advanced_options.dart';
import 'package:open_mower_app/screens/sensor_values.dart';
import 'package:open_mower_app/screens/timetable.dart';
import 'package:open_mower_app/screens/mqtt_areas.dart';
import 'package:open_mower_app/screens/status_transition_log.dart';
import 'package:open_mower_app/screens/mower_logic_settings.dart';
import 'package:open_mower_app/screens/hardware_settings.dart';
import 'package:open_mower_app/screens/settings.dart';
import 'package:open_mower_app/views/logo_widget.dart';
import 'package:open_mower_app/views/logo_widget_drawer.dart';

class MainScreen extends GetView<RobotStateController> {
  MainScreen({super.key});

  final widgetList = <Widget>[
    Dashboard(),
    AdvancedOptions(),
    const SensorValues(),
    const TimetableScreen(),
    const MqttAreasScreen(),
    const StatusTransitionLogScreen(),
    const HardwareSettingsScreen(),
    const MowerLogicSettingsScreen(),
    const Settings(),
  ];

  final _index = 0.obs;

  final RobotStateController robotStateController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LogoWidget(size: 200),
        titleSpacing: 0,
        elevation: 10,
        shadowColor: Colors.black,
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: buildDrawerList(),
              ),
            ),
            Obx(() => Text(robotStateController.softwareVersion.value).paddingAll(10)),
          ],
        ),
      ),
      body: Obx(() => widgetList[_index.value]),
    );
  }

  ListTile _buildDrawerTile({
    required Widget leading,
    required String title,
    required int index,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title),
      onTap: () {
        Get.back();
        _index.value = index;
      },
    );
  }

  List<Widget> buildDrawerList() {
    final drawerList = <Widget>[
      const DrawerHeader(
        decoration: BoxDecoration(
          color: Colors.blue,
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: FittedBox(
            child: LogoWidgetDrawer(size: 0.2),
          ),
        ),
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.speed),
        title: 'Dashboard',
        index: 0,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.settings_applications),
        title: 'Advanced Options',
        index: 1,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.line_axis),
        title: 'Sensor Values',
        index: 2,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.event_note),
        title: 'Timetable',
        index: 3,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.grass),
        title: 'Flächen',
        index: 4,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.receipt_long),
        title: 'Protokoll',
        index: 5,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(68, 2, 22, 2),
        child: Divider(height: 1),
      ),
      _buildDrawerTile(
        leading: const _HardwareSettingsDrawerIcon(),
        title: 'Hardwarenahe Einstellungen',
        index: 6,
      ),
      _buildDrawerTile(
        leading: const _SoftwareSettingsDrawerIcon(),
        title: 'Softwarenahe Einstellungen',
        index: 7,
      ),
    ];

    if (!kReleaseMode || !kIsWeb) {
      drawerList.add(
        _buildDrawerTile(
          leading: n.Icon(Icons.settings),
          title: 'Settings',
          index: 8,
        ),
      );
    }

    return drawerList;
  }
}

class _HardwareSettingsDrawerIcon extends StatelessWidget {
  const _HardwareSettingsDrawerIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.grey;
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Icon(Icons.build, size: 25, color: color),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: CustomPaint(
              size: const Size(14, 14),
              painter: _HexNutPainter(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftwareSettingsDrawerIcon extends StatelessWidget {
  const _SoftwareSettingsDrawerIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.grey;
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        size: const Size(28, 28),
        painter: _SliderIconPainter(color),
      ),
    );
  }
}

class _SliderIconPainter extends CustomPainter {
  const _SliderIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    final knob = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final y1 = size.height * 0.25;
    final y2 = size.height * 0.50;
    final y3 = size.height * 0.75;
    canvas.drawLine(Offset(size.width * 0.10, y1), Offset(size.width * 0.90, y1), line);
    canvas.drawLine(Offset(size.width * 0.10, y2), Offset(size.width * 0.90, y2), line);
    canvas.drawLine(Offset(size.width * 0.10, y3), Offset(size.width * 0.90, y3), line);
    canvas.drawCircle(Offset(size.width * 0.65, y1), 3.4, knob);
    canvas.drawCircle(Offset(size.width * 0.35, y2), 3.4, knob);
    canvas.drawCircle(Offset(size.width * 0.55, y3), 3.4, knob);
  }

  @override
  bool shouldRepaint(covariant _SliderIconPainter oldDelegate) => oldDelegate.color != color;
}

class _HexNutPainter extends CustomPainter {
  const _HexNutPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    final hole = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.06)
      ..lineTo(size.width * 0.73, size.height * 0.06)
      ..lineTo(size.width * 0.96, size.height * 0.50)
      ..lineTo(size.width * 0.73, size.height * 0.94)
      ..lineTo(size.width * 0.27, size.height * 0.94)
      ..lineTo(size.width * 0.04, size.height * 0.50)
      ..close();

    canvas.drawPath(path, outline);
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      size.width * 0.18,
      hole,
    );
  }

  @override
  bool shouldRepaint(covariant _HexNutPainter oldDelegate) => oldDelegate.color != color;
}
