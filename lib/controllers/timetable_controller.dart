import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class TimetableController extends GetxController {
  final timetableData = <String, dynamic>{}.obs;
  final lastStatus = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final rawJsonController = TextEditingController();

  bool get hasData => timetableData.isNotEmpty;

  void setTimetable(Map<String, dynamic> data) {
    timetableData.clear();
    timetableData.addAll(_deepCopy(data));
    rawJsonController.text = const JsonEncoder.withIndent('  ').convert(timetableData);
    lastUpdated.value = DateTime.now();
    lastStatus.value = 'Timetable empfangen';
    lastStatusOk.value = true;
    waitingForResponse.value = false;
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
      timetableData.clear();
      timetableData.addAll(Map<String, dynamic>.from(parsed));
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
    timetableData.clear();
    timetableData.addAll(next);
    syncRawJsonFromData();
  }

  void updateEntry(String entryId, String key, dynamic value) {
    final next = _deepCopy(timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    final entry = Map<String, dynamic>.from((timetable[entryId] as Map?) ?? <String, dynamic>{});
    entry[key] = value;
    timetable[entryId] = entry;
    next['timetable'] = timetable;
    timetableData.clear();
    timetableData.addAll(next);
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
    timetableData.clear();
    timetableData.addAll(next);
    syncRawJsonFromData();
  }

  void removeEntry(String entryId) {
    final next = _deepCopy(timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    timetable.remove(entryId);
    next['timetable'] = timetable;
    timetableData.clear();
    timetableData.addAll(next);
    syncRawJsonFromData();
  }

  Map<String, dynamic> _deepCopy(Map data) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  }

  @override
  void onClose() {
    rawJsonController.dispose();
    super.onClose();
  }
}
