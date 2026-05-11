import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

enum SuspensionUiState {
  none,
  oneDay,
  threeDays,
  indefinite,
  customDate,
}

class TimetableController extends GetxController {
  static const String indefiniteSuspensionValue = '9999-12-31T23:59:59Z';

  static String _todayDateText() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static const visibleEntryFields = <String>{
    'day',
    'start',
    'end',
    'end_behavior',
    'enabled',
    'auto_start',
  };

  final timetableData = <String, dynamic>{}.obs;
  final robotState = <String, dynamic>{}.obs;
  final lastRemarks = <String>[].obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final currentSystemTimeIso = RxnString();

  final rawJsonController = TextEditingController();
  final timezoneController = TextEditingController(text: 'Europe/Berlin');
  final manualDateController = TextEditingController(text: _todayDateText());
  final hourController = TextEditingController(text: '22');
  final minuteController = TextEditingController(text: '30');
  final ntpServerController = TextEditingController(text: 'pool.ntp.org');

  final selectedTimeSource = 'ntp'.obs;

  static const availableTimezones = <String>[
    'Europe/Berlin',
    'Europe/Vienna',
    'Europe/Zurich',
    'Europe/Amsterdam',
    'Europe/Paris',
    'Europe/London',
    'UTC',
  ];

  static const timeSourceLabels = <String, String>{
    'system': 'Systemzeit',
    'ntp': 'NTP',
    'gps': 'GPS',
    'manual': 'Manuell',
  };

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
  bool get hasRobotState => robotState.isNotEmpty;

  dynamic get autoMowSuspension => robotState['AutoMowSuspension'] ?? 0;
  bool get isSuspended => autoMowSuspension != null && autoMowSuspension != 0 && autoMowSuspension.toString() != '0' && autoMowSuspension.toString().trim().isNotEmpty;

  bool get isIndefinitelySuspended {
    final value = autoMowSuspension;
    if (value == null || value == 0 || value.toString() == '0' || value.toString().trim().isEmpty) {
      return false;
    }

    final text = value.toString().trim();
    if (text.startsWith('9999-')) {
      return true;
    }

    final parsed = DateTime.tryParse(text);
    return parsed != null && parsed.year >= 9999;
  }

  SuspensionUiState get suspensionUiState {
    if (!isSuspended) {
      return SuspensionUiState.none;
    }

    if (isIndefinitelySuspended) {
      return SuspensionUiState.indefinite;
    }

    if (_suspensionMatchesDays(1)) {
      return SuspensionUiState.oneDay;
    }

    if (_suspensionMatchesDays(3)) {
      return SuspensionUiState.threeDays;
    }

    return SuspensionUiState.customDate;
  }

  String get selectedTimezone {
    final value = timezoneController.text.trim();
    return value.isEmpty ? 'Europe/Berlin' : value;
  }

  String get formattedSystemTime {
    final raw = currentSystemTimeIso.value;
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return _formatDateTimeForUi(parsed ?? DateTime.now());
  }

  String get timeSourceDescription {
    switch (selectedTimeSource.value) {
      case 'system':
        return 'Vorhandene Systemzeit übernehmen.';
      case 'gps':
        return 'Zeit aus GPS-Signal übernehmen.';
      case 'manual':
        return 'Datum und Uhrzeit manuell setzen.';
      case 'ntp':
      default:
        return 'Zeit über NTP-Server synchronisieren.';
    }
  }

  String get localTimeForManualSet {
    final hour = int.tryParse(hourController.text.trim()) ?? 0;
    final minute = int.tryParse(minuteController.text.trim()) ?? 0;
    final dateText = manualDateController.text.trim();
    final date = DateTime.tryParse(dateText) ?? DateTime.now();
    final manual = DateTime(date.year, date.month, date.day, hour.clamp(0, 23), minute.clamp(0, 59));
    final offset = manual.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final offsetText = '$sign${abs.inHours.toString().padLeft(2, '0')}:${(abs.inMinutes % 60).toString().padLeft(2, '0')}';
    return '${manual.year.toString().padLeft(4, '0')}-${manual.month.toString().padLeft(2, '0')}-${manual.day.toString().padLeft(2, '0')}T${manual.hour.toString().padLeft(2, '0')}:${manual.minute.toString().padLeft(2, '0')}:00$offsetText';
  }

