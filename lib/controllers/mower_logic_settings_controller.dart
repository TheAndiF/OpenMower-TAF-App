import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class MowerLogicSettingsController extends GetxController {
  final statusPayload = <String, dynamic>{}.obs;
  final settings = <String, Map<String, dynamic>>{}.obs;
  final draftValues = <String, dynamic>{}.obs;
  final dirtyKeys = <String>{}.obs;

  final lastRemarks = <String>[].obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;

  bool get hasData => settings.isNotEmpty;
  int get settingCount => settings.length;
  int get differenceCount => settings.values.where((setting) => _bool(setting['different'])).length;
  int get restartRequiredCount => settings.values.where((setting) => _bool(setting['restart_required'])).length;
  int get dirtyCount => dirtyKeys.length;

  String get rawStatusJson {
    if (statusPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(statusPayload);
  }

  List<String> get groups {
    final groupNames = settings.values.map((setting) => _text(setting['group'], fallback: 'general')).toSet().toList();
    groupNames.sort((a, b) => _groupOrder(a).compareTo(_groupOrder(b)));
    return groupNames;
  }

  List<MapEntry<String, Map<String, dynamic>>> settingsForGroup(String group) {
    final entries = settings.entries.where((entry) => _text(entry.value['group'], fallback: 'general') == group).toList();
    entries.sort((a, b) {
      final orderA = _int(a.value['order']) ?? 999999;
      final orderB = _int(b.value['order']) ?? 999999;
      final byOrder = orderA.compareTo(orderB);
      return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
    });
    return entries;
  }

  int dirtyCountForGroup(String group) => settingsForGroup(group).where((entry) => dirtyKeys.contains(entry.key)).length;

  int differenceCountForGroup(String group) => settingsForGroup(group).where((entry) => _bool(entry.value['different'])).length;

  int sessionSupportedDirtyCountForGroup(String group) => settingsForGroup(group)
      .where((entry) => dirtyKeys.contains(entry.key) && _bool(entry.value['session_apply_supported']))
      .length;

  String groupLabel(String group) {
    switch (group) {
      case 'general':
        return 'Allgemein';
      case 'undocking':
        return 'Ausdocken';
      case 'docking':
        return 'Andocken';
      case 'mowing_strategy':
        return 'Mähstrategie';
      case 'temperature_protection':
        return 'Temperaturschutz';
      case 'mowing_load_control':
        return 'Mäh-Lastregelung';
      case 'gps':
        return 'GPS';
      case 'rain':
        return 'Regen';
      case 'safety':
        return 'Sicherheit';
      default:
        return group;
    }
  }

  IconData groupIcon(String group) {
    switch (group) {
      case 'general':
        return Icons.tune;
      case 'undocking':
        return Icons.exit_to_app;
      case 'docking':
        return Icons.home_work_outlined;
      case 'mowing_strategy':
        return Icons.grass;
      case 'temperature_protection':
        return Icons.device_thermostat;
      case 'mowing_load_control':
        return Icons.speed;
      case 'gps':
        return Icons.gps_fixed;
      case 'rain':
        return Icons.water_drop_outlined;
      case 'safety':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  String labelFor(String key, Map<String, dynamic> setting) => _text(setting['label'], fallback: key);
  String descriptionFor(Map<String, dynamic> setting) => _text(setting['description']);
  String unitFor(Map<String, dynamic> setting) => _text(setting['unit']);
  String typeFor(Map<String, dynamic> setting) {
    final declared = _text(setting['type']).toLowerCase();
    switch (declared) {
      case 'bool':
      case 'boolean':
        return 'bool';
      case 'int':
      case 'integer':
        return 'int';
      case 'double':
      case 'float':
      case 'number':
        return 'double';
      case 'string':
        return 'string';
    }

    // Defensive fallback: The backend is expected to provide `type`, but
    // session writes must still never accidentally turn numeric values into
    // JSON strings if an older/incomplete status payload is received.
    final active = setting['active'];
    final persistent = setting['persistent'];
    if (active is bool || persistent is bool) {
      return 'bool';
    }
    if (active is double || persistent is double) {
      return 'double';
    }
    if (active is int || persistent is int) {
      return 'double';
    }
    if (setting['min'] is num || setting['max'] is num) {
      return 'double';
    }
    return 'string';
  }

  bool isBool(Map<String, dynamic> setting) => typeFor(setting) == 'bool';
  bool isInt(Map<String, dynamic> setting) => typeFor(setting) == 'int';
  bool isDouble(Map<String, dynamic> setting) => typeFor(setting) == 'double';
  bool isNumeric(Map<String, dynamic> setting) => isInt(setting) || isDouble(setting);

  bool draftBool(String key, Map<String, dynamic> setting) => _bool(draftValues[key] ?? _seedValue(setting));

  String draftText(String key, Map<String, dynamic> setting) => _valueText(draftValues[key] ?? _seedValue(setting));

  String activeText(Map<String, dynamic> setting) => _valueText(setting['active']);
  String persistentText(Map<String, dynamic> setting) => _valueText(setting['persistent']);

  String rangeText(Map<String, dynamic> setting) {
    final min = setting['min'];
    final max = setting['max'];
    if (min == null && max == null) {
      return '';
    }
    if (min != null && max != null) {
      return 'Erlaubt: ${_valueText(min)} bis ${_valueText(max)}';
    }
    if (min != null) {
      return 'Mindestens ${_valueText(min)}';
    }
    return 'Maximal ${_valueText(max)}';
  }

  void requestSettings() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Settings-Status wird neu angefordert ...';
    lastTopic.value = 'settings/mower_logic/set/renew/json';
    lastUpdated.value = DateTime.now();
    Get.find<MqttConnection>().requestMowerLogicSettings();
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = 'settings/mower_logic/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final rawSettings = root['settings'];
    if (rawSettings is! Map) {
      setError('Settings-Status enthält kein gültiges settings-Objekt.', topic: topic);
      return;
    }

    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));

    final next = <String, Map<String, dynamic>>{};
    rawSettings.forEach((key, value) {
      if (value is Map) {
        next[key.toString()] = Map<String, dynamic>.from(value);
      }
    });

    settings
      ..clear()
      ..addAll(next);

    for (final entry in settings.entries) {
      if (!dirtyKeys.contains(entry.key)) {
        draftValues[entry.key] = _seedValue(entry.value);
      }
    }
    draftValues.removeWhere((key, value) => !settings.containsKey(key));
    dirtyKeys.removeWhere((key) => !settings.containsKey(key));

    waitingForResponse.value = false;
    lastStatusOk.value ??= true;
    if (lastStatus.value.isEmpty || lastStatus.value.contains('angefordert')) {
      lastStatus.value = 'Settings-Status vom Backend empfangen.';
    }
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void setValidation(Map<String, dynamic> payload, {String topic = 'settings/mower_logic/validation/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final valid = _boolOrNull(root['valid']);
    final scope = _text(root['scope']);
    final remarks = _stringList(root['remarks']);
    final applied = root['applied'];

    lastRemarks.assignAll(remarks);
    lastStatusOk.value = valid;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;

    if (valid == true) {
      if (applied is Map) {
        for (final key in applied.keys) {
          dirtyKeys.remove(key.toString());
        }
      }
      if (scope == 'persistent') {
        lastStatus.value = 'Dauerhafte Settings wurden gespeichert.';
      } else if (scope == 'session') {
        lastStatus.value = 'Settings wurden für die aktuelle Session angewendet.';
      } else {
        lastStatus.value = 'Settings wurden vom Backend bestätigt.';
      }
    } else if (valid == false) {
      lastStatus.value = 'Settings wurden abgelehnt. Bitte Hinweise prüfen.';
    } else {
      lastStatus.value = 'Validierungsantwort empfangen.';
    }
  }

  void setError(String message, {String topic = 'local/error'}) {
    waitingForResponse.value = false;
    lastStatusOk.value = false;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void setInfo(String message, {String topic = 'local/info'}) {
    lastStatusOk.value = null;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void updateDraftText(String key, Map<String, dynamic> setting, String rawValue) {
    final parsed = _parseTextValue(rawValue, setting);
    if (parsed == null && rawValue.trim().isNotEmpty && !isString(setting)) {
      draftValues[key] = rawValue;
    } else {
      draftValues[key] = parsed ?? '';
    }
    _updateDirtyState(key, setting);
  }

  void updateDraftBool(String key, Map<String, dynamic> setting, bool value) {
    draftValues[key] = value;
    _updateDirtyState(key, setting);
  }

  bool isString(Map<String, dynamic> setting) => typeFor(setting) == 'string';

  void resetGroupDrafts(String group) {
    for (final entry in settingsForGroup(group)) {
      draftValues[entry.key] = _seedValue(entry.value);
      dirtyKeys.remove(entry.key);
    }
    setInfo('Entwürfe in „${groupLabel(group)}“ wurden zurückgesetzt.', topic: 'local/reset');
  }

  void applySessionForGroup(String group) {
    final payload = _payloadForGroup(group, sessionOnly: true);
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Session-Änderungen werden gesendet ...';
    lastTopic.value = 'settings/mower_logic/set/session/json';
    lastUpdated.value = DateTime.now();
    Get.find<MqttConnection>().publishMowerLogicSessionSettings(payload);
  }

  void savePersistentForGroup(String group) {
    final payload = _payloadForGroup(group, sessionOnly: false);
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Dauerhafte Einstellungen werden gespeichert ...';
    lastTopic.value = 'settings/mower_logic/set/persistent/json';
    lastUpdated.value = DateTime.now();
    Get.find<MqttConnection>().publishMowerLogicPersistentSettings(payload);
  }

  Map<String, dynamic>? _payloadForGroup(String group, {required bool sessionOnly}) {
    final payload = <String, dynamic>{};
    for (final entry in settingsForGroup(group)) {
      final key = entry.key;
      final setting = entry.value;
      if (!dirtyKeys.contains(key)) {
        continue;
      }
      if (sessionOnly && !_bool(setting['session_apply_supported'])) {
        continue;
      }
      final value = _normalizedDraftValue(key, setting);
      if (value == _invalidValue) {
        setError('Der Wert für „${labelFor(key, setting)}“ ist nicht gültig.', topic: 'local/validation');
        return null;
      }
      payload[key] = value;
    }

    if (payload.isEmpty) {
      if (sessionOnly) {
        setInfo('In „${groupLabel(group)}“ gibt es keine live anwendbaren Änderungen.', topic: 'local/info');
      } else {
        setInfo('In „${groupLabel(group)}“ gibt es keine geänderten Werte.', topic: 'local/info');
      }
      return null;
    }

    return payload;
  }

  dynamic _normalizedDraftValue(String key, Map<String, dynamic> setting) {
    final raw = draftValues[key];
    final type = typeFor(setting);
    dynamic value;
    switch (type) {
      case 'bool':
        value = _boolOrNull(raw);
        if (value == null) return _invalidValue;
        break;
      case 'int':
        value = _int(raw);
        if (value == null) return _invalidValue;
        break;
      case 'double':
        value = _double(raw);
        if (value == null) return _invalidValue;
        break;
      case 'string':
        value = raw?.toString() ?? '';
        break;
      default:
        value = raw;
    }

    final min = _double(setting['min']);
    final max = _double(setting['max']);
    if (value is num) {
      if (min != null && value.toDouble() < min) return _invalidValue;
      if (max != null && value.toDouble() > max) return _invalidValue;
    }
    return value;
  }

  void _updateDirtyState(String key, Map<String, dynamic> setting) {
    final normalized = _normalizedDraftValue(key, setting);
    final seed = _seedValue(setting);
    if (normalized == _invalidValue || !_sameValue(normalized, seed)) {
      dirtyKeys.add(key);
    } else {
      dirtyKeys.remove(key);
    }
  }

  dynamic _seedValue(Map<String, dynamic> setting) {
    if (setting.containsKey('active')) {
      return setting['active'];
    }
    return setting['persistent'];
  }

  dynamic _parseTextValue(String rawValue, Map<String, dynamic> setting) {
    final text = rawValue.trim();
    switch (typeFor(setting)) {
      case 'int':
        return text.isEmpty ? '' : int.tryParse(text);
      case 'double':
        return text.isEmpty ? '' : double.tryParse(text.replaceAll(',', '.'));
      case 'string':
        return rawValue;
      default:
        return rawValue;
    }
  }

  static const Object _invalidValue = Object();

  bool _sameValue(dynamic left, dynamic right) {
    if (left is num && right is num) {
      return left.toDouble() == right.toDouble();
    }
    return left == right;
  }

  int _groupOrder(String group) {
    switch (group) {
      case 'general':
        return 100;
      case 'temperature_protection':
        return 200;
      case 'mowing_load_control':
        return 300;
      case 'mowing_strategy':
        return 400;
      case 'gps':
        return 500;
      case 'rain':
        return 600;
      case 'docking':
        return 700;
      case 'undocking':
        return 800;
      case 'safety':
        return 900;
      default:
        return 999;
    }
  }

  String _valueText(dynamic value) {
    if (value == null) {
      return '-';
    }
    if (value is bool) {
      return value ? 'An' : 'Aus';
    }
    return value.toString();
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  bool _bool(dynamic value) => _boolOrNull(value) ?? false;

  bool? _boolOrNull(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on') return true;
      if (normalized == 'false' || normalized == '0' || normalized == 'no' || normalized == 'off') return false;
    }
    return null;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      final numeric = value.toDouble();
      if (!numeric.isFinite || numeric != numeric.truncateToDouble()) {
        return null;
      }
      return numeric.toInt();
    }
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    return parsed;
  }

  double? _double(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim().replaceAll(',', '.') ?? '');
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
    }
    if (value == null) {
      return <String>[];
    }
    final text = value.toString().trim();
    return text.isEmpty ? <String>[] : <String>[text];
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}
