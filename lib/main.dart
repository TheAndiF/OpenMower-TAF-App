import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:open_mower_app/controllers/remote_controller.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/controllers/sensors_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/controllers/map_editor_controller.dart';
import 'package:open_mower_app/controllers/status_transition_log_controller.dart';
import 'package:open_mower_app/controllers/mower_logic_settings_controller.dart';
import 'package:open_mower_app/controllers/mow_load_factor_settings_controller.dart';
import 'package:open_mower_app/controllers/low_level_power_settings_controller.dart';
import 'package:open_mower_app/controllers/satellite_logging_controller.dart';
import 'package:open_mower_app/controllers/gps_state_controller.dart';
import 'package:open_mower_app/controllers/messenger_settings_controller.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';
import 'package:open_mower_app/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF36618E),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0xFFE0E0E0),
    ),
  );

  await GetStorage.init();

  // Put the settings controller first, other controllers might need it.
  final settingsController = Get.put(SettingsController());
  settingsController.load();

  // Second the robotStateController. MQTTConnection needs it
  Get.put(RobotStateController());
  Get.put(SensorsController());
  Get.put(TimetableController());
  Get.put(MqttAreasController());
  Get.put(MapEditorController());
  Get.put(StatusTransitionLogController());
  Get.put(MowerLogicSettingsController());
  Get.put(MowLoadFactorSettingsController());
  Get.put(LowLevelPowerSettingsController());
  Get.put(SatelliteLoggingController());
  Get.put(GpsStateController());
  Get.put(MessengerSettingsController());

  initServices();
  final MqttConnection mqttConnection = Get.find();

  mqttConnection.start();

  Get.put(RemoteController());

  // Periodic MQTT reconnect
  Timer.periodic(const Duration(seconds: 1), (timer) {
    mqttConnection.tryConnect();
  });






  runApp(const MyApp());
}


Future<void> initServices() async {
  if(!Get.isRegistered<MqttConnection>()) {
    Get.put<MqttConnection>(MqttConnection(), permanent: true);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Open Mower App',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
          useMaterial3: false,
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.light
      ),
      initialRoute: "/",
      getPages: [
        GetPage(name: "/", page: () => MainScreen())
      ],
    );
  }


}