  void setTimetablePayload(Map<String, dynamic> payload, {String topic = 'timetable/json'}) {
    final wasWaiting = waitingForResponse.value;
    final status = wasWaiting ? 'Gespeichert. Server hat die Timetable bestätigt.' : 'Timetable vom Server empfangen.';
    setTimetable(payload, statusMessage: status, topic: topic);
  }

  void setTimetable(Map<String, dynamic> data, {String statusMessage = 'Timetable empfangen', String topic = 'timetable/json'}) {
    final normalized = _normalizeTimetableData(data);
    timetableData
      ..clear()
      ..addAll(_deepCopy(normalized));
    editingEntryIds.clear();
    syncRawJsonFromData();
    _syncControllersFromTimeSettings();
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
    lastStatus.value = statusMessage;
    lastStatusOk.value = true;
    lastRemarks.clear();
    waitingForResponse.value = false;
  }


  // Compatibility handlers for older OpenMower time/timetable topics.
  void setTimeStatus(Map<String, dynamic> payload) {
    final state = _mapOrEmpty(payload['time_state']).isNotEmpty ? _mapOrEmpty(payload['time_state']) : payload;
    final source = (state['source'] ?? state['active_source'])?.toString();
    if (source == 'manual' || source == 'ntp' || source == 'gps' || source == 'system') {
      selectedTimeSource.value = source!;
    }
    _updateSystemTimeFromMap(state);
    lastRemarks.assignAll(_stringList(payload['remarks']));
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'legacy/time/status';
    lastStatusOk.value = _validOrNull(payload['valid']) ?? _validOrNull(state['valid']);
    lastStatus.value = 'Zeitstatus empfangen.';
    waitingForResponse.value = false;
  }

  void setTimeConfigStatus(Map<String, dynamic> payload) {
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'legacy/time/config/status';
    lastStatusOk.value = true;
    lastStatus.value = 'Zeit-Konfiguration bestätigt.';
    waitingForResponse.value = false;
  }

