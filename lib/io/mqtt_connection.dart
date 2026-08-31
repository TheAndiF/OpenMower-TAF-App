
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:open_mower_app/controllers/sensors_controller.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/controllers/status_transition_log_controller.dart';
import 'package:open_mower_app/controllers/mower_logic_settings_controller.dart';
import 'package:open_mower_app/controllers/mow_load_factor_settings_controller.dart';
import 'package:open_mower_app/controllers/low_level_power_settings_controller.dart';
import 'package:open_mower_app/controllers/satellite_logging_controller.dart';
import 'package:open_mower_app/controllers/gps_state_controller.dart';
import 'package:open_mower_app/controllers/messenger_settings_controller.dart';
import 'package:open_mower_app/models/map_model.dart';
import 'package:open_mower_app/models/robot_state.dart';
import 'package:open_mower_app/models/map_overlay_model.dart';
import 'package:open_mower_app/models/mowing_progress_model.dart';

import 'server.dart' if (dart.library.html) 'browser.dart' as mqttclient;
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'dart:math';
import 'dart:ui';
import 'package:bson/bson.dart';
import 'package:typed_data/typed_data.dart';

class MqttConnection  {


  static final MqttConnection _instance = MqttConnection._internal();
  int clientId = 0;
  // singleton constructor
  MqttConnection._internal() {
    final rng = Random();
    clientId = rng.nextInt(99999);
  }

  factory MqttConnection() {
    return _instance;
  }

  bool _connecting = false;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSubscription;
  DateTime? _lastConnectAttempt;
  int _reconnectDelaySeconds = 1;

  final SettingsController settingsController = Get.find();
  final RobotStateController robotStateController = Get.find();
  final SensorsController sensorsController = Get.find();
  final TimetableController timetableController = Get.find();
  final MqttAreasController mqttAreasController = Get.find();
  final StatusTransitionLogController statusTransitionLogController = Get.find();
  final MowerLogicSettingsController mowerLogicSettingsController = Get.find();
  final MowLoadFactorSettingsController mowLoadFactorSettingsController = Get.find();
  final LowLevelPowerSettingsController lowLevelPowerSettingsController = Get.find();
  final SatelliteLoggingController satelliteLoggingController = Get.find();
  final GpsStateController gpsStateController = Get.find();
  final MessengerSettingsController messengerSettingsController = Get.find();

  final RegExp exp = RegExp(r'^sensors/([^/]+)/bson$');
  final RegExp expJson = RegExp(r'^sensors/([^/]+)/json$');
  final RegExp expData = RegExp(r'^sensors/([^/]+)/data$');

  final client = mqttclient.get();

  static const String timetableTopic = "timetable/json";
  static const String timetableBsonTopic = "timetable/bson";
  static const String timetableRenewJsonTopic = "timetable/set/renew/json";
  static const String timetableSetTopic = "timetable/set/json";
  static const String timetableValidationJsonTopic = "timetable/validation/json";
  static const String timetableValidationBsonTopic = "timetable/validation/bson";
  static const String timetableSuspensionSetJsonTopic = "timetable/set/suspension/json";

  // Legacy topics kept for compatibility with older services.
  static const String timetableRequestTopic = "timetable/request";
  static const String timetableResponseTopic = "timetable/response/json";
  static const String timetableAckTopic = "timetable/ack/json";
  static const String timetableStatusTopic = "/openmower/timetable/status/json";
  static const String timetableSetJsonTopic = "/openmower/timetable/config/set/json";
  static const String timetableActionResultTopic = "/openmower/timetable/action_result/json";

  static const String timeStatusJsonTopic = "/openmower/time/status/json";
  static const String timeStatusBsonTopic = "/openmower/time/status/bson";
  static const String timeActionJsonTopic = "/openmower/time/action/json";
  static const String timeActionBsonTopic = "/openmower/time/action/bson";
  static const String timeActionResultJsonTopic = "/openmower/time/action_result/json";
  static const String timeActionResultBsonTopic = "/openmower/time/action_result/bson";
  static const String timeConfigSetJsonTopic = "/openmower/time/config/set/json";
  static const String timeConfigStatusJsonTopic = "/openmower/time/config/status/json";
  static const String timeConfigStatusBsonTopic = "/openmower/time/config/status/bson";

  static const String mapJsonTopic = "map/json";
  static const String mapBsonTopic = "map/bson";
  static const String mapRenewJsonTopic = "map/set/renew/json";
  static const String mapSetJsonTopic = "map/set/json";
  static const String mapValidationJsonTopic = "map/validation/json";
  static const String mapValidationBsonTopic = "map/validation/bson";
  static const String mapResponseJsonTopic = "map/response/json";
  static const String mapAckJsonTopic = "map/ack/json";
  static const String mapActionResultJsonTopic = "map/action_result/json";

  static const String statusTransitionLogJsonTopic = "statustransition_log/json";
  static const String statusTransitionLogRenewJsonTopic = "statustransition_log/set/renew/json";

  // Settings namespace according to the JSON-first MQTT API.
  static const String mowerLogicSettingsJsonTopic = "settings/mower_logic/json";
  static const String mowerLogicSettingsValidationJsonTopic = "settings/mower_logic/validation/json";
  static const String mowerLogicSettingsRenewJsonTopic = "settings/mower_logic/set/renew/json";
  static const String mowerLogicSettingsSetSessionJsonTopic = "settings/mower_logic/set/session/json";
  static const String mowerLogicSettingsSetPersistentJsonTopic = "settings/mower_logic/set/persistent/json";

  // Mäh-Lastregelung ist kein eigener MQTT-Namespace mehr.
  // Die gefilterte UI nutzt ausschließlich die generischen Mäher-Logik-Settings.
  static const String mowLoadFactorSettingsJsonTopic = mowerLogicSettingsJsonTopic;
  static const String mowLoadFactorSettingsValidationJsonTopic = mowerLogicSettingsValidationJsonTopic;
  static const String mowLoadFactorSettingsRenewJsonTopic = mowerLogicSettingsRenewJsonTopic;
  static const String mowLoadFactorSettingsSetSessionJsonTopic = mowerLogicSettingsSetSessionJsonTopic;
  static const String mowLoadFactorSettingsSetPersistentJsonTopic = mowerLogicSettingsSetPersistentJsonTopic;

  // Canonical legacy-free GPS logging contract.
  static const String gpsStateLoggingStatusJsonTopic = "gps_state/logging/status/json";
  static const String gpsStateLoggingLastJsonTopic = "gps_state/logging/last/json";
  static const String gpsStateLoggingValidationJsonTopic = "gps_state/logging/validation/json";
  static const String gpsStateLoggingControlJsonTopic = "gps_state/logging/set/control/json";
  static const String gpsStateLoggingRenewJsonTopic = "gps_state/logging/set/renew/json";

  static const String lowLevelPowerJsonTopic = "settings/ll_board/json";
  static const String lowLevelPowerValidationJsonTopic = "settings/ll_board/validation/json";
  static const String lowLevelPowerSetSessionJsonTopic = "settings/ll_board/set/session/json";
  static const String lowLevelPowerSetPersistentJsonTopic = "settings/ll_board/set/persistent/json";
  static const String lowLevelPowerRenewJsonTopic = "settings/ll_board/set/renew/json";

  // Openmower-Taf-WUP messenger contract bot_v1 / waha_v1.
  static const String messengerBotJsonTopic = "messenger/bot/json";
  static const String messengerBotValidationJsonTopic = "messenger/bot/validation/json";
  static const String messengerBotSetRenewJsonTopic = "messenger/bot/set/renew/json";
  static const String messengerBotSetSessionJsonTopic = "messenger/bot/set/session/json";
  static const String messengerBotSetPersistentJsonTopic = "messenger/bot/set/persistent/json";
  static const String messengerBotEventsJsonTopic = "messenger/bot/events/json";
  static const String messengerBotPendingConfirmationsJsonTopic = "messenger/bot/confirmations/pending/json";

  static const String messengerWahaJsonTopic = "messenger/waha/json";
  static const String messengerWahaValidationJsonTopic = "messenger/waha/validation/json";
  static const String messengerWahaSetRenewJsonTopic = "messenger/waha/set/renew/json";
  static const String messengerWahaSetSessionJsonTopic = "messenger/waha/set/session/json";
  static const String messengerWahaSetPersistentJsonTopic = "messenger/waha/set/persistent/json";

  static const String mapOverlayJsonTopic = "map/overlay/json";
  static const String mapMowingProgressJsonTopic = "map/mowing_progress/json";
  static const String mapMowingProgressStatusJsonTopic = "map/mowing_progress/status/json";
  static const String mapOverlayBsonTopic = "map/overlay/bson";
  static const String mapOverlayLegacyJsonTopic = "map_overlay/json";
  static const String mapOverlayLegacyBsonTopic = "map_overlay/bson";

  static const String robotStateJsonTopic = "robot_state/json";
  static const String robotStateBsonTopic = "robot_state/bson";
  static const String robotPoseJsonTopic = "robot_pose/json";
  static const String sensorsPoseJsonTopic = "sensors/pose/json";
  static const String sensorsStatusJsonTopic = "sensors/status/json";
  static const String sensorSettingsJsonTopic = "sensors/settings/json";
  static const String sensorSettingsBsonTopic = "sensors/settings/bson";
  static const String sensorSettingsRenewJsonTopic = "sensors/settings/set/renew/json";
  static const String sensorSettingsSetPersistentJsonTopic = "sensors/settings/set/persistent/json";
  static const String sensorSettingsValidationJsonTopic = "sensors/settings/validation/json";

  static const String gpsState1DefinitionTopic = "gps_state/state1/definition";
  static const String gpsState1StatusTopic = "gps_state/state1/status";
  static const String gpsState2DefinitionTopic = "gps_state/state2/definition";
  static const String gpsState2StatusTopic = "gps_state/state2/status";
  static const String gpsState2SatellitesTopic = "gps_state/state2/satellites";
  static const String gpsState2RequestTopic = "gps_state/state2/request";
  static const String gpsState3DefinitionTopic = "gps_state/state3/definition";
  static const String gpsState3StatusTopic = "gps_state/state3/status";
  static const String gpsState3RequestTopic = "gps_state/state3/request";
  static const String gpsState4DefinitionTopic = "gps_state/state4/definition";
  static const String gpsState4StatusTopic = "gps_state/state4/status";
  static const String gpsState4RequestTopic = "gps_state/state4/request";
  static const String gpsStateSettingsJsonTopic = "gps_state/settings/json";
  static const String gpsStateValidationJsonTopic = "gps_state/settings/validation/json";
  static const String gpsStateRenewJsonTopic = "gps_state/set/renew/json";
  static const String gpsStateSettingsRenewJsonTopic = "gps_state/settings/set/renew/json";
  static const String gpsStateSetSessionJsonTopic = "gps_state/settings/set/session/json";
  static const String gpsStateSetPersistentJsonTopic = "gps_state/settings/set/persistent/json";
  static const String gpsStateRestartSetJsonTopic = "gps_state/restart/set/json";
  static const String gpsStateRestartStatusJsonTopic = "gps_state/restart/status/json";
  static const String gpsStateRestartLastJsonTopic = "gps_state/restart/last/json";
  static const String gpsStateRestartValidationJsonTopic = "gps_state/restart/validation/json";
  static const String gpsStateRestartRenewJsonTopic = "gps_state/restart/set/renew/json";

