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
import 'package:open_mower_app/screens/settings.dart';
import 'package:open_mower_app/views/logo_widget.dart';
import 'package:open_mower_app/views/logo_widget_drawer.dart';

class MainScreen extends GetView<RobotStateController> {
  MainScreen({super.key});

  static const Color _drawerSectionBlue = Color(0xFFEAF3FF);

  final widgetList = <Widget>[
    Dashboard(),
    AdvancedOptions(),
    const SensorValues(),
    const TimetableScreen(),
    const MqttAreasScreen(),
    const StatusTransitionLogScreen(),
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
          child: Column(children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: buildDrawerList(),
              ),
            ),
            Obx(() => Text(robotStateController.softwareVersion.value).paddingAll(10))
          ]),
        ),
        body: Obx(() => widgetList[_index.value]));
  }

  ListTile _buildDrawerTile({
    required Widget leading,
    required String title,
    required int index,
    Color? tileColor,
  }) {
    return ListTile(
      tileColor: tileColor,
      leading: leading,
      title: Text(title),
      onTap: () {
        Get.back();
        _index.value = index;
      },
    );
  }

  Widget _buildBottomSettingsSection({required bool showDebugSettings}) {
    return Container(
      color: _drawerSectionBlue,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDrawerTile(
            leading: n.Icon(Icons.hardware),
            title: 'Mäher-Einstellungen',
            index: 6,
            tileColor: _drawerSectionBlue,
          ),
          if (showDebugSettings)
            _buildDrawerTile(
              leading: n.Icon(Icons.settings),
              title: 'Settings',
              index: 7,
              tileColor: _drawerSectionBlue,
            ),
        ],
      ),
    );
  }

  List<Widget> buildDrawerList() {
    final showDebugSettings = !kReleaseMode || !kIsWeb;

    return <Widget>[
      const DrawerHeader(
        decoration: BoxDecoration(
          color: Colors.blue,
        ),
        child: Padding(
            padding: EdgeInsets.all(24),
            child: FittedBox(
                child: LogoWidgetDrawer(size: 0.2))),
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
      Container(
        height: 12,
        color: _drawerSectionBlue,
      ),
      _buildBottomSettingsSection(showDebugSettings: showDebugSettings),
    ];
  }
}
