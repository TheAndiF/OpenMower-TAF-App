import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class TimetableController extends GetxController {
  final timetableData = <String, dynamic>{}.obs;
  final timeState = <String, dynamic>{}.obs;
  final robotState = <String, dynamic>{}.obs;
  final timeConfigStatus = <String, dynamic>{}.obs;
  final lastRemarks = <String>[].obs;
  final lastStatus = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final rawJsonController = TextEditingController();
  final timezoneController = TextEditingController(text: 'Europe/Berlin');
  final manualLocalTimeController = TextEditingController();

  bool get hasData => timetableData.isNotEmpty;
  bool get hasTimeState => timeState.isNotEmpty;
  bool get hasRobotState => robotState.isNotEmpty;
  bool get hasTimeConfigStatus => timeConfigStatus.isNotEmpty;

  void setTimetablePayload(Map<String, dynamic> payload) {
    final nextTimetable = _mapOrEmpty(payload['timetable']);
    if (nextTimetable.isNotEmpty &&
        (payload.containsKey('valid') || payload.containsKey('remarks') || payload.containsKey('time_state') || payload.containsKey('robot_state'))) {
      setTimetable(nextTimetable, statusMessage: 'Timetable-Rückkanal empfangen');
      _updateOptionalStatusBlocks(payload);
      lastStatusOk.value = _validOrNull(payload['valid']) ?? true;
      lastRemarks.assignAll(_stringList(payload['remarks']));
      return;
    }

    setTimetable(payload, statusMessage: 'Timetable empfangen');
  }

  void setTimetable(Map<String, dynamic> data, {String statusMessage = 'Timetable empfangen'}) {
    timetableData
      ..clear()
      ..addAll(_deepCopy(data));
    rawJsonController.text = const JsonEncoder.withIndent('  ').convert(timetableData);
    _syncTimezoneControllerFromTimetable();
    lastUpdated.value = DateTime.now();
    lastStatus.value = statusMessage;
    lastStatusOk.value = true;
    waitingForResponse.value = false;
  }

  void setTimeStatus(Map<String, dynamic> payload) {
    final state = _mapOrEmpty(payload['time_state']);
    if (state.isNotEmpty) {
      timeState
        ..clear()
        ..addAll(_deepCopy(state));
      _syncTimezoneControllerFromTimeState();
    }
    lastRemarks.assignAll(_stringList(payload['remarks']));
    lastUpdated.value = DateTime.now();
    lastStatusOk.value = _validOrNull(payload['valid']) ?? _validOrNull(state['valid']);
    lastStatus.value = 'Zeitstatus empfangen';
    waitingForResponse.value = false;
  }

  void setTimeConfigStatus(Map<String, dynamic> payload) {
    final config = _mapOrEmpty(payload['time']).isNotEmpty ? _mapOrEmpty(payload['time']) : payload;
    timeConfigStatus
      ..clear()
      ..addAll(_deepCopy(config));
    lastUpdated.value = DateTime.now();
    lastStatusOk.value = true;
    lastStatus.value = 'Zeit-Konfiguration bestätigt';
    waitingForResponse.value = false;
  }

  void setActionResult(Map<String, dynamic> payload) {
    _updateOptionalStatusBlocks(payload);
    final action = (payload['action'] ?? 'Action').toString();
    final ok = _validOrNull(payload['valid']) ?? false;
    final remarks = _stringList(payload['remarks']);
    lastRemarks.assignAll(remarks);
    waitingForResponse.value = false;
    lastStatusOk.value = ok;
    lastStatus.value = ok
        ? '$action bestätigt${remarks.isEmpty ? '' : ': ${remarks.join(', ')}'}'
        : '$action abgelehnt${remarks.isEmpty ? '' : ': ${remarks.join(', ')}'}';
  }

  void setResponse(bool accepted, String reason) {
    waitingForResponse.value = false;
    lastStatusOk.value = accepted;
    lastStatus.value = accepted
        ? (reason.isEmpty ? 'Service hat die Änderung bestätigt.' : 'Bestätigt: $reason')
        : (reason.isEmpty ? 'Service hat die Änderung abgelehnt.' : 'Abgelehnt: $reason');
  }

  void setError(String message) {
    waitingForResponse.value = false;
    lastStatusOk.value = false;
    lastStatus.value = message;
  }

  void requestTimetable() {
    final mqttConnection = Get.find<MqttConnection>();
    mqttConnection.requestTimetable();
    lastStatus.value = 'Timetable wird angefordert ...';
    lastStatusOk.value = null;
  }

  void requestTimeStatus() {
    final mqttConnection = Get.find<MqttConnection>();
    mqttConnection.requestTimeStatus();
    waitingForResponse.value = true;
    lastStatus.value = 'Zeitstatus wird angefordert ...';
    lastStatusOk.value = null;
  }

  void requestTimeResync({String preferredSource = 'ntp'}) {
    final mqttConnection = Get.find<MqttConnection>();
    mqttConnection.requestTimeResync(preferredSource: preferredSource);
    waitingForResponse.value = true;
    lastStatus.value = 'Zeitsynchronisation wird angefordert ...';
    lastStatusOk.value = null;
  }

  void sendTimezone() {
    final timezone = timezoneController.text.trim();
    if (timezone.isEmpty) {
      setError('Zeitzone darf nicht leer sein.');
      return;
    }
    Get.find<MqttConnection>().setTimeTimezone(timezone);
    waitingForResponse.value = true;
    lastStatus.value = 'Zeitzone wird gesendet ...';
    lastStatusOk.value = null;
  }

  void sendManualTime() {
    final timezone = timezoneController.text.trim();
    final localTime = manualLocalTimeController.text.trim();
    if (timezone.isEmpty || localTime.isEmpty) {
      setError('Zeitzone und lokale Zeit müssen gesetzt sein.');
      return;
    }
    Get.find<MqttConnection>().setManualTime(timezone: timezone, localTime: localTime);
    waitingForResponse.value = true;
    lastStatus.value = 'Manuelle Zeit wird gesendet ...';
    lastStatusOk.value = null;
  }

  void clearManualTime() {
    Get.find<MqttConnection>().clearManualTime();
    waitingForResponse.value = true;
    lastStatus.value = 'Manuelle Zeit wird verworfen ...';
    lastStatusOk.value = null;
  }

  void sendTimeConfig() {
    final time = _mapOrEmpty(timetableData['time']);
    if (time.isEmpty) {
      setError('Keine timetable.time-Konfiguration vorhanden.');
      return;
    }
    Get.find<MqttConnection>().publishTimeConfig(time);
    waitingForResponse.value = true;
    lastStatus.value = 'Zeitquellen-Konfiguration wird gesendet ...';
    lastStatusOk.value = null;
  }

  void sendTimetable() {
    final mqttConnection = Get.find<MqttConnection>();
    syncRawJsonFromData();
    mqttConnection.publishTimetable(Map<String, dynamic>.from(timetableData));
    waitingForResponse.value = true;
    lastStatus.value = 'Timetable gesendet. Warte auf Bestätigung ...';
    lastStatusOk.value = null;
  }

  bool applyRawJson() {
    try {
      final parsed = jsonDecode(rawJsonController.text);
      if (parsed is! Map) {
        setError('JSON muss ein Objekt sein.');
        return false;
      }
      timetableData
        ..clear()
        ..addAll(Map<String, dynamic>.from(parsed));
      _syncTimezoneControllerFromTimetable();
      lastStatus.value = 'JSON übernommen, noch nicht gesendet.';
      lastStatusOk.value = true;
      return true;
    } catch (e) {
      setError('JSON ist ungültig: $e');
      return false;
    }
  }

  void syncRawJsonFromData() {
    rawJsonController.text = const JsonEncoder.withIndent('  ').convert(timetableData);
  }

  void updateTopLevel(String section, String key, dynamic value) {
    final next = _deepCopy(timetableData);
    final sectionData = Map<String, dynamic>.from((next[section] as Map?) ?? <String, dynamic>{});
    sectionData[key] = value;
    next[section] = sectionData;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
    _syncTimezoneControllerFromTimetable();
  }

  void updateAllowedSource(String source, bool enabled) {
    final next = _deepCopy(timetableData);
    final time = Map<String, dynamic>.from((next['time'] as Map?) ?? <String, dynamic>{});
    final sources = List<String>.from((time['allowed_sources'] as List?)?.map((e) => e.toString()) ?? const <String>[]);
    if (enabled && !sources.contains(source)) {
      sources.add(source);
    } else if (!enabled) {
      sources.remove(source);
    }
    time['allowed_sources'] = sources;
    next['time'] = time;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
  }

  void updateEntry(String entryId, String key, dynamic value) {
    final next = _deepCopy(timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    final entry = Map<String, dynamic>.from((timetable[entryId] as Map?) ?? <String, dynamic>{});
    entry[key] = value;
    timetable[entryId] = entry;
    next['timetable'] = timetable;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
  }

  void addEntry() {
    final next = _deepCopy(timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    final id = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    timetable[id] = <String, dynamic>{
      'day': 'Monday',
      'start': '08:00',
      'end': '12:00',
      'end_behavior': 'return_to_dock',
      'enabled': true,
      'auto_start': true,
      'minimum_remaining_window_minutes': 30,
      'required_battery_state': 'full',
    };
    next['timetable'] = timetable;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
  }

  void removeEntry(String entryId) {
    final next = _deepCopy(timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    timetable.remove(entryId);
    next['timetable'] = timetable;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
  }

  void _updateOptionalStatusBlocks(Map<String, dynamic> payload) {
    final state = _mapOrEmpty(payload['time_state']);
    if (state.isNotEmpty) {
      timeState
        ..clear()
        ..addAll(_deepCopy(state));
      _syncTimezoneControllerFromTimeState();
    }
    final robot = _mapOrEmpty(payload['robot_state']);
    if (robot.isNotEmpty) {
      robotState
        ..clear()
        ..addAll(_deepCopy(robot));
    }
  }

  void _syncTimezoneControllerFromTimetable() {
    final time = _mapOrEmpty(timetableData['time']);
    final timezone = time['timezone']?.toString();
    if (timezone != null && timezone.isNotEmpty && timezoneController.text != timezone) {
      timezoneController.text = timezone;
    }
  }

  void _syncTimezoneControllerFromTimeState() {
    final timezone = timeState['timezone']?.toString();
    if (timezone != null && timezone.isNotEmpty && timezoneController.text != timezone) {
      timezoneController.text = timezone;
    }
  }

  Map<String, dynamic> _mapOrEmpty(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  bool? _validOrNull(dynamic value) {
    if (value is bool) return value;
    return null;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value == null) {
      return <String>[];
    }
    return <String>[value.toString()];
  }

  Map<String, dynamic> _deepCopy(Map data) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  }

  @override
  void onClose() {
    rawJsonController.dispose();
    timezoneController.dispose();
    manualLocalTimeController.dispose();
    super.onClose();
  }
}