  List<int>? _payloadBytes(MqttPublishMessage payload) {
    return payload.payload.message?.toList(growable: false);
  }

  dynamic _decodeJsonValue(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return jsonDecode(utf8.decode(bytes));
  }

  Map<String, dynamic>? _decodeJsonMap(List<int>? bytes) {
    final decoded = _decodeJsonValue(bytes);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Map<String, dynamic>? _decodeBsonMap(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final decoded = BsonCodec.deserialize(BsonBinary.from(bytes));
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? _decodeMap(MqttPublishMessage payload, {bool bson = false}) {
    return bson ? _decodeBsonMap(_payloadBytes(payload)) : _decodeJsonMap(_payloadBytes(payload));
  }

  void parseTimetableMessage(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        timetableController.setError("Leere oder ungültige Timetable-Nachricht empfangen.");
        return;
      }
      timetableController.setTimetablePayload(map, topic: bson ? timetableBsonTopic : timetableTopic);
    } catch (e) {
      timetableController.setError("Timetable konnte nicht gelesen werden: $e");
    }
  }

  void parseTimetableResponse(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        timetableController.setError("Leere oder ungültige Timetable-Antwort empfangen.");
        return;
      }
      final root = map['d'] is Map ? Map<String, dynamic>.from(map['d'] as Map) : map;
      if (root.containsKey("timetable")) {
        timetableController.setTimetablePayload(root);
        return;
      }
      if (root.containsKey("valid") ||
          root.containsKey("remarks") ||
          root.containsKey("time_state") ||
          root.containsKey("robot_state") ||
          root.containsKey("ok") ||
          root.containsKey("accepted") ||
          root.containsKey("success") ||
          root.containsKey("status") ||
          root.containsKey("result")) {
        timetableController.setActionResult(root);
        return;
      }
      final status = (root["status"] ?? '').toString().toLowerCase();
      final result = (root["result"] ?? '').toString().toLowerCase();
      final accepted = root["accepted"] == true ||
          root["ok"] == true ||
          root["success"] == true ||
          status == "accepted" ||
          status == "ok" ||
          result == "valid";
      final reason = (root["reason"] ?? root["message"] ?? "").toString();
      timetableController.setResponse(accepted, reason);
    } catch (e) {
      timetableController.setError("Timetable-Antwort konnte nicht gelesen werden: $e");
    }
  }

  void parseTimetableValidation(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        timetableController.setError("Leere oder ungültige Timetable-Validierung empfangen.");
        return;
      }
      timetableController.setValidation(map, topic: bson ? timetableValidationBsonTopic : timetableValidationJsonTopic);
    } catch (e) {
      timetableController.setError("Timetable-Validierung konnte nicht gelesen werden: $e");
    }
  }

  void parseRobotStateJson(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map != null) {
        timetableController.setRobotState(map, topic: robotStateJsonTopic);
        final raw = map["d"] is Map ? Map<String, dynamic>.from(map["d"] as Map) : map;
        _updateRobotStateControllerFromRaw(raw);
      }
    } catch (e) {
      timetableController.setError("Robot-State konnte nicht gelesen werden: $e", topic: robotStateJsonTopic);
    }
  }

  void parseRobotPoseJson(MqttPublishMessage payload, {required String topic}) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        return;
      }
      final root = map["d"] is Map ? Map<String, dynamic>.from(map["d"] as Map) : map;
      final pose = root["pose"] is Map ? Map<String, dynamic>.from(root["pose"] as Map) : root;
      _updateRobotPoseFromRaw(pose);
    } catch (e) {
      debugPrint("Roboter-Pose konnte nicht gelesen werden ($topic): $e");
    }
  }

  void parseSensorsStatusJson(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        return;
      }
      final raw = map["d"] is Map ? Map<String, dynamic>.from(map["d"] as Map) : map;
      _updateRobotStateControllerFromRaw(raw);
    } catch (e) {
      debugPrint("Sensor-Status konnte nicht gelesen werden ($sensorsStatusJsonTopic): $e");
    }
  }

  bool _readBoolValue(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase().trim() ?? '';
    if (text.isEmpty || text == 'null') {
      return fallback;
    }
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }

  double _readDoubleValue(dynamic value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? "") ?? fallback;
  }

  int _readIntValue(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? "") ?? fallback;
  }

  dynamic _firstExistingValue(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      if (raw.containsKey(key)) {
        return raw[key];
      }
    }
    return null;
  }

  bool _readAutoMowIndicator(Map<String, dynamic> raw, {bool fallback = false}) {
    final suspensionValue = _firstExistingValue(raw, const [
      "AutoMowSuspension",
      "autoMowSuspension",
      "automowSuspension",
      "auto_mow_suspension",
    ]);

    // AutoMow dot follows suspension state:
    // suspension == 0  -> AutoMow active/valid -> show dot
    // suspension != 0  -> suspended           -> hide dot
    if (suspensionValue == null) {
      return fallback;
    }
    if (suspensionValue is bool) {
      return suspensionValue == false;
    }
    if (suspensionValue is num) {
      return suspensionValue == 0;
    }

    final text = suspensionValue.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'null') {
      return fallback;
    }
    if (text == '0' || text == '0.0' || text == 'false') {
      return true;
    }
    return false;
  }

  void _updateRobotPoseFromRaw(Map<String, dynamic> pose) {
    final state = robotStateController.robotState.value;
    state.isConnected = true;

    if (pose.containsKey("x")) {
      state.posX = _readDoubleValue(pose["x"], fallback: state.posX);
    }
    if (pose.containsKey("y")) {
      state.posY = -_readDoubleValue(pose["y"], fallback: -state.posY);
    }
    if (pose.containsKey("heading")) {
      state.heading = _readDoubleValue(pose["heading"], fallback: state.heading);
    }
    if (pose.containsKey("pos_accuracy")) {
      state.posAccuracy = _readDoubleValue(pose["pos_accuracy"], fallback: state.posAccuracy);
    }
    if (pose.containsKey("heading_accuracy")) {
      state.headingAccuracy = _readDoubleValue(pose["heading_accuracy"], fallback: state.headingAccuracy);
    }
    if (pose.containsKey("heading_valid")) {
      state.headingValid = _readBoolValue(pose["heading_valid"], fallback: state.headingValid);
    }

    robotStateController.robotState.refresh();
  }

  void _updateRobotStateControllerFromRaw(Map<String, dynamic> raw) {
    final state = robotStateController.robotState.value;
    state.isConnected = true;

    if (raw["pose"] is Map) {
      _updateRobotPoseFromRaw(Map<String, dynamic>.from(raw["pose"] as Map));
    } else if (raw.containsKey("x") || raw.containsKey("y") || raw.containsKey("heading")) {
      _updateRobotPoseFromRaw(raw);
    }

    if (raw.containsKey("battery_percentage")) {
      state.batteryPercent = _readDoubleValue(raw["battery_percentage"], fallback: state.batteryPercent);
    }
    if (raw.containsKey("gps_percentage")) {
      state.gpsPercent = _readDoubleValue(raw["gps_percentage"], fallback: state.gpsPercent);
    }
    if (raw.containsKey("emergency")) {
      state.isEmergency = _readBoolValue(raw["emergency"], fallback: state.isEmergency);
    }
    if (raw.containsKey("is_charging")) {
      state.isCharging = _readBoolValue(raw["is_charging"], fallback: state.isCharging);
    }
    if (raw.containsKey("rain_detected")) {
      state.rainDetected = _readBoolValue(raw["rain_detected"], fallback: state.rainDetected);
    }
    if (raw.containsKey("current_area_id")) {
      state.currentAreaId = raw["current_area_id"]?.toString() ?? "";
      robotStateController.rememberActiveMowingArea(state.currentAreaId);
    }
    if (raw.containsKey("checkpoint_area_id")) {
      state.checkpointAreaId = raw["checkpoint_area_id"]?.toString() ?? "";
    }
    if (raw.containsKey("current_area")) {
      state.currentArea = _readIntValue(raw["current_area"], fallback: state.currentArea);
    }
    if (raw.containsKey("current_path")) {
      state.currentPath = _readIntValue(raw["current_path"], fallback: state.currentPath);
    }
    if (raw.containsKey("current_path_index")) {
      state.currentPathIndex = _readIntValue(raw["current_path_index"], fallback: state.currentPathIndex);
    }
    if (raw.containsKey("current_state")) {
      state.currentState = raw["current_state"]?.toString() ?? state.currentState;
    }
    if (raw.containsKey("current_sub_state")) {
      state.currentSubState = raw["current_sub_state"]?.toString() ?? state.currentSubState;
    }
    if (raw.containsKey("load_factor_computed")) {
      state.loadFactorComputed = _readDoubleValue(raw["load_factor_computed"], fallback: state.loadFactorComputed);
    }
    if (raw.containsKey("load_factor_effective")) {
      state.loadFactorEffective = _readDoubleValue(raw["load_factor_effective"], fallback: state.loadFactorEffective);
    }
    state.isAutoMow = _readAutoMowIndicator(raw, fallback: state.isAutoMow);

    robotStateController.robotState.refresh();
  }

  void parseSensorJsonData(String sensorId, MqttPublishMessage payload) {
    try {
      final decoded = _decodeJsonValue(_payloadBytes(payload));
      if (decoded == null) {
        return;
      }

      final value = decoded is Map
          ? (decoded["d"] ?? decoded["value"] ?? decoded[sensorId] ?? decoded)
          : decoded;
      final state = robotStateController.robotState.value;
      state.isConnected = true;

      switch (sensorId) {
        case "battery":
        case "battery_percentage":
          state.batteryPercent = _readDoubleValue(value, fallback: state.batteryPercent);
          break;
        case "gps":
        case "gps_percentage":
          state.gpsPercent = _readDoubleValue(value, fallback: state.gpsPercent);
          break;
        case "emergency":
          state.isEmergency = _readBoolValue(value, fallback: state.isEmergency);
          break;
        case "charging":
        case "is_charging":
          state.isCharging = _readBoolValue(value, fallback: state.isCharging);
          break;
        case "rain":
        case "rain_detected":
          state.rainDetected = _readBoolValue(value, fallback: state.rainDetected);
          break;
        case "pos_accuracy":
          state.posAccuracy = _readDoubleValue(value, fallback: state.posAccuracy);
          break;
        case "heading_accuracy":
          state.headingAccuracy = _readDoubleValue(value, fallback: state.headingAccuracy);
          break;
        case "heading_valid":
          state.headingValid = _readBoolValue(value, fallback: state.headingValid);
          break;
        case "x":
          state.posX = _readDoubleValue(value, fallback: state.posX);
          break;
        case "y":
          state.posY = -_readDoubleValue(value, fallback: -state.posY);
          break;
        case "heading":
          state.heading = _readDoubleValue(value, fallback: state.heading);
          break;
        default:
          debugPrint("got unknown JSON sensor on topic: sensors/$sensorId/json");
          return;
      }

      robotStateController.robotState.refresh();
    } catch (e) {
      debugPrint("JSON-Sensorwert konnte nicht gelesen werden (sensors/$sensorId/json): $e");
    }
  }

  void parseTimeStatus(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        timetableController.setError("Leere oder ungültige Zeitstatus-Nachricht empfangen.");
        return;
      }
      timetableController.setTimeStatus(map);
    } catch (e) {
      timetableController.setError("Zeitstatus konnte nicht gelesen werden: $e");
    }
  }

  void parseTimeActionResult(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        timetableController.setError("Leere oder ungültige Zeitservice-Antwort empfangen.");
        return;
      }
      timetableController.setActionResult(map);
    } catch (e) {
      timetableController.setError("Zeitservice-Antwort konnte nicht gelesen werden: $e");
    }
  }

  void parseTimeConfigStatus(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        timetableController.setError("Leere oder ungültige Zeit-Konfigurationsantwort empfangen.");
        return;
      }
      timetableController.setTimeConfigStatus(map);
    } catch (e) {
      timetableController.setError("Zeit-Konfiguration konnte nicht gelesen werden: $e");
    }
  }

  void parseStatusTransitionLog(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        statusTransitionLogController.setError("Leere oder ungültige Protokoll-Nachricht empfangen.");
        return;
      }
      statusTransitionLogController.setLogPayload(map, topic: statusTransitionLogJsonTopic);
    } catch (e) {
      statusTransitionLogController.setError("Protokolldaten konnten nicht gelesen werden: $e");
    }
  }

  bool _validationMentionsMowLoadFactor(Map<String, dynamic> payload) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    bool keyMatches(dynamic value) {
      if (value is Map) {
        return value.keys.any((key) => keyMatches(key)) || value.values.any(keyMatches);
      }
      if (value is List) {
        return value.any(keyMatches);
      }
      final text = value?.toString() ?? '';
      return text.startsWith('mow_load_') || text.startsWith('load_factor_');
    }
    return keyMatches(root['accepted']) ||
        keyMatches(root['applied']) ||
        keyMatches(root['rejected']) ||
        keyMatches(root['remarks']);
  }

  void parseMowerLogicSettings(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        mowerLogicSettingsController.setError("Leere oder ungültige Settings-Nachricht empfangen.", topic: mowerLogicSettingsJsonTopic);
        return;
      }
      mowerLogicSettingsController.setStatusPayload(map, topic: mowerLogicSettingsJsonTopic);
      mowLoadFactorSettingsController.setStatusPayload(map, topic: mowerLogicSettingsJsonTopic);
    } catch (e) {
      mowerLogicSettingsController.setError("Settings-Status konnte nicht gelesen werden: $e", topic: mowerLogicSettingsJsonTopic);
    }
  }

  void parseMowerLogicSettingsValidation(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        mowerLogicSettingsController.setError("Leere oder ungültige Mäher-Logik-Validierung empfangen.", topic: mowerLogicSettingsValidationJsonTopic);
        return;
      }
      mowerLogicSettingsController.setValidation(map, topic: mowerLogicSettingsValidationJsonTopic);
      if (_validationMentionsMowLoadFactor(map) || mowLoadFactorSettingsController.actionInProgress.value) {
        mowLoadFactorSettingsController.setValidation(map, topic: mowerLogicSettingsValidationJsonTopic);
      }
    } catch (e) {
      mowerLogicSettingsController.setError("Mäher-Logik-Validierung konnte nicht gelesen werden: $e", topic: mowerLogicSettingsValidationJsonTopic);
    }
  }

  void parseGpsStateLoggingStatus(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        satelliteLoggingController.setError("Leere oder ungültige GPS-Logging-Statusnachricht empfangen.", topic: gpsStateLoggingStatusJsonTopic);
        return;
      }
      satelliteLoggingController.setStatusPayload(map, topic: gpsStateLoggingStatusJsonTopic);
    } catch (e) {
      satelliteLoggingController.setError("GPS-Logging-Status konnte nicht gelesen werden: $e", topic: gpsStateLoggingStatusJsonTopic);
    }
  }

  void parseGpsStateLoggingLast(MqttPublishMessage payload) {
    final map = _decodeMap(payload);
    if (map != null) satelliteLoggingController.setLastPayload(map, topic: gpsStateLoggingLastJsonTopic);
  }

  void parseGpsStateLoggingValidation(MqttPublishMessage payload) {
    final map = _decodeMap(payload);
    if (map != null) satelliteLoggingController.setValidationPayload(map, topic: gpsStateLoggingValidationJsonTopic);
  }

  void parseLowLevelPowerSettings(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        lowLevelPowerSettingsController.setError("Leere oder ungültige Low-Level-Board-Nachricht empfangen.", topic: lowLevelPowerJsonTopic);
        return;
      }
      lowLevelPowerSettingsController.setStatusPayload(map, topic: lowLevelPowerJsonTopic);
    } catch (e) {
      lowLevelPowerSettingsController.setError("Low-Level-Board-Status konnte nicht gelesen werden: $e", topic: lowLevelPowerJsonTopic);
    }
  }

  void parseLowLevelPowerSettingsValidation(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        lowLevelPowerSettingsController.setError("Leere oder ungültige Low-Level-Board-Validierung empfangen.", topic: lowLevelPowerValidationJsonTopic);
        return;
      }
      lowLevelPowerSettingsController.setValidation(map, topic: lowLevelPowerValidationJsonTopic);
    } catch (e) {
      lowLevelPowerSettingsController.setError("Low-Level-Board-Validierung konnte nicht gelesen werden: $e", topic: lowLevelPowerValidationJsonTopic);
    }
  }

  String _requestId(String prefix) => "$prefix-${DateTime.now().millisecondsSinceEpoch}-$clientId";

  void parseGpsState(int stateNumber, MqttPublishMessage payload, {required String topic}) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError("Leere oder ungültige GPS-State-Nachricht empfangen.", topic: topic);
        return;
      }
      gpsStateController.setStatePayload(stateNumber, map, topic: topic);
    } catch (e) {
      gpsStateController.setError("GPS-State konnte nicht gelesen werden: $e", topic: topic);
    }
  }

  void parseGpsStateSatellites(MqttPublishMessage payload, {required String topic}) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError("Leere oder ungültige State2-Satellitenliste empfangen.", topic: topic);
        return;
      }
      gpsStateController.setState2Satellites(map, topic: topic);
    } catch (e) {
      gpsStateController.setError("State2-Satellitenliste konnte nicht gelesen werden: $e", topic: topic);
    }
  }

  void parseGpsStateSettings(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError("Leere oder ungültige GPS-State-Settings empfangen.", topic: gpsStateSettingsJsonTopic);
        return;
      }
      gpsStateController.setSettingsPayload(map, topic: gpsStateSettingsJsonTopic);
    } catch (e) {
      gpsStateController.setError("GPS-State-Settings konnten nicht gelesen werden: $e", topic: gpsStateSettingsJsonTopic);
    }
  }

  void parseGpsStateValidation(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError("Leere oder ungültige GPS-State-Validierung empfangen.", topic: gpsStateValidationJsonTopic);
        return;
      }
      gpsStateController.setValidation(map, topic: gpsStateValidationJsonTopic);
    } catch (e) {
      gpsStateController.setError("GPS-State-Validierung konnte nicht gelesen werden: $e", topic: gpsStateValidationJsonTopic);
    }
  }

  void parseGpsRestartStatus(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError("Leere oder ungültige F9P-Neustartstatus-Nachricht empfangen.", topic: gpsStateRestartStatusJsonTopic);
        return;
      }
      gpsStateController.setRestartStatus(map, topic: gpsStateRestartStatusJsonTopic);
    } catch (e) {
      gpsStateController.setError("F9P-Neustartstatus konnte nicht gelesen werden: $e", topic: gpsStateRestartStatusJsonTopic);
    }
  }

  void parseGpsRestartLast(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError(
          "Leere oder ungültige Nachricht zum letzten F9P-Neustart empfangen.",
          topic: gpsStateRestartLastJsonTopic,
        );
        return;
      }
      gpsStateController.setRestartLast(map, topic: gpsStateRestartLastJsonTopic);
    } catch (e) {
      gpsStateController.setError(
        "Letzter F9P-Neustartstatus konnte nicht gelesen werden: $e",
        topic: gpsStateRestartLastJsonTopic,
      );
    }
  }

  void parseGpsRestartValidation(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        gpsStateController.setError("Leere oder ungültige F9P-Neustartvalidierung empfangen.", topic: gpsStateRestartValidationJsonTopic);
        return;
      }
      gpsStateController.setRestartValidation(map, topic: gpsStateRestartValidationJsonTopic);
    } catch (e) {
      gpsStateController.setError("F9P-Neustartvalidierung konnte nicht gelesen werden: $e", topic: gpsStateRestartValidationJsonTopic);
    }
  }

  void _publishJson(String topic, Map<String, dynamic> map, {MqttQos qos = MqttQos.atLeastOnce}) {
    final builder = MqttPayloadBuilder();
    builder.addString(jsonEncode(map));
    client.publishMessage(topic, qos, builder.payload!);
  }

  void requestTimetable() {
    try {
      _publishJson(timetableRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting timetable via mqtt");
      timetableController.setError("Timetable-Anfrage konnte nicht gesendet werden.");
    }
  }

  void publishTimetable(Map<String, dynamic> timetable) {
    try {
      _publishJson(timetableSetTopic, timetable, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing timetable to mqtt");
      timetableController.setError("Timetable konnte nicht gesendet werden.");
    }
  }

  void publishSuspension(dynamic autoMowSuspension) {
    try {
      _publishJson(timetableSuspensionSetJsonTopic, {"AutoMowSuspension": autoMowSuspension}, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing suspension to mqtt");
      timetableController.setError("Aussetzung konnte nicht gesendet werden.");
    }
  }

  void requestTimeStatus() {
    try {
      _publishJson(timeActionJsonTopic, {"request_id": _requestId("time_req"), "action": "get_status"});
    } catch(e) {
      debugPrint("error requesting time status via mqtt");
      timetableController.setError("Zeitstatus-Anfrage konnte nicht gesendet werden.");
    }
  }

  void requestTimeResync({String preferredSource = "ntp"}) {
    try {
      _publishJson(timeActionJsonTopic, {"request_id": _requestId("time_req"), "action": "resync", "preferred_source": preferredSource});
    } catch(e) {
      debugPrint("error requesting time resync via mqtt");
      timetableController.setError("Resync-Anfrage konnte nicht gesendet werden.");
    }
  }

  void setTimeTimezone(String timezone) {
    try {
      _publishJson(timeActionJsonTopic, {"request_id": _requestId("time_req"), "action": "set_timezone", "timezone": timezone});
    } catch(e) {
      debugPrint("error setting timezone via mqtt");
      timetableController.setError("Zeitzone konnte nicht gesendet werden.");
    }
  }

  void setManualTime({required String timezone, required String localTime}) {
    try {
      _publishJson(timeActionJsonTopic, {"request_id": _requestId("time_req"), "action": "set_manual_time", "timezone": timezone, "local_time": localTime});
    } catch(e) {
      debugPrint("error setting manual time via mqtt");
      timetableController.setError("Manuelle Zeit konnte nicht gesendet werden.");
    }
  }

  void setNtpServer(String server) {
    try {
      _publishJson(timeActionJsonTopic, {"request_id": _requestId("time_req"), "action": "set_ntp_server", "ntp_server": server});
    } catch(e) {
      debugPrint("error setting ntp server via mqtt");
      timetableController.setError("NTP Server konnte nicht gesendet werden.");
    }
  }

  void clearManualTime() {
    try {
      _publishJson(timeActionJsonTopic, {"request_id": _requestId("time_req"), "action": "clear_manual_time"});
    } catch(e) {
      debugPrint("error clearing manual time via mqtt");
      timetableController.setError("Manuelle Zeit konnte nicht verworfen werden.");
    }
  }

  void publishTimeConfig(Map<String, dynamic> timeConfig) {
    try {
      _publishJson(timeConfigSetJsonTopic, {"time": timeConfig}, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing time config to mqtt");
      timetableController.setError("Zeit-Konfiguration konnte nicht gesendet werden.");
    }
  }

  void requestMap() {
    try {
      _publishJson(mapRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting map via mqtt");
      mqttAreasController.setError("Flächen-Anfrage konnte nicht gesendet werden.");
    }
  }

  void requestStatusTransitionLog({int limit = 20}) {
    try {
      final normalizedLimit = limit.clamp(1, 300).toInt();
      _publishJson(statusTransitionLogRenewJsonTopic, {"limit": normalizedLimit});
    } catch(e) {
      debugPrint("error requesting status transition log via mqtt");
      statusTransitionLogController.setError("Protokoll-Anfrage konnte nicht gesendet werden.");
    }
  }

  void requestMowerLogicSettings() {
    try {
      _publishJson(mowerLogicSettingsRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting mower logic settings via mqtt");
      mowerLogicSettingsController.setError("Mäher-Logik-Anfrage konnte nicht gesendet werden.", topic: mowerLogicSettingsRenewJsonTopic);
    }
  }

  void publishMowerLogicSessionSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(mowerLogicSettingsSetSessionJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing mower logic session settings via mqtt");
      mowerLogicSettingsController.setError("Mäher-Logik-Sessionwerte konnten nicht gesendet werden.", topic: mowerLogicSettingsSetSessionJsonTopic);
    }
  }

  void publishMowerLogicPersistentSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(mowerLogicSettingsSetPersistentJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing mower logic persistent settings via mqtt");
      mowerLogicSettingsController.setError("Dauerhafte Mäher-Logik-Settings konnten nicht gesendet werden.", topic: mowerLogicSettingsSetPersistentJsonTopic);
    }
  }

  void requestMowLoadFactorSettings() {
    requestMowerLogicSettings();
  }

  void publishMowLoadFactorSessionSettings(Map<String, dynamic> settings) {
    publishMowerLogicSessionSettings(settings);
  }

  void publishMowLoadFactorPersistentSettings(Map<String, dynamic> settings) {
    publishMowerLogicPersistentSettings(settings);
  }

  void requestGpsStateLoggingStatus() {
    try {
      _publishJson(gpsStateLoggingRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      satelliteLoggingController.setError("GPS-Logging-Anfrage konnte nicht gesendet werden.", topic: gpsStateLoggingRenewJsonTopic);
    }
  }

  void publishGpsStateLoggingControl(Map<String, dynamic> control) {
    try {
      _publishJson(gpsStateLoggingControlJsonTopic, control, qos: MqttQos.exactlyOnce);
    } catch(e) {
      satelliteLoggingController.setError("GPS-Logging-Befehl konnte nicht gesendet werden.", topic: gpsStateLoggingControlJsonTopic);
    }
  }

  void requestLowLevelPowerSettings() {
    try {
      _publishJson(lowLevelPowerRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting low level power settings via mqtt");
      lowLevelPowerSettingsController.setError("Low-Level-Board-Anfrage konnte nicht gesendet werden.", topic: lowLevelPowerRenewJsonTopic);
    }
  }

  void publishLowLevelPowerSessionSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(lowLevelPowerSetSessionJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing low level session settings via mqtt");
      lowLevelPowerSettingsController.setError("Low-Level-Board-Sessionwerte konnten nicht gesendet werden.", topic: lowLevelPowerSetSessionJsonTopic);
    }
  }

  void publishLowLevelPowerPersistentSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(lowLevelPowerSetPersistentJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing low level persistent settings via mqtt");
      lowLevelPowerSettingsController.setError("Low-Level-Board-Werte konnten nicht dauerhaft gespeichert werden.", topic: lowLevelPowerSetPersistentJsonTopic);
    }
  }

  void requestMessengerBot() {
    try {
      _publishJson(messengerBotSetRenewJsonTopic, <String, dynamic>{}, qos: MqttQos.atMostOnce);
    } catch (e) {
      messengerSettingsController.lastStatus.value = "Bot-Status konnte nicht neu angefordert werden.";
    }
  }

  void requestMessengerWaha() {
    try {
      _publishJson(messengerWahaSetRenewJsonTopic, <String, dynamic>{}, qos: MqttQos.atMostOnce);
    } catch (e) {
      messengerSettingsController.lastStatus.value = "WAHA-Status konnte nicht neu angefordert werden.";
    }
  }

  void publishMessengerBotSession(Map<String, dynamic> payload) {
    try {
      _publishJson(messengerBotSetSessionJsonTopic, payload, qos: MqttQos.atMostOnce);
    } catch (e) {
      messengerSettingsController.lastStatus.value = "Bot-Sessionänderungen konnten nicht gesendet werden.";
    }
  }

  void publishMessengerBotPersistent(Map<String, dynamic> payload) {
    try {
      _publishJson(messengerBotSetPersistentJsonTopic, payload, qos: MqttQos.atMostOnce);
    } catch (e) {
      messengerSettingsController.lastStatus.value = "Bot-Einstellungen konnten nicht dauerhaft gespeichert werden.";
    }
  }

  void publishMessengerWahaSession(Map<String, dynamic> payload) {
    try {
      _publishJson(messengerWahaSetSessionJsonTopic, payload, qos: MqttQos.atMostOnce);
    } catch (e) {
      messengerSettingsController.lastStatus.value = "WAHA-Sessionänderungen konnten nicht gesendet werden.";
    }
  }

  void publishMessengerWahaPersistent(Map<String, dynamic> payload) {
    try {
      _publishJson(messengerWahaSetPersistentJsonTopic, payload, qos: MqttQos.atMostOnce);
    } catch (e) {
      messengerSettingsController.lastStatus.value = "WAHA-Einstellungen konnten nicht dauerhaft gespeichert werden.";
    }
  }

  void parseMessengerMessage(String topic, MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) return;
      switch (topic) {
        case messengerBotJsonTopic:
          messengerSettingsController.setSnapshot(
            MessengerSurface.bot,
            map,
            topic: messengerBotJsonTopic,
          );
          break;
        case messengerBotValidationJsonTopic:
          messengerSettingsController.setValidation(
            MessengerSurface.bot,
            map,
            topic: messengerBotValidationJsonTopic,
          );
          break;
        case messengerWahaJsonTopic:
          messengerSettingsController.setSnapshot(
            MessengerSurface.waha,
            map,
            topic: messengerWahaJsonTopic,
          );
          break;
        case messengerWahaValidationJsonTopic:
          messengerSettingsController.setValidation(
            MessengerSurface.waha,
            map,
            topic: messengerWahaValidationJsonTopic,
          );
          break;
        case messengerBotEventsJsonTopic:
        case messengerBotPendingConfirmationsJsonTopic:
          messengerSettingsController.setBotRuntime(topic, map);
          break;
      }
    } catch (e) {
      messengerSettingsController.lastStatus.value = "Messenger-Payload konnte nicht gelesen werden: $e";
    }
  }

  void requestSensorSettings() {
    try {
      _publishJson(sensorSettingsRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting sensor settings via mqtt");
      sensorsController.setError("Sensor-Metadaten-Anfrage konnte nicht gesendet werden.", topic: sensorSettingsRenewJsonTopic);
    }
  }

  void publishSensorPersistentSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(sensorSettingsSetPersistentJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing sensor metadata via mqtt");
      sensorsController.setError("Sensor-Metadaten konnten nicht dauerhaft gespeichert werden.", topic: sensorSettingsSetPersistentJsonTopic);
    }
  }

  void requestGpsState() {
    try {
      _publishJson(gpsStateRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting gps state via mqtt");
      gpsStateController.setError("GPS-State-Anfrage konnte nicht gesendet werden.", topic: gpsStateRenewJsonTopic);
      return;
    }
    requestGpsStateSettings(reportError: false);
  }

  void requestGpsStateSettings({bool reportError = true}) {
    try {
      _publishJson(gpsStateSettingsRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting gps state settings via mqtt");
      if (reportError) {
        gpsStateController.setError(
          "GPS-State-Settings konnten nicht angefordert werden.",
          topic: gpsStateSettingsRenewJsonTopic,
        );
      }
    }
  }

  void publishGpsStateRequest(int state, Map<String, dynamic> payload) {
    final topic = switch (state) {
      1 => 'gps_state/state1/request',
      2 => gpsState2RequestTopic,
      3 => gpsState3RequestTopic,
      4 => gpsState4RequestTopic,
      _ => throw ArgumentError.value(state, 'state', 'Nur state1 bis state4 sind kanonisch'),
    };
    try {
      _publishJson(topic, payload, qos: MqttQos.atLeastOnce);
    } catch (e) {
      debugPrint('error publishing GPS state request via mqtt');
      gpsStateController.setError('GPS-State-Anforderung konnte nicht gesendet werden.', topic: topic);
    }
  }

  void requestGpsRestartStatus() {
    try {
      _publishJson(gpsStateRestartRenewJsonTopic, <String, dynamic>{});
    } catch(e) {
      debugPrint("error requesting gps restart status via mqtt");
      gpsStateController.setError("F9P-Neustartstatus-Anfrage konnte nicht gesendet werden.", topic: gpsStateRestartRenewJsonTopic);
    }
  }

  void publishGpsRestartCommand(Map<String, dynamic> command) {
    try {
      _publishJson(gpsStateRestartSetJsonTopic, command, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing gps restart command via mqtt");
      gpsStateController.setError("F9P-Neustartbefehl konnte nicht gesendet werden.", topic: gpsStateRestartSetJsonTopic);
    }
  }

  void publishGpsStateSessionSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(gpsStateSetSessionJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing gps state session settings via mqtt");
      gpsStateController.setError("GPS-State-Sessionwerte konnten nicht gesendet werden.", topic: gpsStateSetSessionJsonTopic);
    }
  }

  void publishGpsStatePersistentSettings(Map<String, dynamic> settings) {
    try {
      _publishJson(gpsStateSetPersistentJsonTopic, settings, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing gps state persistent settings via mqtt");
      gpsStateController.setError("GPS-State-Werte konnten nicht dauerhaft gespeichert werden.", topic: gpsStateSetPersistentJsonTopic);
    }
  }

  void publishMap(Map<String, dynamic> map) {
    try {
      _publishJson(mapSetJsonTopic, map, qos: MqttQos.exactlyOnce);
    } catch(e) {
      debugPrint("error publishing map to mqtt");
      mqttAreasController.setError("Flächen konnten nicht gesendet werden.");
    }
  }


  void disconnect() {
    client.autoReconnect = false;
    client.onDisconnected = null;
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    client.disconnect();
  }

  void start() {
    // client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.autoReconnect = false;
    client.resubscribeOnAutoReconnect = false;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
  }

  void sendJoystick(double x, double r, bool highQos) {
    final map = {"vx": x,
    "vz": r};
    final binary = BsonCodec.serialize(map);
    final buffer = Uint8Buffer();
    buffer.addAll(binary.byteList);
    try {
      client.publishMessage("teleop", highQos ? MqttQos.atLeastOnce : MqttQos.atMostOnce, buffer);
    } catch(e) {
      debugPrint("error publishing to mqtt");
    }

  }

  Path convertJsonPolygon(path) {
    Path pathPoly = Path();
    bool first = true;
    for (final pt in path) {
      if (first) {
        pathPoly.moveTo(pt["x"], -pt["y"]);
        first = false;
      } else {
        pathPoly.lineTo(pt["x"], -pt["y"]);
      }
    }
    pathPoly.close();
    return pathPoly;
  }

  Offset getPolygonCenter(path) {
    return getOverlayPosition(path);
  }

  Offset getOverlayPosition(path) {
    if (path == null || path.isEmpty) {
      return Offset.zero;
    }

    final polygon = convertJsonPolygon(path);
    final bounds = polygon.getBounds();
    if (bounds.isEmpty) {
      return Offset.zero;
    }

    final outlinePoints = _jsonPolygonToOffsets(path);
    if (outlinePoints.isEmpty) {
      return Offset.zero;
    }

    final boundsCenter = bounds.center;

    // Same circle size as the map overlay painter. This is used only for
    // placement, so the label is preferably positioned where the whole circle
    // fits inside the area.
    const double overlayRadius = 0.58;

    Offset? bestFullyInsidePoint;
    double bestFullyInsideScore = double.infinity;

    Offset? bestInsidePoint;
    double bestInsideScore = double.negativeInfinity;

    // A finer grid keeps the behavior stable for long/narrow and irregular
    // mowing areas without relying on vertex averages near edges.
    const int steps = 48;
    for (int ix = 0; ix <= steps; ix++) {
      final x = bounds.left + bounds.width * ix / steps;
      for (int iy = 0; iy <= steps; iy++) {
        final y = bounds.top + bounds.height * iy / steps;
        final candidate = Offset(x, y);
        if (!polygon.contains(candidate)) {
          continue;
        }

        final clearance = _distanceToOutline(candidate, outlinePoints);
        final dx = candidate.dx - boundsCenter.dx;
        final dy = candidate.dy - boundsCenter.dy;
        final centerDistanceSquared = dx * dx + dy * dy;

        // Fallback candidate: stay inside and prefer the widest available
        // part of the area. This helps when the area is too narrow for the
        // complete circle.
        final insideScore = clearance * 1000000.0 - centerDistanceSquared;
        if (insideScore > bestInsideScore) {
          bestInsideScore = insideScore;
          bestInsidePoint = candidate;
        }

        // Preferred candidate: the circle around the label also stays inside.
        if (clearance >= overlayRadius &&
            _circleSamplesInside(polygon, candidate, overlayRadius)) {
          if (centerDistanceSquared < bestFullyInsideScore) {
            bestFullyInsideScore = centerDistanceSquared;
            bestFullyInsidePoint = candidate;
          }
        }
      }
    }

    if (bestFullyInsidePoint != null) {
      return bestFullyInsidePoint;
    }

    if (bestInsidePoint != null) {
      return bestInsidePoint;
    }

    // Fallback to the old vertex-average behavior if no sampled point was
    // found. This should only happen for very small or malformed polygons.
    double sumX = 0;
    double sumY = 0;
    int count = 0;

    for (final pt in path) {
      sumX += (pt["x"] as num).toDouble();
      sumY += -((pt["y"] as num).toDouble());
      count++;
    }

    if (count == 0) {
      return Offset.zero;
    }
    return Offset(sumX / count, sumY / count);
  }

  List<Offset> _jsonPolygonToOffsets(path) {
    final points = <Offset>[];
    if (path == null) {
      return points;
    }

    for (final pt in path) {
      if (pt is Map && pt["x"] is num && pt["y"] is num) {
        points.add(Offset(
          (pt["x"] as num).toDouble(),
          -((pt["y"] as num).toDouble()),
        ));
      }
    }
    return points;
  }

  bool _circleSamplesInside(Path polygon, Offset center, double radius) {
    if (!polygon.contains(center)) {
      return false;
    }

    const int samples = 24;
    for (int i = 0; i < samples; i++) {
      final angle = 2.0 * pi * i / samples;
      final sample = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      if (!polygon.contains(sample)) {
        return false;
      }
    }
    return true;
  }

  double _distanceToOutline(Offset point, List<Offset> outlinePoints) {
    if (outlinePoints.length < 2) {
      return 0.0;
    }

    double best = double.infinity;
    for (int i = 0; i < outlinePoints.length; i++) {
      final a = outlinePoints[i];
      final b = outlinePoints[(i + 1) % outlinePoints.length];
      best = min(best, _distanceToSegment(point, a, b));
    }
    return best;
  }

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      final px = point.dx - a.dx;
      final py = point.dy - a.dy;
      return sqrt(px * px + py * py);
    }

    final t = (((point.dx - a.dx) * dx + (point.dy - a.dy) * dy) /
            lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();

    final projection = Offset(a.dx + t * dx, a.dy + t * dy);
    final px = point.dx - projection.dx;
    final py = point.dy - projection.dy;
    return sqrt(px * px + py * py);
  }

  int? parseIntProperty(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  bool parseMowingEnabled(dynamic value) {
    if (value == null) {
      return true;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final lower = value.toString().toLowerCase();
    return lower != "false" && lower != "0" && lower != "disabled";
  }

  bool parseAreaActive(dynamic value) {
    if (value == null) {
      return true;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final lower = value.toString().trim().toLowerCase();
    return lower != "false" && lower != "0" && lower != "disabled" && lower != "inactive";
  }

  Map<String, dynamic> _mapRootForParser(Map<String, dynamic> obj) {
    return obj["d"] is Map ? obj : <String, dynamic>{"d": obj};
  }

  void parseMapMessage(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        mqttAreasController.setError("Leere oder ungültige Map-Nachricht empfangen.", topic: bson ? mapBsonTopic : mapJsonTopic);
        return;
      }
      mqttAreasController.setAreaPayload(map, topic: bson ? mapBsonTopic : mapJsonTopic);
      final root = _mapRootForParser(map);
      if (root["d"] is Map && (root["d"] as Map).containsKey("areas")) {
        parseMap(root);
      } else {
        parseLegacyMap(root);
      }
    } catch (e) {
      mqttAreasController.setError("Map konnte nicht gelesen werden: $e", topic: bson ? mapBsonTopic : mapJsonTopic);
    }
  }

  void parseMapValidation(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        mqttAreasController.setError("Leere oder ungültige Map-Validierung empfangen.", topic: bson ? mapValidationBsonTopic : mapValidationJsonTopic);
        return;
      }
      mqttAreasController.setValidation(map, topic: bson ? mapValidationBsonTopic : mapValidationJsonTopic);
    } catch (e) {
      mqttAreasController.setError("Map-Validierung konnte nicht gelesen werden: $e", topic: bson ? mapValidationBsonTopic : mapValidationJsonTopic);
    }
  }

  void parseMapResponse(MqttPublishMessage payload, {String topic = mapResponseJsonTopic}) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        mqttAreasController.setError("Leere oder ungültige Map-Antwort empfangen.", topic: topic);
        return;
      }
      final root = map['d'] is Map ? Map<String, dynamic>.from(map['d'] as Map) : map;
      if (root.containsKey("areas") || root.containsKey("working_areas")) {
        mqttAreasController.setAreaPayload(root, topic: topic);
        final parserRoot = _mapRootForParser(root);
        if (parserRoot["d"] is Map && (parserRoot["d"] as Map).containsKey("areas")) {
          parseMap(parserRoot);
        } else {
          parseLegacyMap(parserRoot);
        }
        return;
      }
      if (root.containsKey("valid") ||
          root.containsKey("remarks") ||
          root.containsKey("ok") ||
          root.containsKey("accepted") ||
          root.containsKey("success") ||
          root.containsKey("status") ||
          root.containsKey("result")) {
        mqttAreasController.setActionResult(root, topic: topic);
        return;
      }
      final status = (root["status"] ?? '').toString().toLowerCase();
      final result = (root["result"] ?? '').toString().toLowerCase();
      final accepted = root["accepted"] == true ||
          root["ok"] == true ||
          root["success"] == true ||
          status == "accepted" ||
          status == "ok" ||
          result == "valid";
      final reason = (root["reason"] ?? root["message"] ?? "").toString();
      mqttAreasController.setResponse(accepted, reason, topic: topic);
    } catch (e) {
      mqttAreasController.setError("Map-Antwort konnte nicht gelesen werden: $e", topic: topic);
    }
  }

  void parseMap(obj) {
    final mapModel = MapModel();
    final areas = obj["d"]["areas"] ?? [];

    // calculate bounds of active map data used by the normal map view
    var hasBounds = false;
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final area in areas) {
      final properties = area["properties"] ?? {};
      if (!parseAreaActive(properties["active"] ?? area["active"])) {
        continue;
      }
      for (final pt in area["outline"] ?? []) {
        minX = min(minX, pt["x"]);
        maxX = max(maxX, pt["x"]);
        minY = min(minY, pt["y"]);
        maxY = max(maxY, pt["y"]);
        hasBounds = true;
      }
    }
    if (hasBounds) {
      mapModel.width = maxX - minX;
      mapModel.height = maxY - minY;
      mapModel.centerX = (minX + maxX) / 2;
      mapModel.centerY = -(minY + maxY) / 2;
    } else {
      mapModel.width = 0;
      mapModel.height = 0;
      mapModel.centerX = 0;
      mapModel.centerY = 0;
    }

    if (obj["d"]["docking_stations"].isNotEmpty) {
      mapModel.dockX = obj["d"]["docking_stations"][0]["position"]["x"];
      mapModel.dockY = -obj["d"]["docking_stations"][0]["position"]["y"];
      mapModel.dockHeading = obj["d"]["docking_stations"][0]["heading"];
    } else {
      mapModel.dockX = 0;
      mapModel.dockY = 0;
      mapModel.dockHeading = 0;
    }

    for (final area in areas) {
      final properties = area["properties"] ?? {};
      final type = properties["type"];
      if (!parseAreaActive(properties["active"] ?? area["active"])) {
        continue;
      }
      if (type == "mow") {
        mapModel.mowingAreas.add(MapArea(
          outline: convertJsonPolygon(area["outline"]),
          labelPosition: getOverlayPosition(area["outline"]),
          id: area["id"]?.toString() ?? "",
          mowingEnabled: parseMowingEnabled(properties["mowing_enabled"]),
          mowingOrder: parseIntProperty(properties["mowing_order"]),
        ));
      } else if (type == "nav") {
        mapModel.navigationAreas.add(convertJsonPolygon(area["outline"]));
      } else if (type == "obstacle") {
        mapModel.obstacles.add(convertJsonPolygon(area["outline"]));
      }
    }

    debugPrint(
        "Got a map with ${mapModel.mowingAreas.length} mowing areas, ${mapModel.navigationAreas.length} navigation areas and ${mapModel.obstacles.length} active obstacles. Size: ${mapModel.width} x ${mapModel.height}. Docking pos: ${mapModel.dockX}, ${mapModel.dockY}");

    final RobotStateController robotStateController = Get.find();
    robotStateController.map.value = mapModel;
    robotStateController.map.refresh();
  }

  void parseLegacyMap(obj) {
    final mapModel = MapModel();

    mapModel.width =   obj["d"]["meta"]["mapWidth"] ?? 0;
    mapModel.height =  obj["d"]["meta"]["mapHeight"] ?? 0;
    mapModel.centerX = obj["d"]["meta"]["mapCenterX"] ?? 0;
    mapModel.centerY = -obj["d"]["meta"]["mapCenterY"] ?? 0;
    mapModel.dockX =       obj["d"]["docking_pose"]["x"] ?? 0;
    mapModel.dockY =       -obj["d"]["docking_pose"]["y"] ?? 0;
    mapModel.dockHeading = obj["d"]["docking_pose"]["heading"] ?? 0;

    final wa = obj["d"]["working_areas"];
    if(wa != null) {
      for(final area in wa) {
        mapModel.mowingAreas.add(MapArea(
          outline: convertJsonPolygon(area["outline"]),
          labelPosition: getOverlayPosition(area["outline"]),
        ));
        for (final obstacle in area["obstacles"] ?? []) {
          mapModel.obstacles.add(convertJsonPolygon(obstacle));
        }
      }
    }
    final na = obj["d"]["navigation_areas"];
    if(na != null) {
      for(final area in na) {
        mapModel.navigationAreas.add(convertJsonPolygon(area["outline"]));
        for (final obstacle in area["obstacles"] ?? []) {
          mapModel.obstacles.add(convertJsonPolygon(obstacle));
        }
      }
    }

    debugPrint(
        "Got a legacy map with ${mapModel.mowingAreas.length} mowing areas and ${mapModel.navigationAreas.length} navigation areas. Size: ${mapModel.width} x ${mapModel.height}. Docking pos: ${mapModel.dockX}, ${mapModel.dockY}");

    final RobotStateController robotStateController = Get.find();
    robotStateController.map.value = mapModel;
    robotStateController.map.refresh();
  }

  void parseMapOverlayMessage(MqttPublishMessage payload, {bool bson = false, required String topic}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        debugPrint("Leere oder ungültige Map-Overlay-Nachricht auf $topic empfangen.");
        return;
      }
      final root = map["d"] is Map ? map : <String, dynamic>{"d": map};
      parseMapOverlay(root);
    } catch (e) {
      debugPrint("Map-Overlay konnte nicht gelesen werden ($topic): $e");
    }
  }

  void parseMapOverlay(obj) {
    final overlayModel = MapOverlayModel();
    final polys = obj["d"]["polygons"];
    if(polys != null) {
      for(final poly in polys) {
        bool first = true;
        Path path = Path();
        for (final pt in poly["poly"]) {
          if (first) {
            path.moveTo(pt["x"], -pt["y"]);
            first = false;
          } else {
            path.lineTo(pt["x"], -pt["y"]);
          }
        }
        if(path.isBlank != true && poly["is_closed"] > 0) {
          path.close();
        }
        overlayModel.polygons.add(OverlayPolygon(path, poly["is_closed"] > 0, poly["line_width"], poly["color"]));
      }
    }


    robotStateController.mapOverlay.value = overlayModel;
    robotStateController.mapOverlay.refresh();
  }


  void parseMowingProgressMessage(MqttPublishMessage payload, {required String topic, bool statusOnly = false}) {
    try {
      final decoded = _decodeJsonValue(_payloadBytes(payload));
      if (decoded is! Map) {
        debugPrint("Leere oder ungültige Mähfortschritt-Nachricht auf $topic empfangen.");
        return;
      }
      final root = decoded["d"] is Map ? decoded : <String, dynamic>{"d": decoded};
      parseMowingProgress(root, statusOnly: statusOnly);
    } catch (e) {
      debugPrint("Mähfortschritt konnte nicht gelesen werden ($topic): $e");
    }
  }

  void parseMowingProgress(obj, {bool statusOnly = false}) {
    final currentModel = robotStateController.mowingProgress.value;
    final root = obj is Map && obj["d"] is Map
        ? Map<String, dynamic>.from(obj["d"] as Map)
        : <String, dynamic>{};
    final rawCurrentAreaId = root["current_area_id"];
    var currentAreaId = rawCurrentAreaId == null
        ? currentModel.currentAreaId.trim()
        : rawCurrentAreaId.toString().trim();
    final progressAreas = Map<String, AreaMowingProgress>.from(currentModel.areas);

    final areas = root["areas"];
    if (areas is Map) {
      areas.forEach((key, value) {
        if (value is Map) {
          final areaMap = Map<String, dynamic>.from(value);
          final areaId = (areaMap["area_id"] ?? key).toString();
          final previous = currentModel.areaById(areaId);
          final mergedPaths = <String, MowingPathProgress>{
            for (final path in previous?.paths ?? <MowingPathProgress>[])
              if (path.pathId.trim().isNotEmpty) path.pathId.trim(): path,
          };

          final rawPaths = areaMap["paths"];
          if (rawPaths is Iterable) {
            final seenPathIds = statusOnly
                ? _mergeMowingStatusPaths(mergedPaths, rawPaths)
                : _mergeMowingGeometryPaths(mergedPaths, rawPaths);
            mergedPaths.removeWhere((pathId, _) => !seenPathIds.contains(pathId));
          }

          progressAreas[areaId] = AreaMowingProgress(
            areaId: areaId,
            percent: _readDoubleValue(areaMap["percent"], fallback: previous?.percent ?? 0.0),
            state: areaMap["state"]?.toString() ?? previous?.state ?? "",
            currentPathId: areaMap["current_path_id"]?.toString() ?? previous?.currentPathId ?? "",
            paths: _sortedMowingPaths(mergedPaths.values),
          );
        }
      });
    }

    final progressModel = MowingProgressModel(
      currentAreaId: currentAreaId,
      areas: progressAreas,
    );

    robotStateController.rememberActiveMowingArea(currentAreaId);
    robotStateController.mowingProgress.value = progressModel;
    robotStateController.mowingProgress.refresh();
  }

  Set<String> _mergeMowingGeometryPaths(Map<String, MowingPathProgress> target, Iterable rawPaths) {
    final seenPathIds = <String>{};
    var fallbackIndex = target.length;
    for (final rawPath in rawPaths) {
      if (rawPath is! Map) {
        continue;
      }
      final pathMap = Map<String, dynamic>.from(rawPath);
      final pathId = pathMap["path_id"]?.toString().trim() ?? "";
      if (pathId.isEmpty) {
        continue;
      }
      seenPathIds.add(pathId);
      final previous = target[pathId];
      final order = _readIntValue(pathMap["order"], fallback: previous?.order ?? fallbackIndex);
      final points = <Offset>[];
      final rawPoints = pathMap["points"];
      if (rawPoints is Iterable) {
        for (final rawPoint in rawPoints) {
          if (rawPoint is Map) {
            final pointMap = Map<String, dynamic>.from(rawPoint);
            points.add(Offset(
              _readDoubleValue(pointMap["x"], fallback: 0.0),
              -_readDoubleValue(pointMap["y"], fallback: 0.0),
            ));
          }
        }
      }

      int? slicerSourcePathId;
      final slicerSource = pathMap["slicer_source"];
      if (slicerSource is Map) {
        slicerSourcePathId = _readIntValue(
          Map<String, dynamic>.from(slicerSource)["path_id"],
          fallback: previous?.slicerSourcePathId ?? -1,
        );
        if (slicerSourcePathId < 0) {
          slicerSourcePathId = previous?.slicerSourcePathId;
        }
      }

      target[pathId] = (previous ?? MowingPathProgress(
        index: order,
        order: order,
        pathId: pathId,
        points: const <Offset>[],
      )).copyWith(
        index: order,
        order: order,
        slicerSourcePathId: slicerSourcePathId,
        pathDirection: pathMap["path_direction"]?.toString() ?? previous?.pathDirection ?? "",
        points: points,
        hasGeometry: true,
      );
      fallbackIndex++;
    }
    return seenPathIds;
  }

  Set<String> _mergeMowingStatusPaths(Map<String, MowingPathProgress> target, Iterable rawPaths) {
    final seenPathIds = <String>{};
    var fallbackIndex = target.length;
    for (final rawPath in rawPaths) {
      if (rawPath is! Map) {
        continue;
      }
      final pathMap = Map<String, dynamic>.from(rawPath);
      final pathId = pathMap["path_id"]?.toString().trim() ?? "";
      if (pathId.isEmpty) {
        continue;
      }
      seenPathIds.add(pathId);
      final previous = target[pathId];
      target[pathId] = (previous ?? MowingPathProgress(
        index: fallbackIndex,
        pathId: pathId,
        points: const <Offset>[],
      )).copyWith(
        mowStatus: pathMap["mow_status"]?.toString() ?? previous?.mowStatus ?? "",
        currentPoseIndex: _readIntValue(pathMap["current_pose_index"], fallback: previous?.currentPoseIndex ?? 0),
        completedPercent: _readDoubleValue(pathMap["completed_percent"], fallback: previous?.completedPercent ?? 0.0),
        hasStatus: true,
      );
      fallbackIndex++;
    }
    return seenPathIds;
  }

  List<MowingPathProgress> _sortedMowingPaths(Iterable<MowingPathProgress> paths) {
    final result = paths.toList();
    result.sort((a, b) {
      final orderCompare = (a.order ?? a.index).compareTo(b.order ?? b.index);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.pathId.compareTo(b.pathId);
    });
    return result;
  }

  void parseRobotState(obj) {
    final raw = obj is Map && obj["d"] is Map ? Map<String, dynamic>.from(obj["d"] as Map) : <String, dynamic>{};
    if (raw.isNotEmpty) {
      timetableController.setRobotState(raw, topic: "robot_state/bson");
      _updateRobotStateControllerFromRaw(raw);
    }
    if (obj["d"] == null || obj["d"]["pose"] == null) {
      return;
    }
    RobotState state        = RobotState();
    state.isConnected       = true;
    state.posX              = obj["d"]["pose"]["x"];
    state.posY              = -obj["d"]["pose"]["y"];
    state.heading           = obj["d"]["pose"]["heading"];
    state.posAccuracy       = obj["d"]["pose"]["pos_accuracy"];
    state.headingAccuracy   = obj["d"]["pose"]["heading_accuracy"];
    state.headingValid      = obj["d"]["pose"]["heading_valid"] > 0;
    state.isEmergency       = obj["d"]["emergency"] > 0;
    state.isCharging        = obj["d"]["is_charging"] > 0;
    state.rainDetected      = obj["d"]["rain_detected"] > 0;
    state.currentState      = obj["d"]["current_state"];
    state.isAutoMow         = _readAutoMowIndicator(Map<String, dynamic>.from(obj["d"] as Map));
    state.gpsPercent        = obj["d"]["gps_percentage"];
    state.batteryPercent    = obj["d"]["battery_percentage"];
    final loadFactorComputed = obj["d"]["load_factor_computed"];
    if (loadFactorComputed is num) {
      state.loadFactorComputed = loadFactorComputed.toDouble();
    }
    final loadFactorEffective = obj["d"]["load_factor_effective"];
    if (loadFactorEffective is num) {
      state.loadFactorEffective = loadFactorEffective.toDouble();
    }
    state.currentArea       = obj["d"]["current_area"];
    state.currentAreaId     = obj["d"]["current_area_id"]?.toString() ?? "";
    state.checkpointAreaId  = obj["d"]["checkpoint_area_id"]?.toString() ?? state.checkpointAreaId;
    robotStateController.rememberActiveMowingArea(state.currentAreaId);
    state.currentPath       = obj["d"]["current_path"];
    state.currentPathIndex  = obj["d"]["current_path_index"];
    robotStateController.robotState.value = state;
  }



  void parseSensorSettings(MqttPublishMessage payload, {bool bson = false}) {
    try {
      final map = _decodeMap(payload, bson: bson);
      if (map == null) {
        sensorsController.setError("Leere oder ungültige Sensor-Metadaten empfangen.", topic: bson ? sensorSettingsBsonTopic : sensorSettingsJsonTopic);
        return;
      }
      sensorsController.setSettingsPayload(map, topic: bson ? sensorSettingsBsonTopic : sensorSettingsJsonTopic);
    } catch (e) {
      sensorsController.setError("Sensor-Metadaten konnten nicht gelesen werden: $e", topic: bson ? sensorSettingsBsonTopic : sensorSettingsJsonTopic);
    }
  }

  void parseSensorSettingsValidation(MqttPublishMessage payload) {
    try {
      final map = _decodeMap(payload);
      if (map == null) {
        sensorsController.setError("Leere oder ungültige Sensor-Validierung empfangen.", topic: sensorSettingsValidationJsonTopic);
        return;
      }
      sensorsController.setValidation(map, topic: sensorSettingsValidationJsonTopic);
    } catch (e) {
      sensorsController.setError("Sensor-Validierung konnte nicht gelesen werden: $e", topic: sensorSettingsValidationJsonTopic);
    }
  }

  void parseSensorInfos(obj) {
    debugPrint("Got new sensor infos, refreshing");
    final infos = obj["d"];
    if (infos is! Iterable) {
      return;
    }
    for (final sensorInfo in infos) {
      if (sensorInfo is Map) {
        sensorsController.upsertSensorFromInfo(Map<String, dynamic>.from(sensorInfo));
      }
    }
  }

  void parseSensorData(sensorId, obj) {
    final value = obj is Map ? (obj["d"] ?? obj["value"] ?? obj["data"] ?? obj[sensorId.toString()] ?? obj) : obj;
    sensorsController.updateSensorValue(sensorId.toString(), value);
  }

  void parseSensorLiveData(String sensorId, MqttPublishMessage payload) {
    final bytes = _payloadBytes(payload);
    if (bytes == null || bytes.isEmpty) {
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      try {
        decoded = BsonCodec.deserialize(BsonBinary.from(bytes));
      } catch (_) {
        decoded = utf8.decode(bytes, allowMalformed: true).trim();
      }
    }

    final value = decoded is Map
        ? (decoded["d"] ?? decoded["value"] ?? decoded["data"] ?? decoded[sensorId] ?? decoded)
        : decoded;
    sensorsController.updateSensorValue(sensorId, value);
  }

  void parseVersion(obj) {
    final String versionString = obj["version"];
    robotStateController.softwareVersion.value = versionString;
  }

  void parseActionInfos(obj) {
      final Set<String> newActionSet = {};
      for(final action in obj["d"]) {
        if(action["enabled"] > 0) {
          newActionSet.add(action["action_id"]);
        }
      }

      debugPrint("available actions: $newActionSet");
      robotStateController.availableActions.assignAll(newActionSet);
  }

  void onConnected() {
    debugPrint("MQTT connected");
    robotStateController.setConnected(true);

    _reconnectDelaySeconds = 1;
    _lastConnectAttempt = null;
    _updatesSubscription?.cancel();
    _updatesSubscription = client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {

      for (var msg in c) {
          if (kDebugMode && msg.topic != null && !msg.topic!.startsWith('sensors/') && msg.topic != robotPoseJsonTopic) {
            debugPrint("got message on ${msg.topic}");
          }
          final payload = msg.payload as MqttPublishMessage;
          switch(msg.topic) {
            case timetableTopic: {
              parseTimetableMessage(payload);
            }
            break;
            case timetableBsonTopic: {
              parseTimetableMessage(payload, bson: true);
            }
            break;
            case timetableStatusTopic: {
              parseTimetableMessage(payload);
            }
            break;
            case timetableResponseTopic:
            case timetableAckTopic:
            case timetableActionResultTopic: {
              parseTimetableResponse(payload);
            }
            break;
            case timetableValidationJsonTopic: {
              parseTimetableValidation(payload);
            }
            break;
            case timetableValidationBsonTopic: {
              parseTimetableValidation(payload, bson: true);
            }
            break;
            case timeStatusJsonTopic: {
              parseTimeStatus(payload);
            }
            break;
            case timeStatusBsonTopic: {
              parseTimeStatus(payload, bson: true);
            }
            break;
            case timeActionResultJsonTopic: {
              parseTimeActionResult(payload);
            }
            break;
            case timeActionResultBsonTopic: {
              parseTimeActionResult(payload, bson: true);
            }
            break;
            case timeConfigStatusJsonTopic: {
              parseTimeConfigStatus(payload);
            }
            break;
            case timeConfigStatusBsonTopic: {
              parseTimeConfigStatus(payload, bson: true);
            }
            break;
            case "version": {
              final bytes = payload.payload.message?.toList(growable: false);
              if(bytes == null || bytes.isBlank == true) {
                continue;
              }
              final object = BsonCodec.deserialize(BsonBinary.from(bytes));
              parseVersion(object);
            }
            break;
            case "actions/bson": {
              final bytes = payload.payload.message?.toList(growable: false);
              if(bytes == null || bytes.isBlank == true) {
                continue;
              }
              final object = BsonCodec.deserialize(BsonBinary.from(bytes));
              parseActionInfos(object);
            }
            break;
            case mapJsonTopic: {
              parseMapMessage(payload);
            }
            break;
            case mapBsonTopic: {
              parseMapMessage(payload, bson: true);
            }
            break;
            case mapValidationJsonTopic: {
              parseMapValidation(payload);
            }
            break;
            case mapValidationBsonTopic: {
              parseMapValidation(payload, bson: true);
            }
            break;
            case statusTransitionLogJsonTopic: {
              parseStatusTransitionLog(payload);
            }
            break;
            case mowerLogicSettingsJsonTopic: {
              parseMowerLogicSettings(payload);
            }
            break;
            case mowerLogicSettingsValidationJsonTopic: {
              parseMowerLogicSettingsValidation(payload);
            }
            break;
            case gpsStateLoggingStatusJsonTopic: { parseGpsStateLoggingStatus(payload); } break;
            case gpsStateLoggingLastJsonTopic: { parseGpsStateLoggingLast(payload); } break;
            case gpsStateLoggingValidationJsonTopic: { parseGpsStateLoggingValidation(payload); } break;
            case gpsState1DefinitionTopic: {
              parseGpsState(1, payload, topic: gpsState1DefinitionTopic);
            }
            break;
            case gpsState1StatusTopic: {
              parseGpsState(1, payload, topic: gpsState1StatusTopic);
            }
            break;
            case gpsState2DefinitionTopic: {
              parseGpsState(2, payload, topic: gpsState2DefinitionTopic);
            }
            break;
            case gpsState2StatusTopic: {
              parseGpsState(2, payload, topic: gpsState2StatusTopic);
            }
            break;
            case gpsState2SatellitesTopic: {
              parseGpsStateSatellites(payload, topic: gpsState2SatellitesTopic);
            }
            break;
            case gpsState3DefinitionTopic: {
              parseGpsState(3, payload, topic: gpsState3DefinitionTopic);
            }
            break;
            case gpsState3StatusTopic: {
              parseGpsState(3, payload, topic: gpsState3StatusTopic);
            }
            break;
            case gpsState4DefinitionTopic: {
              parseGpsState(4, payload, topic: gpsState4DefinitionTopic);
            }
            break;
            case gpsState4StatusTopic: {
              parseGpsState(4, payload, topic: gpsState4StatusTopic);
            }
            break;
            case gpsStateSettingsJsonTopic: {
              parseGpsStateSettings(payload);
            }
            break;
            case gpsStateValidationJsonTopic: {
              parseGpsStateValidation(payload);
            }
            break;
            case gpsStateRestartStatusJsonTopic: {
              parseGpsRestartStatus(payload);
            }
            break;
            case gpsStateRestartLastJsonTopic: {
              parseGpsRestartLast(payload);
            }
            break;
            case gpsStateRestartValidationJsonTopic: {
              parseGpsRestartValidation(payload);
            }
            break;
            case messengerBotJsonTopic:
            case messengerBotValidationJsonTopic:
            case messengerBotEventsJsonTopic:
            case messengerBotPendingConfirmationsJsonTopic:
            case messengerWahaJsonTopic:
            case messengerWahaValidationJsonTopic: {
              parseMessengerMessage(msg.topic!, payload);
            }
            break;
            case lowLevelPowerJsonTopic: {
              parseLowLevelPowerSettings(payload);
            }
            break;
            case lowLevelPowerValidationJsonTopic: {
              parseLowLevelPowerSettingsValidation(payload);
            }
            break;
            case mapOverlayJsonTopic:
            case mapOverlayLegacyJsonTopic: {
              parseMapOverlayMessage(payload, topic: msg.topic!);
            }
            break;
            case mapMowingProgressJsonTopic: {
              parseMowingProgressMessage(payload, topic: msg.topic!, statusOnly: false);
            }
            break;
            case mapMowingProgressStatusJsonTopic: {
              parseMowingProgressMessage(payload, topic: msg.topic!, statusOnly: true);
            }
            break;
            case mapOverlayBsonTopic:
            case mapOverlayLegacyBsonTopic: {
              parseMapOverlayMessage(payload, bson: true, topic: msg.topic!);
            }
            break;
            case robotStateJsonTopic: {
              parseRobotStateJson(payload);
            }
            break;
            case robotPoseJsonTopic:
            case sensorsPoseJsonTopic: {
              parseRobotPoseJson(payload, topic: msg.topic!);
            }
            break;
            case sensorsStatusJsonTopic: {
              parseSensorsStatusJson(payload);
            }
            break;
            case sensorSettingsJsonTopic: {
              parseSensorSettings(payload);
            }
            break;
            case sensorSettingsBsonTopic: {
              parseSensorSettings(payload, bson: true);
            }
            break;
            case sensorSettingsValidationJsonTopic: {
              parseSensorSettingsValidation(payload);
            }
            break;
            case robotStateBsonTopic: {
              // Got the robot state
              final bytes = payload.payload.message?.toList(growable: false);
              if(bytes == null || bytes.isBlank == true) {
                continue;
              }
              final object = BsonCodec.deserialize(BsonBinary.from(bytes));
              parseRobotState(object);
            }
            break;
            default: {
              if(msg.topic != null) {
                // It's probably some sensor data, get ID
                final dataMatch = expData.firstMatch(msg.topic!);
                if (dataMatch != null) {
                  parseSensorLiveData(dataMatch[1]!, payload);
                } else {
                  final match = exp.firstMatch(msg.topic!);
                  if (match != null) {
                    // Got sensor data bson
                    final bytes = payload.payload.message?.toList(growable: false);
                    if(bytes == null || bytes.isBlank == true) {
                      continue;
                    }
                    final object = BsonCodec.deserialize(BsonBinary.from(bytes));
                    parseSensorData(match[1], object);
                  } else {
                    final jsonMatch = expJson.firstMatch(msg.topic!);
                    if (jsonMatch != null) {
                      parseSensorJsonData(jsonMatch[1]!, payload);
                    } else {
                      debugPrint("got unknown message on topic: ${msg.topic}");
                    }
                  }
                }
              }
            }
            break;
          }
      }
    });

    client.subscribe("actions/bson", MqttQos.exactlyOnce);
    client.subscribe(mapJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mapBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mapValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mapValidationBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(statusTransitionLogJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mowerLogicSettingsJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mowerLogicSettingsValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateLoggingStatusJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateLoggingLastJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateLoggingValidationJsonTopic, MqttQos.atLeastOnce);
    // Mäh-Lastregelung wird ausschließlich über settings/mower_logic/... verarbeitet.
    client.subscribe(messengerBotJsonTopic, MqttQos.atMostOnce);
    client.subscribe(messengerBotValidationJsonTopic, MqttQos.atMostOnce);
    client.subscribe(messengerBotEventsJsonTopic, MqttQos.atMostOnce);
    client.subscribe(messengerBotPendingConfirmationsJsonTopic, MqttQos.atMostOnce);
    client.subscribe(messengerWahaJsonTopic, MqttQos.atMostOnce);
    client.subscribe(messengerWahaValidationJsonTopic, MqttQos.atMostOnce);
    client.subscribe(lowLevelPowerJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(lowLevelPowerValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState1DefinitionTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState1StatusTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState2DefinitionTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState2StatusTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState2SatellitesTopic, MqttQos.atMostOnce);
    client.subscribe(gpsState3DefinitionTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState3StatusTopic, MqttQos.atMostOnce);
    client.subscribe(gpsState4DefinitionTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsState4StatusTopic, MqttQos.atMostOnce);
    client.subscribe(gpsStateSettingsJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateRestartStatusJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateRestartLastJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(gpsStateRestartValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mapOverlayJsonTopic, MqttQos.atMostOnce);
    client.subscribe(mapMowingProgressJsonTopic, MqttQos.atMostOnce);
    client.subscribe(mapMowingProgressStatusJsonTopic, MqttQos.atMostOnce);
    client.subscribe(mapOverlayBsonTopic, MqttQos.atMostOnce);
    client.subscribe(mapOverlayLegacyJsonTopic, MqttQos.atMostOnce);
    client.subscribe(mapOverlayLegacyBsonTopic, MqttQos.atMostOnce);
    client.subscribe(robotStateJsonTopic, MqttQos.atMostOnce);
    client.subscribe(robotStateBsonTopic, MqttQos.atMostOnce);
    client.subscribe(robotPoseJsonTopic, MqttQos.atMostOnce);
    client.subscribe(sensorsPoseJsonTopic, MqttQos.atMostOnce);
    client.subscribe(sensorsStatusJsonTopic, MqttQos.atMostOnce);
    client.subscribe(sensorSettingsJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(sensorSettingsBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(sensorSettingsValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe("sensors/+/data", MqttQos.atMostOnce);
    client.subscribe("sensors/+/bson", MqttQos.atMostOnce);
    client.subscribe("sensors/+/json", MqttQos.atMostOnce);
    client.subscribe("version", MqttQos.atLeastOnce);
    client.subscribe(timetableTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableValidationBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableStatusTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableResponseTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableAckTopic, MqttQos.atLeastOnce);
    client.subscribe(timetableActionResultTopic, MqttQos.atLeastOnce);
    client.subscribe(timeStatusJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timeStatusBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timeActionResultJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timeActionResultBsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timeConfigStatusJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(timeConfigStatusBsonTopic, MqttQos.atLeastOnce);
  }

  void onDisconnected() {
    debugPrint("MQTT disconnected");
    robotStateController.setConnected(false);
  }

  void connect() async {
    if(_connecting) {
      debugPrint("MQTT already connecting, ignoring connect() call");
      return;
    }
    _connecting = true;

    client.disconnect();


    if(kIsWeb && kReleaseMode) {
      // Connect according to settings
      if(mqttclient.isWebSocket()) {
        client.server = "ws://${Uri.base.host}/";
      } else{
        client.server = Uri.base.host;
      }
      client.port = 9001;
    } else {
      // Connect according to settings
      if(mqttclient.isWebSocket()) {
        client.server = "ws://${settingsController.hostname.value}/";
      } else{
        client.server = settingsController.hostname.value;
      }
      client.port = settingsController.mqttPort.value;
    }



    final connMess = MqttConnectMessage()
    // .withProtocolName("mqtt")
    // .withProtocolName("websocket")
    // .startClean()
        .withClientIdentifier("om-client-$clientId");
      // .authenticateAs(settingsController.mqttUsername, settingsController.mqttPassword);

    debugPrint('Mosquitto client connecting to ${client.server} on ${client.port}....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on Exception catch (e) {
      debugPrint('EXAMPLE::client exception - $e');
      client.disconnect();
      _connecting = false;

      return;
    }
    debugPrint("MQTT connect success!");
    _connecting = false;
  }

  void tryConnect() {
    final state = client.connectionStatus?.state;
    if(state == MqttConnectionState.connected || state == MqttConnectionState.connecting || _connecting) {
      return;
    }
    final now = DateTime.now();
    final lastAttempt = _lastConnectAttempt;
    if (lastAttempt != null && now.difference(lastAttempt).inSeconds < _reconnectDelaySeconds) {
      return;
    }
    _lastConnectAttempt = now;
    _reconnectDelaySeconds = min(_reconnectDelaySeconds * 2, 30);
    debugPrint("trying reconnect MQTT");
    connect();
  }

  void callAction(String action) {
    final builder = MqttPayloadBuilder();
    builder.addString(action);
    try {
      client.publishMessage("action", MqttQos.exactlyOnce, builder.payload!);
    } catch(e) {
      debugPrint("error publishing to mqtt");
    }
  }

}