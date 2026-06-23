import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class GpsStateController extends GetxController {
  final state1 = <String, dynamic>{}.obs;
  final state2 = <String, dynamic>{}.obs;
  final state3 = <String, dynamic>{}.obs;
  final state4 = <String, dynamic>{}.obs;
  final settings = <String, dynamic>{}.obs;
  final draftValues = <String, dynamic>{}.obs;
  final dirtyKeys = <String>{}.obs;
  final validation = <String, dynamic>{}.obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;

  Timer? _responseTimeout;
  int _waitGeneration = 0;

  bool get hasState1 => state1.isNotEmpty;
  bool get hasState2 => state2.isNotEmpty;
  bool get hasState3 => state3.isNotEmpty;
  bool get hasState4 => state4.isNotEmpty;
  bool get hasSettings => settings.isNotEmpty;

  bool get available => _bool(_value(state1, 'available') ?? _value(state2, 'available'));
  String get quality => _text(_value(state1, 'quality') ?? _value(state2, 'quality'));
  int get visible => _int(_value(state1, 'visible') ?? _value(state2, 'visible'));
  int get used => _int(_value(state1, 'used') ?? _value(state2, 'used'));
  double get avgCn0 => _double(_value(state1, 'avg_cn0') ?? _value(state2, 'avg_cn0'));
  double get minCn0 => _double(_value(state2, 'min_cn0'));
  double get maxCn0 => _double(_value(state2, 'max_cn0'));
  int get weakCount => _int(_value(state2, 'weak_count'));
  int get goodCount => _int(_value(state2, 'good_count'));

  List<Map<String, dynamic>> get usedSatellites => _satellitesFrom(state3);
  List<Map<String, dynamic>> get allSatellites => _satellitesFrom(state4);
  Map<String, dynamic> get systems => _map(_value(state2, 'systems'));

  bool get publishState4Enabled => _bool(settingDraftValue('publish_state4', fallback: _value(settings, 'publish_state4')));

  Duration? get dataAge {
    final raw = _value(state1, 'updated_at') ?? _value(state2, 'updated_at');
    final updated = _parseDate(raw);
    if (updated == null) return null;
    return DateTime.now().difference(updated);
  }

  bool get dataLooksStale {
    final age = dataAge;
    if (age == null) return false;
    return age.inSeconds > 5;
  }

  String get rawJson {
    final payload = <String, dynamic>{
      'state1': state1,
      'state2': state2,
      'state3': state3,
      'state4': state4,
      'settings': settings,
      'validation': validation,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  dynamic settingDraftValue(String key, {dynamic fallback}) {
    if (draftValues.containsKey(key)) {
      return draftValues[key];
    }
    return _settingValue(key, fallback: fallback);
  }

  void updateDraft(String key, dynamic value) {
    draftValues[key] = value;
    final current = _settingValue(key);
    if (_normalized(value) == _normalized(current)) {
      dirtyKeys.remove(key);
    } else {
      dirtyKeys.add(key);
    }
    draftValues.refresh();
    dirtyKeys.refresh();
  }

  void resetDraft() {
    draftValues.clear();
    dirtyKeys.clear();
  }

  void requestRenew() {
    waitingForResponse.value = true;
    lastStatus.value = 'GPS-State wird neu angefordert ...';
    lastTopic.value = MqttConnection.gpsStateRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine GPS-State-Antwort empfangen. Bitte Topic gps_state/# prüfen.');
    Get.find<MqttConnection>().requestGpsState();
  }

  void publishSession() {
    final payload = _dirtyPayload();
    if (payload.isEmpty) return;
    waitingForResponse.value = true;
    lastStatus.value = 'GPS-State-Sessionwerte werden gesendet ...';
    lastTopic.value = MqttConnection.gpsStateSetSessionJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine GPS-State-Validierung empfangen. Bitte Status neu laden.');
    Get.find<MqttConnection>().publishGpsStateSessionSettings(payload);
  }

  void publishPersistent() {
    final payload = _dirtyPayload();
    if (payload.isEmpty) return;
    waitingForResponse.value = true;
    lastStatus.value = 'GPS-State-Werte werden dauerhaft gespeichert ...';
    lastTopic.value = MqttConnection.gpsStateSetPersistentJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine GPS-State-Validierung empfangen. Bitte Status neu laden.');
    Get.find<MqttConnection>().publishGpsStatePersistentSettings(payload);
  }

  void setStatePayload(int stateNumber, Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    switch (stateNumber) {
      case 1:
        state1.assignAll(root);
        break;
      case 2:
        state2.assignAll(root);
        break;
      case 3:
        state3.assignAll(root);
        break;
      case 4:
        state4.assignAll(root);
        break;
    }
    lastStatus.value = 'GPS-State $stateNumber empfangen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void setSettingsPayload(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    settings.assignAll(root);
    _refreshDraftFromSettings();
    lastStatus.value = 'GPS-State-Einstellungen empfangen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void setValidation(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    validation.assignAll(root);
    final valid = _bool(root['valid'] ?? root['ok'] ?? root['success']);
    lastStatus.value = valid ? 'GPS-State-Änderung akzeptiert.' : 'GPS-State-Änderung wurde abgelehnt.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    if (valid) {
      dirtyKeys.clear();
    }
    _clearResponseTimeout();
  }

  void setError(String message, {String topic = 'local/error'}) {
    waitingForResponse.value = false;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _clearResponseTimeout();
  }

  Map<String, dynamic> _dirtyPayload() {
    final result = <String, dynamic>{};
    for (final key in dirtyKeys) {
      result[key] = <String, dynamic>{'value': draftValues[key]};
    }
    return result;
  }

  void _refreshDraftFromSettings() {
    final next = <String, dynamic>{};
    for (final key in gpsStateSettingKeys) {
      final value = _settingValue(key);
      if (value != null) next[key] = value;
    }
    for (final entry in next.entries) {
      if (!dirtyKeys.contains(entry.key)) {
        draftValues[entry.key] = entry.value;
      }
    }
    draftValues.refresh();
  }

  dynamic _settingValue(String key, {dynamic fallback}) {
    final direct = settings[key];
    if (direct is Map) {
      if (direct.containsKey('value')) return direct['value'];
      if (direct.containsKey('session')) return direct['session'];
      if (direct.containsKey('persistent')) return direct['persistent'];
      if (direct.containsKey('default')) return direct['default'];
    }
    if (direct != null) return direct;

    final values = settings['values'];
    if (values is Map && values[key] != null) return values[key];

    final items = settings['settings'];
    if (items is Map) {
      final entry = items[key];
      if (entry is Map) {
        if (entry.containsKey('value')) return entry['value'];
        if (entry.containsKey('session')) return entry['session'];
        if (entry.containsKey('persistent')) return entry['persistent'];
        if (entry.containsKey('default')) return entry['default'];
      }
      if (entry != null) return entry;
    }
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final itemKey = item['key'] ?? item['id'] ?? item['name'];
        if (itemKey?.toString() != key) continue;
        if (item.containsKey('value')) return item['value'];
        if (item.containsKey('session')) return item['session'];
        if (item.containsKey('persistent')) return item['persistent'];
        if (item.containsKey('default')) return item['default'];
      }
    }
    return fallback;
  }

  Map<String, dynamic> _root(Map<String, dynamic> payload) {
    final d = payload['d'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return Map<String, dynamic>.from(payload);
  }

  dynamic _value(Map<String, dynamic> map, String key) {
    if (map.containsKey(key)) return map[key];
    final d = map['d'];
    if (d is Map && d.containsKey(key)) return d[key];
    return null;
  }

  List<Map<String, dynamic>> _satellitesFrom(Map<String, dynamic> map) {
    final raw = _value(map, 'satellites');
    if (raw is List) {
      return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      if (raw > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw > 1000000000) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is double) {
      if (raw > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(raw.round());
      if (raw > 1000000000) return DateTime.fromMillisecondsSinceEpoch((raw * 1000).round());
    }
    return DateTime.tryParse(raw.toString());
  }

  void _armResponseTimeout(String message) {
    _responseTimeout?.cancel();
    final generation = ++_waitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _waitGeneration) return;
      waitingForResponse.value = false;
      lastStatus.value = message;
      lastUpdated.value = DateTime.now();
    });
  }

  void _clearResponseTimeout() {
    _responseTimeout?.cancel();
    _responseTimeout = null;
    _waitGeneration++;
  }

  dynamic _normalized(dynamic value) {
    if (value is num) return value.toDouble();
    return value;
  }

  String _text(dynamic value) => value?.toString() ?? '';

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on' || normalized == 'enabled';
  }
}

const gpsStateSettingKeys = <String>[
  'enabled',
  'publish_rate_hz',
  'publish_state1',
  'publish_state2',
  'publish_state3',
  'publish_state4',
  'weak_cn0_threshold',
  'good_cn0_threshold',
];
