import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class StatusTransitionLogController extends GetxController {
  final logPayload = <String, dynamic>{}.obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final rawJsonController = TextEditingController(text: '{}');

  final limitController = TextEditingController(text: '20');
  final selectedDay = Rxn<DateTime>();

  bool get hasData => entries.isNotEmpty || logPayload.isNotEmpty;

  int get totalEntries => _asInt(logPayload['total_entries']);
  int get returnedEntries => _asInt(logPayload['returned_entries'], fallback: entries.length);
  int get effectiveLimit => _asInt(logPayload['limit'], fallback: requestedLimit);

  int get requestedLimit {
    final parsed = int.tryParse(limitController.text.trim());
    if (parsed == null) return 20;
    return parsed.clamp(1, 300).toInt();
  }

  List<Map<String, dynamic>> get entries {
    final value = logPayload['entries'];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(_jsonSafe(entry) as Map))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> get filteredEntries {
    final filterDay = selectedDay.value;
    if (filterDay == null) {
      return entries;
    }
    return entries.where((entry) => _isSameLocalDay(_entryLocalDay(entry), filterDay)).toList(growable: false);
  }

  String get selectedDayText {
    final value = selectedDay.value;
    if (value == null) {
      return 'Alle Tage';
    }
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year.toString().padLeft(4, '0')}';
  }

  void setSelectedDay(DateTime? day) {
    if (day == null) {
      selectedDay.value = null;
      return;
    }
    selectedDay.value = DateTime(day.year, day.month, day.day);
  }

  Map<String, dynamic>? get currentEntry {
    for (final entry in entries) {
      if (entry['duration_is_current'] == true) {
        return entry;
      }
    }
    return entries.isEmpty ? null : entries.first;
  }

  String get jsonString {
    if (logPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(_jsonSafe(logPayload));
  }

  String exportJsonString() {
    syncRawJsonFromData();
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'local/download';
    lastStatus.value = 'Protokoll-JSON wurde zum Download vorbereitet.';
    lastStatusOk.value = true;
    waitingForResponse.value = false;
    return rawJsonController.text;
  }

  void syncRawJsonFromData() {
    rawJsonController.text = jsonString;
  }

  void setLogPayload(Map<dynamic, dynamic> payload, {String topic = 'statustransition_log/json'}) {
    final root = payload['d'] is Map ? Map<dynamic, dynamic>.from(payload['d'] as Map) : payload;
    final normalized = Map<String, dynamic>.from(_jsonSafe(root) as Map);

    logPayload
      ..clear()
      ..addAll(_deepCopy(normalized));

    final payloadLimit = _asInt(normalized['limit']);
    if (payloadLimit > 0) {
      limitController.text = payloadLimit.toString();
    }

    syncRawJsonFromData();
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    lastStatusOk.value = true;
    waitingForResponse.value = false;

    final total = totalEntries;
    final returned = returnedEntries;
    lastStatus.value = returned == 0
        ? 'Protokoll empfangen, aber es wurden keine Einträge geliefert.'
        : '$returned von $total Protokoll-Einträgen empfangen.';
  }

  void requestLog() {
    final limit = requestedLimit;
    limitController.text = limit.toString();
    Get.find<MqttConnection>().requestStatusTransitionLog(limit: limit);
    lastStatus.value = 'Protokolldaten werden angefordert ...';
    lastTopic.value = 'statustransition_log/set/renew/json';
    lastStatusOk.value = null;
    waitingForResponse.value = true;
  }

  void setError(String message, {String topic = 'statustransition_log/json'}) {
    lastStatus.value = message;
    syncRawJsonFromData();
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    lastStatusOk.value = false;
    waitingForResponse.value = false;
  }

  String stateText(Map<String, dynamic> entry) {
    return _text(entry['state'], fallback: '-');
  }

  String subStateText(Map<String, dynamic> entry) {
    return _text(entry['sub_state'], fallback: '');
  }

  String previousStateText(Map<String, dynamic> entry) {
    return _text(entry['previous_state'], fallback: 'Start');
  }

  String previousSubStateText(Map<String, dynamic> entry) {
    return _text(entry['previous_sub_state'], fallback: '');
  }

  String transitionText(Map<String, dynamic> entry) {
    final previous = previousStateText(entry);
    final current = stateText(entry);
    return '$previous → $current';
  }

  String timestampText(Map<String, dynamic> entry) {
    final raw = entry['timestamp']?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.isEmpty ? '-' : raw;
    }
    final local = parsed.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year.toString().padLeft(4, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String durationText(Map<String, dynamic> entry) {
    final seconds = _asDouble(entry['duration_seconds']);
    if (seconds == null) return '-';
    final rounded = seconds.round();
    final hours = rounded ~/ 3600;
    final minutes = (rounded % 3600) ~/ 60;
    final secs = rounded % 60;

    if (hours > 0) {
      return '${hours} h ${minutes.toString().padLeft(2, '0')} min ${secs.toString().padLeft(2, '0')} s';
    }
    if (minutes > 0) {
      return '${minutes} min ${secs.toString().padLeft(2, '0')} s';
    }
    return '$secs s';
  }

  String percentageText(dynamic value) {
    final number = _asDouble(value);
    if (number == null) return '-';
    final percent = number <= 1.0 ? number * 100 : number;
    return '${percent.toStringAsFixed(percent == percent.roundToDouble() ? 0 : 1)} %';
  }

  String boolText(dynamic value, {required String yes, required String no}) {
    return _asBool(value) ? yes : no;
  }

  bool isCurrent(Map<String, dynamic> entry) => entry['duration_is_current'] == true;
  bool isCharging(Map<String, dynamic> entry) => _asBool(entry['is_charging']);
  bool isEmergency(Map<String, dynamic> entry) => _asBool(entry['emergency']);

  Map<String, dynamic> positionFor(Map<String, dynamic> entry) {
    final value = entry['position'];
    if (value is Map) {
      return Map<String, dynamic>.from(_jsonSafe(value) as Map);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> temperaturesFor(Map<String, dynamic> entry) {
    final value = entry['temperatures'];
    if (value is Map) {
      return Map<String, dynamic>.from(_jsonSafe(value) as Map);
    }
    return const <String, dynamic>{};
  }

  String compactNumber(dynamic value, {int decimals = 2}) {
    final number = _asDouble(value);
    if (number == null) return '-';
    return number.toStringAsFixed(decimals);
  }

  DateTime? _entryLocalDay(Map<String, dynamic> entry) {
    final raw = entry['timestamp']?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _isSameLocalDay(DateTime? left, DateTime right) {
    if (left == null) {
      return false;
    }
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }

  String _text(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  dynamic _jsonSafe(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), _jsonSafe(item)));
    }
    if (value is List) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    return value;
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> map) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(map)) as Map);
  }

  @override
  void onClose() {
    rawJsonController.dispose();
    limitController.dispose();
    super.onClose();
  }
}
