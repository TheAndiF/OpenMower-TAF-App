import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class TimetableController extends GetxController {
  static const visibleEntryFields = <String>{
    'day',
    'start',
    'end',
    'end_behavior',
    'enabled',
    'auto_start',
  };

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
  final hourController = TextEditingController(text: '22');
  final minuteController = TextEditingController(text: '30');
  final ntpServerController = TextEditingController(text: 'pool.ntp.org');
  final newEntryIdController = TextEditingController(text: 'test_sunday_full_day');

  final selectedTimeSource = 'manual'.obs;
  final editingEntryIds = <String>{}.obs;
  final newEntryDraft = <String, dynamic>{
    'day': 'Sunday',
    'start': '00:00',
    'end': '23:59',
    'end_behavior': 'return_to_dock',
    'enabled': true,
    'auto_start': true,
  }.obs;

  bool get hasData => timetableData.isNotEmpty;
  bool get hasTimeState => timeState.isNotEmpty;
  bool get hasRobotState => robotState.isNotEmpty;
  bool get hasTimeConfigStatus => timeConfigStatus.isNotEmpty;

  String get localTimeForManualSet {
    final hour = int.tryParse(hourController.text.trim()) ?? 0;
    final minute = int.tryParse(minuteController.text.trim()) ?? 0;
    final now = DateTime.now();
    final manual = DateTime(now.year, now.month, now.day, hour.clamp(0, 23), minute.clamp(0, 59));
    final offset = manual.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final offsetText = '$sign${abs.inHours.toString().padLeft(2, '0')}:${(abs.inMinutes % 60).toString().padLeft(2, '0')}';
    return '${manual.year.toString().padLeft(4, '0')}-${manual.month.toString().padLeft(2, '0')}-${manual.day.toString().padLeft(2, '0')}T${manual.hour.toString().padLeft(2, '0')}:${manual.minute.toString().padLeft(2, '0')}:00$offsetText';
  }

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
    editingEntryIds.clear();
    syncRawJsonFromData();
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
      final source = (state['source'] ?? '').toString();
      if (source == 'manual') selectedTimeSource.value = 'manual';
      if (source == 'ntp') selectedTimeSource.value = 'ntp';
      if (source == 'gps') selectedTimeSource.value = 'gps';
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
    Get.find<MqttConnection>().requestTimetable();
    lastStatus.value = 'Timetable wird angefordert ...';
    lastStatusOk.value = null;
  }

  void requestTimeStatus() {
    Get.find<MqttConnection>().requestTimeStatus();
    waitingForResponse.value = true;
    lastStatus.value = 'Zeitstatus wird angefordert ...';
    lastStatusOk.value = null;
  }

  void setSelectedTimeSource(String source) {
    if (source == 'manual' || source == 'ntp' || source == 'gps') {
      selectedTimeSource.value = source;
    }
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
    if (timezone.isEmpty) {
      setError('Zeitzone darf nicht leer sein.');
      return;
    }
    final hour = int.tryParse(hourController.text.trim());
    final minute = int.tryParse(minuteController.text.trim());
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      setError('Stunden müssen 0–23 und Minuten 0–59 sein.');
      return;
    }
    selectedTimeSource.value = 'manual';
    Get.find<MqttConnection>().setManualTime(timezone: timezone, localTime: localTimeForManualSet);
    waitingForResponse.value = true;
    lastStatus.value = 'Manuelle Zeit wird gesendet ...';
    lastStatusOk.value = null;
  }

  void sendNtpServer() {
    final server = ntpServerController.text.trim();
    if (server.isEmpty) {
      setError('NTP Server darf nicht leer sein.');
      return;
    }
    selectedTimeSource.value = 'ntp';
    Get.find<MqttConnection>().setNtpServer(server);
    waitingForResponse.value = true;
    lastStatus.value = 'NTP Server wird gesendet ...';
    lastStatusOk.value = null;
  }

  void synchronizeGps() {
    selectedTimeSource.value = 'gps';
    Get.find<MqttConnection>().requestTimeResync(preferredSource: 'gps');
    waitingForResponse.value = true;
    lastStatus.value = 'GPS-Zeit wird synchronisiert ...';
    lastStatusOk.value = null;
  }

  void clearManualTime() {
    Get.find<MqttConnection>().clearManualTime();
    waitingForResponse.value = true;
    lastStatus.value = 'Manuelle Zeit wird verworfen ...';
    lastStatusOk.value = null;
  }

  void sendTimetable() {
    syncRawJsonFromData();
    Get.find<MqttConnection>().publishTimetable(Map<String, dynamic>.from(timetableData));
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
      editingEntryIds.clear();
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

  bool isEntryEditing(String entryId) => editingEntryIds.contains(entryId);

  void toggleEditEntry(String entryId) {
    if (isEntryEditing(entryId)) {
      editingEntryIds.remove(entryId);
      editingEntryIds.refresh();
      syncRawJsonFromData();
      lastStatus.value = 'Eintrag "$entryId" gespeichert, noch nicht gesendet.';
      lastStatusOk.value = true;
    } else {
      editingEntryIds.add(entryId);
      editingEntryIds.refresh();
    }
  }

  void updateEntry(String entryId, String key, dynamic value) {
    final next = _deepCopy(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
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

  void updateNewEntry(String key, dynamic value) {
    final next = Map<String, dynamic>.from(newEntryDraft);
    next[key] = value;
    newEntryDraft
      ..clear()
      ..addAll(next);
  }

  void addEntryFromDraft({String? overrideId}) {
    final id = (overrideId ?? newEntryIdController.text).trim();
    if (id.isEmpty) {
      setError('Bitte eine Eintrag-ID angeben.');
      return;
    }

    final next = _deepCopy(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    if (timetable.containsKey(id) && overrideId == null) {
      setError('Eintrag-ID "$id" existiert bereits.');
      return;
    }

    timetable[id] = Map<String, dynamic>.from(newEntryDraft);
    next['timetable'] = timetable;
    timetableData
      ..clear()
      ..addAll(next);
    editingEntryIds.remove(id);
    editingEntryIds.refresh();
    _resetNewEntryDraft(existingIds: timetable.keys.map((e) => e.toString()).toSet());
    syncRawJsonFromData();
    lastStatus.value = 'Mähzeit "$id" hinzugefügt, noch nicht gesendet.';
    lastStatusOk.value = true;
  }

  void removeEntry(String entryId) {
    final next = _deepCopy(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    timetable.remove(entryId);
    editingEntryIds.remove(entryId);
    editingEntryIds.refresh();
    next['timetable'] = timetable;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
  }

  Map<String, dynamic> extraFieldsFor(Map<String, dynamic> item) {
    final result = <String, dynamic>{};
    for (final entry in item.entries) {
      if (!visibleEntryFields.contains(entry.key)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  int extraFieldsCount(Map<String, dynamic> item) => extraFieldsFor(item).length;

  bool updateExtraFieldsFromJson(String entryId, String jsonText) {
    try {
      final parsed = jsonDecode(jsonText.trim().isEmpty ? '{}' : jsonText);
      if (parsed is! Map) {
        setError('Felder-JSON muss ein Objekt sein.');
        return false;
      }
      final cleaned = Map<String, dynamic>.from(parsed);
      for (final key in visibleEntryFields) {
        cleaned.remove(key);
      }

      final next = _deepCopy(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
      final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
      final entry = Map<String, dynamic>.from((timetable[entryId] as Map?) ?? <String, dynamic>{});
      entry.removeWhere((key, value) => !visibleEntryFields.contains(key));
      entry.addAll(cleaned);
      timetable[entryId] = entry;
      next['timetable'] = timetable;
      timetableData
        ..clear()
        ..addAll(next);
      syncRawJsonFromData();
      lastStatus.value = 'Zusätzliche Felder für "$entryId" übernommen, noch nicht gesendet.';
      lastStatusOk.value = true;
      return true;
    } catch (e) {
      setError('Felder-JSON ist ungültig: $e');
      return false;
    }
  }

  void _resetNewEntryDraft({Set<String> existingIds = const <String>{}}) {
    newEntryDraft
      ..clear()
      ..addAll(<String, dynamic>{
        'day': 'Sunday',
        'start': '00:00',
        'end': '23:59',
        'end_behavior': 'return_to_dock',
        'enabled': true,
        'auto_start': true,
      });
    newEntryIdController.text = _generateEntryId(existingIds);
  }

  String _generateEntryId(Set<String> existingIds) {
    var id = 'entry_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    var counter = 1;
    while (existingIds.contains(id)) {
      id = 'entry_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}_$counter';
      counter += 1;
    }
    return id;
  }

  Map<String, dynamic> _emptyTimetableData() {
    return <String, dynamic>{
      'version': 1,
      'time': <String, dynamic>{
        'timezone': timezoneController.text.trim().isEmpty ? 'Europe/Berlin' : timezoneController.text.trim(),
        'required': true,
        'allowed_sources': <String>['ntp', 'gps', 'manual', 'system'],
        'fallback_source': 'system',
        'require_valid_time': true,
      },
      'timetable': <String, dynamic>{},
    };
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
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value == null) return <String>[];
    return <String>[value.toString()];
  }

  Map<String, dynamic> _deepCopy(Map data) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  }

  @override
  void onClose() {
    rawJsonController.dispose();
    timezoneController.dispose();
    hourController.dispose();
    minuteController.dispose();
    ntpServerController.dispose();
    newEntryIdController.dispose();
    super.onClose();
  }
}