  void setActionResult(Map<String, dynamic> payload) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final status = (root['status'] ?? '').toString().toLowerCase().trim();
    final result = (root['result'] ?? '').toString().toLowerCase().trim();
    final ok = _validOrNull(root['valid']) ??
        _validOrNull(root['ok']) ??
        _validOrNull(root['accepted']) ??
        _validOrNull(root['success']) ??
        (status == 'ok' || status == 'accepted' ? true : null) ??
        (result == 'valid' || result == 'ok' ? true : null);
    lastRemarks.assignAll(_stringList(root['remarks']));
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'legacy/action_result';
    lastStatusOk.value = ok;
    final action = (root['action'] ?? 'Action').toString();
    if (ok == true) {
      lastStatus.value = '$action bestätigt.';
    } else if (ok == false) {
      lastStatus.value = '$action abgelehnt.';
    } else {
      lastStatus.value = '$action verarbeitet. Warte auf Bestätigung ...';
    }
    waitingForResponse.value = false;
  }

  void setValidation(Map<String, dynamic> payload, {String topic = 'timetable/validation/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final status = (root['status'] ?? '').toString().toLowerCase().trim();
    final result = (root['result'] ?? '').toString().toLowerCase().trim();
    final ok = _validOrNull(root['valid']) ??
        _validOrNull(root['ok']) ??
        _validOrNull(root['accepted']) ??
        _validOrNull(root['success']) ??
        (status == 'ok' || status == 'accepted' ? true : null) ??
        (result == 'valid' || result == 'ok' ? true : null);
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
    lastStatusOk.value = ok;
    lastRemarks.assignAll(_stringList(root['remarks']));
    if (ok == true) {
      lastStatus.value = 'Server-Validierung erfolgreich.';
    } else if (ok == false) {
      lastStatus.value = 'Speichern fehlgeschlagen. Server hat die Timetable abgelehnt.';
    } else {
      lastStatus.value = 'Validierungsantwort empfangen. Warte auf eindeutige Bestätigung ...';
    }
    waitingForResponse.value = false;
  }

  void setRobotState(Map<String, dynamic> payload, {String topic = 'robot_state/json'}) {
    final state = _mapOrEmpty(payload['d']).isNotEmpty ? _mapOrEmpty(payload['d']) : payload;
    robotState
      ..clear()
      ..addAll(_deepCopy(state));
    _updateSystemTimeFromMap(state);
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
  }

  void setResponse(bool accepted, String reason, {String topic = 'timetable/response/json'}) {
    waitingForResponse.value = false;
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
    lastStatusOk.value = accepted;
    lastStatus.value = accepted
        ? (reason.isEmpty ? 'Service hat die Änderung bestätigt.' : 'Bestätigt: $reason')
        : (reason.isEmpty ? 'Service hat die Änderung abgelehnt.' : 'Abgelehnt: $reason');
  }

  void setError(String message, {String topic = ''}) {
    waitingForResponse.value = false;
    lastUpdated.value = DateTime.now();
    if (topic.isNotEmpty) lastTopic.value = topic;
    lastStatusOk.value = false;
    lastStatus.value = message;
  }

  void requestTimetable() {
    Get.find<MqttConnection>().requestTimetable();
    lastStatus.value = 'Timetable wird vom Server angefordert ...';
    lastTopic.value = 'timetable/set/renew/json';
    lastStatusOk.value = null;
  }

  void setSelectedTimeSource(String source) {
    if (source == 'manual' || source == 'ntp' || source == 'gps' || source == 'system') {
      selectedTimeSource.value = source;
      _updateTimeSettings((settings) {
        settings['active_source'] = source;
        _applySourceSpecificValues(settings);
      });
    }
  }

  void updateTimezone(String timezone) {
    _updateTimeSettings((settings) {
      settings['timezone'] = timezone.trim().isEmpty ? 'Europe/Berlin' : timezone.trim();
    });
  }

  void updateManualTimeFromFields() {
    _updateTimeSettings((settings) {
      settings['manual'] = <String, dynamic>{'datetime': localTimeForManualSet};
    });
  }

  void updateNtpServer(String server) {
    _updateTimeSettings((settings) {
      settings['ntp'] = <String, dynamic>{'server': server.trim().isEmpty ? 'pool.ntp.org' : server.trim()};
    });
  }

  void updateTimeSettingsNow() {
    _updateTimeSettings((settings) {
      settings['timezone'] = selectedTimezone;
      settings['active_source'] = selectedTimeSource.value;
      _applySourceSpecificValues(settings);
    }, setLocalStatus: false);
    syncRawJsonFromData();
    Get.find<MqttConnection>().publishTimetable(Map<String, dynamic>.from(timetableData));
    waitingForResponse.value = true;
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'timetable/set/json';
    lastStatus.value = 'Zeitaktualisierung gesendet. Warte auf Serverantwort ...';
    lastStatusOk.value = null;
  }

  void _applySourceSpecificValues(Map<String, dynamic> settings) {
    final source = (settings['active_source'] ?? 'ntp').toString();
    if (source == 'manual') {
      settings['manual'] = <String, dynamic>{'datetime': localTimeForManualSet};
    } else {
      settings['manual'] = _mapOrEmpty(settings['manual']).isEmpty ? <String, dynamic>{'datetime': null} : _mapOrEmpty(settings['manual']);
    }
    settings['ntp'] = <String, dynamic>{'server': ntpServerController.text.trim().isEmpty ? 'pool.ntp.org' : ntpServerController.text.trim()};
    settings['gps'] = _mapOrEmpty(settings['gps']);
  }

  void _updateTimeSettings(void Function(Map<String, dynamic> settings) mutate, {bool setLocalStatus = true}) {
    final next = _deepCopy(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
    final settings = Map<String, dynamic>.from((next['timeSettings'] as Map?) ?? _defaultTimeSettings());
    mutate(settings);
    next['timeSettings'] = settings;
    timetableData
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
    if (setLocalStatus) {
      lastStatus.value = 'Time Settings lokal aktualisiert, noch nicht gesendet.';
      lastStatusOk.value = true;
    }
  }

  void sendTimetable() {
    syncRawJsonFromData();
    Get.find<MqttConnection>().publishTimetable(Map<String, dynamic>.from(timetableData));
    waitingForResponse.value = true;
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'timetable/set/json';
    lastStatus.value = 'Timetable gesendet. Warte auf Serverantwort ...';
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
        ..addAll(_normalizeTimetableData(Map<String, dynamic>.from(parsed)));
      editingEntryIds.clear();
      _syncControllersFromTimeSettings();
      syncRawJsonFromData();
      lastUpdated.value = DateTime.now();
      lastTopic.value = 'local/upload';
      lastStatus.value = 'JSON wurde lokal übernommen. Zum Übertragen an den Server bitte Speichern drücken.';
      lastStatusOk.value = true;
      return true;
    } catch (e) {
      setError('JSON ist ungültig: $e', topic: 'local/upload');
      return false;
    }
  }

  bool importJsonString(String jsonText, {String filename = 'Datei'}) {
    rawJsonController.text = jsonText;
    final ok = applyRawJson();
    if (ok) {
      lastStatus.value = 'JSON-Datei "$filename" wurde lokal geladen. Noch nicht an den Server gesendet.';
    }
    return ok;
  }

  String exportJsonString() {
    syncRawJsonFromData();
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'local/download';
    lastStatus.value = 'JSON-Datei wurde zum Download vorbereitet.';
    lastStatusOk.value = true;
    return rawJsonController.text;
  }

  void syncRawJsonFromData() {
    rawJsonController.text = const JsonEncoder.withIndent('  ').convert(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
  }

  bool isEntryEditing(String entryId) => editingEntryIds.contains(entryId);

  void toggleEditEntry(String entryId) {
    if (isEntryEditing(entryId)) {
      editingEntryIds.remove(entryId);
      editingEntryIds.refresh();
      syncRawJsonFromData();
      lastStatus.value = 'Mähzeit gespeichert, noch nicht an den Server gesendet.';
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

  void addEntryFromDraft() {
    final next = _deepCopy(timetableData.isEmpty ? _emptyTimetableData() : timetableData);
    final timetable = Map<String, dynamic>.from((next['timetable'] as Map?) ?? <String, dynamic>{});
    final id = _generateEntryId(timetable.keys.map((e) => e.toString()).toSet());
    timetable[id] = Map<String, dynamic>.from(newEntryDraft);
    next['timetable'] = timetable;
    timetableData
      ..clear()
      ..addAll(next);
    editingEntryIds.remove(id);
    editingEntryIds.refresh();
    _resetNewEntryDraft();
    syncRawJsonFromData();
    lastStatus.value = 'Neue Mähzeit hinzugefügt, noch nicht an den Server gesendet.';
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
    lastStatus.value = 'Mähzeit gelöscht, noch nicht an den Server gesendet.';
    lastStatusOk.value = true;
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
      lastStatus.value = 'Zusätzliche Felder übernommen, noch nicht an den Server gesendet.';
      lastStatusOk.value = true;
      return true;
    } catch (e) {
      setError('Felder-JSON ist ungültig: $e');
      return false;
    }
  }

  void setSuspensionUntil(DateTime until) {
    final value = _isoWithOffset(until);
    Get.find<MqttConnection>().publishSuspension(value);
    waitingForResponse.value = true;
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'timetable/set/suspension/json';
    lastStatus.value = 'Aussetzung bis $value gesendet. Warte auf robot_state ...';
    lastStatusOk.value = null;
  }

  void clearSuspension() {
    Get.find<MqttConnection>().publishSuspension(0);
    waitingForResponse.value = true;
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'timetable/set/suspension/json';
    lastStatus.value = 'Aufheben der Aussetzung gesendet. Warte auf robot_state ...';
    lastStatusOk.value = null;
  }

  void setSuspensionIndefinite() {
    Get.find<MqttConnection>().publishSuspension(indefiniteSuspensionValue);
    waitingForResponse.value = true;
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'timetable/set/suspension/json';
    lastStatus.value = 'Unbestimmte Aussetzung gesendet. Warte auf robot_state ...';
    lastStatusOk.value = null;
  }

  void toggleSuspensionIndefinite() {
    if (isIndefinitelySuspended) {
      clearSuspension();
      return;
    }
    setSuspensionIndefinite();
  }

  void toggleSuspensionDays(int days) {
    if (isSuspended && _suspensionMatchesDays(days)) {
      clearSuspension();
      return;
    }
    final until = _nextMidnightAfterMinimumHours(days * 24);
    setSuspensionUntil(until);
  }

  bool _suspensionMatchesDays(int days) {
    if (isIndefinitelySuspended) return false;
    final value = autoMowSuspension;
    if (value == null || value == 0) return false;
    final until = DateTime.tryParse(value.toString());
    if (until == null) return false;
    final diffHours = until.difference(DateTime.now()).inHours;
    if (days == 1) return diffHours <= 48;
    if (days == 3) return diffHours > 48;
    return false;
  }

  void _resetNewEntryDraft() {
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
  }

  String _generateEntryId(Set<String> existingIds) {
    final now = DateTime.now();
    var id = 'mow_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_${now.microsecond.toRadixString(16)}';
    var counter = 1;
    while (existingIds.contains(id)) {
      id = '${id}_$counter';
      counter += 1;
    }
    return id;
  }

  Map<String, dynamic> _emptyTimetableData() {
    return <String, dynamic>{
      'version': 1,
      'metadata': <String, dynamic>{
        'created_at': _isoWithOffset(DateTime.now()),
        'created_by': 'openmower_app',
        'description': 'Timetable configuration',
      },
      'timeSettings': _defaultTimeSettings(),
      'timetable': <String, dynamic>{},
    };
  }

  Map<String, dynamic> _defaultTimeSettings() {
    return <String, dynamic>{
      'timezone': timezoneController.text.trim().isEmpty ? 'Europe/Berlin' : timezoneController.text.trim(),
      'allowed_sources': <String>['ntp', 'gps', 'manual', 'system'],
      'active_source': selectedTimeSource.value,
      'manual': <String, dynamic>{'datetime': null},
      'ntp': <String, dynamic>{'server': ntpServerController.text.trim().isEmpty ? 'pool.ntp.org' : ntpServerController.text.trim()},
      'gps': <String, dynamic>{},
    };
  }

  Map<String, dynamic> _normalizeTimetableData(Map<String, dynamic> data) {
    // Some MQTT/BSON stacks wrap the actual payload in a top-level "d" object.
    // The UI must work with the real timetable root, not the wrapper.
    final unwrapped = _unwrapTimetableRoot(data);
    final next = _deepCopy(unwrapped);
    if (!next.containsKey('timeSettings') && next.containsKey('time')) {
      final oldTime = _mapOrEmpty(next['time']);
      next['timeSettings'] = <String, dynamic>{
        'timezone': oldTime['timezone'] ?? 'Europe/Berlin',
        'allowed_sources': oldTime['allowed_sources'] ?? <String>['ntp', 'gps', 'manual', 'system'],
        'active_source': oldTime['active_source'] ?? oldTime['fallback_source'] ?? 'ntp',
        'manual': oldTime['manual'] ?? <String, dynamic>{'datetime': oldTime['manual_time']},
        'ntp': oldTime['ntp'] ?? <String, dynamic>{'server': oldTime['ntp_server'] ?? 'pool.ntp.org'},
        'gps': oldTime['gps'] ?? <String, dynamic>{},
      };
      next.remove('time');
    }
    if (!next.containsKey('timeSettings')) {
      next['timeSettings'] = _defaultTimeSettings();
    }
    if (!next.containsKey('timetable') || next['timetable'] is! Map) {
      next['timetable'] = <String, dynamic>{};
    }
    return next;
  }


  Map<String, dynamic> _unwrapTimetableRoot(Map<String, dynamic> data) {
    final wrapped = _mapOrEmpty(data['d']);
    if (wrapped.isNotEmpty &&
        (wrapped.containsKey('timetable') || wrapped.containsKey('timeSettings') || wrapped.containsKey('time') || wrapped.containsKey('version'))) {
      return wrapped;
    }
    return data;
  }

  void _syncControllersFromTimeSettings() {
    final settings = _mapOrEmpty(timetableData['timeSettings']);
    final timezone = settings['timezone']?.toString();
    if (timezone != null && timezone.isNotEmpty && timezoneController.text != timezone) {
      timezoneController.text = timezone;
    }
    final source = settings['active_source']?.toString() ?? 'ntp';
    if (source == 'manual' || source == 'ntp' || source == 'gps' || source == 'system') {
      selectedTimeSource.value = source;
    }
    final ntp = _mapOrEmpty(settings['ntp']);
    final server = ntp['server']?.toString();
    if (server != null && server.isNotEmpty && ntpServerController.text != server) {
      ntpServerController.text = server;
    }
    final manual = _mapOrEmpty(settings['manual']);
    final manualDate = DateTime.tryParse(manual['datetime']?.toString() ?? '');
    if (manualDate != null) {
      manualDateController.text = '${manualDate.year.toString().padLeft(4, '0')}-${manualDate.month.toString().padLeft(2, '0')}-${manualDate.day.toString().padLeft(2, '0')}';
      hourController.text = manualDate.hour.toString().padLeft(2, '0');
      minuteController.text = manualDate.minute.toString().padLeft(2, '0');
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
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == 'ok' || lower == 'accepted' || lower == 'valid' || lower == 'success') return true;
      if (lower == 'false' || lower == 'invalid' || lower == 'rejected' || lower == 'error' || lower == 'failed') return false;
    }
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    return null;
  }

  void _updateSystemTimeFromMap(Map<String, dynamic> map) {
    final candidates = <dynamic>[
      map['system_time'],
      map['current_time'],
      map['datetime'],
      map['date_time'],
      map['time'],
      _mapOrEmpty(map['system'])['time'],
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final text = candidate.toString();
      if (text.isEmpty) continue;
      if (DateTime.tryParse(text) != null) {
        currentSystemTimeIso.value = text;
        return;
      }
    }
  }

  String _formatDateTimeForUi(DateTime dateTime) {
    const weekdays = <String>['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString().padLeft(4, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$weekday, $day.$month.$year · $hour:$minute Uhr';
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value == null) return <String>[];
    return <String>[value.toString()];
  }

  Map<String, dynamic> _deepCopy(Map data) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  }

  DateTime _nextMidnightAfterMinimumHours(int minimumHours) {
    final minimumUntil = DateTime.now().add(Duration(hours: minimumHours));
    return DateTime(minimumUntil.year, minimumUntil.month, minimumUntil.day).add(const Duration(days: 1));
  }

  String _isoWithOffset(DateTime dateTime) {
    final offset = dateTime.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final offsetText = '$sign${abs.inHours.toString().padLeft(2, '0')}:${(abs.inMinutes % 60).toString().padLeft(2, '0')}';
    return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}T${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}$offsetText';
  }

  @override
  void onClose() {
    rawJsonController.dispose();
    timezoneController.dispose();
    manualDateController.dispose();
    hourController.dispose();
    minuteController.dispose();
    ntpServerController.dispose();
    super.onClose();
  }
}
