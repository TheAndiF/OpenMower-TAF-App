
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:open_mower_app/controllers/sensors_controller.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/models/map_model.dart';
import 'package:open_mower_app/models/robot_state.dart';
import 'package:open_mower_app/models/sensor_state.dart';
import 'package:open_mower_app/models/map_overlay_model.dart';

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

  final SettingsController settingsController = Get.find();
  final RobotStateController robotStateController = Get.find();
  final SensorsController sensorsController = Get.find();
  final TimetableController timetableController = Get.find();
  final MqttAreasController mqttAreasController = Get.find();

  final RegExp exp = RegExp(r'sensors/(.*)/bson');

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

  List<int>? _payloadBytes(MqttPublishMessage payload) {
    return payload.payload.message?.toList(growable: false);
  }

  Map<String, dynamic>? _decodeJsonMap(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(utf8.decode(bytes));
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
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
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
        timetableController.setRobotState(map, topic: "robot_state/json");
        final raw = map["d"] is Map ? Map<String, dynamic>.from(map["d"] as Map) : map;
        _updateRobotStateControllerFromRaw(raw);
      }
    } catch (e) {
      timetableController.setError("Robot-State konnte nicht gelesen werden: $e", topic: "robot_state/json");
    }
  }

  void _updateRobotStateControllerFromRaw(Map<String, dynamic> raw) {
    final state = robotStateController.robotState.value;
    state.isConnected = true;
    if (raw.containsKey("current_area_id")) {
      state.currentAreaId = raw["current_area_id"]?.toString() ?? "";
    }
    if (raw.containsKey("current_area")) {
      final value = raw["current_area"];
      if (value is int) {
        state.currentArea = value;
      } else if (value is num) {
        state.currentArea = value.toInt();
      } else {
        state.currentArea = int.tryParse(value?.toString() ?? "") ?? state.currentArea;
      }
    }
    if (raw.containsKey("current_state")) {
      state.currentState = raw["current_state"]?.toString() ?? state.currentState;
    }
    if (raw.containsKey("current_sub_state")) {
      state.currentSubState = raw["current_sub_state"]?.toString() ?? state.currentSubState;
    }
    robotStateController.robotState.refresh();
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

  String _requestId(String prefix) => "$prefix-${DateTime.now().millisecondsSinceEpoch}-$clientId";

  void _publishJson(String topic, Map<String, dynamic> map, {MqttQos qos = MqttQos.atLeastOnce}) {
    final builder = MqttPayloadBuilder();
    builder.addString(jsonEncode(map));
    client.publishMessage(topic, qos, builder.payload!);
  }

  void requestTimetable() {
    try {
      _publishJson(timetableRenewJsonTopic, {"request": "renew", "source": "app", "request_id": _requestId("timetable_renew")});
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
      _publishJson(mapRenewJsonTopic, {"request": "renew", "source": "app", "request_id": _requestId("map_renew")});
    } catch(e) {
      debugPrint("error requesting map via mqtt");
      mqttAreasController.setError("Flächen-Anfrage konnte nicht gesendet werden.");
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
    if (path == null || path.isEmpty) {
      return Offset.zero;
    }

    double sumX = 0;
    double sumY = 0;

    for (final pt in path) {
      sumX += (pt["x"] as num).toDouble();
      sumY += -((pt["y"] as num).toDouble());
    }

    return Offset(sumX / path.length, sumY / path.length);
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

    // calculate bounds of areas
    if (obj["d"]["areas"].isNotEmpty) {
      double minX = double.infinity;
      double maxX = double.negativeInfinity;
      double minY = double.infinity;
      double maxY = double.negativeInfinity;
      for (final area in obj["d"]["areas"]) {
        for (final pt in area["outline"]) {
          minX = min(minX, pt["x"]);
          maxX = max(maxX, pt["x"]);
          minY = min(minY, pt["y"]);
          maxY = max(maxY, pt["y"]);
        }
      }
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

    for (final area in obj["d"]["areas"]) {
      final properties = area["properties"] ?? {};
      final type = properties["type"];
      if (type == "mow") {
        mapModel.mowingAreas.add(MapArea(
          outline: convertJsonPolygon(area["outline"]),
          labelPosition: getPolygonCenter(area["outline"]),
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
        "Got a map with ${mapModel.mowingAreas.length} mowing areas and ${mapModel.navigationAreas.length} navigation areas. Size: ${mapModel.width} x ${mapModel.height}. Docking pos: ${mapModel.dockX}, ${mapModel.dockY}");

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
          labelPosition: getPolygonCenter(area["outline"]),
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
    state.gpsPercent        = obj["d"]["gps_percentage"];
    state.batteryPercent    = obj["d"]["battery_percentage"];
    state.currentArea       = obj["d"]["current_area"];
    state.currentAreaId     = obj["d"]["current_area_id"]?.toString() ?? "";
    state.currentPath       = obj["d"]["current_path"];
    state.currentPathIndex  = obj["d"]["current_path_index"];
    robotStateController.robotState.value = state;
  }



  void parseSensorInfos(obj) {
    debugPrint("Got new sensor infos, refreshing");
    for (final sensorInfo in obj["d"]) {
      switch (sensorInfo["value_type"]) {
        case "DOUBLE":
          {
            // Got a double sensor
            final sensor = DoubleSensorState(
                sensorInfo["sensor_name"],
                sensorInfo["unit"],
                sensorInfo["min_value"],
                sensorInfo["max_value"],
                sensorInfo["has_min_max"] == 1,
                sensorInfo["lower_critical_value"],
                sensorInfo["has_critical_low"] == 1,
                sensorInfo["upper_critical_value"],
                sensorInfo["has_critical_high"] == 1);
            sensorsController.sensorStates[sensorInfo["sensor_id"]] = sensor;
          }
      }
    }
    sensorsController.sensorStates.refresh();
  }

  void parseSensorData(sensorId, obj) {
    final sensor = sensorsController.sensorStates[sensorId];
    if(sensor != null) {
      sensor.value = obj["d"];
    }
    sensorsController.sensorStates.refresh();
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
      // FIXME: invalid_use_of_protected_member
      robotStateController.availableActions.value = newActionSet;
  }

  void onConnected() {
    debugPrint("MQTT connected");
    robotStateController.setConnected(true);

    client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {

      for (var msg in c) {
          debugPrint("got message on ${msg.topic}");
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
            case mapValidationJsonTopic: {
              parseMapValidation(payload);
            }
            break;
            case "map_overlay/bson": {
              final bytes = payload.payload.message?.toList(growable: false);
              if(bytes == null || bytes.isBlank == true) {
                continue;
              }
              final object = BsonCodec.deserialize(BsonBinary.from(bytes));
              parseMapOverlay(object);
            }
            break;
            case "robot_state/json": {
              parseRobotStateJson(payload);
            }
            break;
            case "robot_state/bson": {
              // Got the robot state
              final bytes = payload.payload.message?.toList(growable: false);
              if(bytes == null || bytes.isBlank == true) {
                continue;
              }
              final object = BsonCodec.deserialize(BsonBinary.from(bytes));
              parseRobotState(object);
            }
            break;
            case "sensor_infos/bson": {
              // Got the robot state
              final bytes = payload.payload.message?.toList(growable: false);
              if(bytes == null || bytes.isBlank == true) {
                continue;
              }
              final object = BsonCodec.deserialize(BsonBinary.from(bytes));
              parseSensorInfos(object);
            }
            break;
            default: {
              if(msg.topic != null) {
                // It's probably some sensor data, get ID
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
                  debugPrint("got unknown message on topic: ${msg.topic}");
                }
              }
            }
            break;
          }
      }
    });

    client.subscribe("actions/bson", MqttQos.exactlyOnce);
    client.subscribe(mapJsonTopic, MqttQos.atLeastOnce);
    client.subscribe(mapValidationJsonTopic, MqttQos.atLeastOnce);
    client.subscribe("map_overlay/bson", MqttQos.atMostOnce);
    client.subscribe("sensor_infos/bson", MqttQos.atLeastOnce);
    client.subscribe("robot_state/json", MqttQos.atMostOnce);
    client.subscribe("robot_state/bson", MqttQos.atMostOnce);
    client.subscribe("sensors/+/bson", MqttQos.atMostOnce);
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
        client.server = "ws://${settingsController.hostname}/";
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
    if(client.connectionStatus?.state == MqttConnectionState.connected || client.connectionStatus?.state == MqttConnectionState.connecting) {
      return;
    }
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