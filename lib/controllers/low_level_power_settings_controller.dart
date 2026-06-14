import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class LowLevelPowerSettingsController extends GetxController {
  static const List<String> orderedKeys = <String>[
    'battery_critical_voltage',
    'battery_empty_voltage',
    'battery_full_voltage',
    'battery_critical_high_voltage',
    'charge_critical_high_voltage',
    'charge_critical_high_current',
  ];

  static const Map<String, Map<String, String>> fallbackMeta = <String, Map<String, String>>{
    'battery_critical_voltage': <String, String>{
      'label': 'Kritische Batteriespannung',
      'unit': 'V',
      'description': 'Untere Schutzgrenze für die Batteriespannung.',
    },
    'battery_empty_voltage': <String, String>{
      'label': 'Akku leer',
      'unit': 'V',
      'description': 'Spannung, ab der der Akku als leer betrachtet wird.',
    },
    'battery_full_voltage': <String, String>{
      'label': 'Akku voll',
      'unit': 'V',
      'description': 'Spannung, ab der der Akku als voll betrachtet wird.',
    },
    'battery_critical_high_voltage': <String, String>{
      'label': 'Maximale Batteriespannung',
      'unit': 'V',
      'description': 'Obere Schutzgrenze der Batteriespannung.',
    },
    'charge_critical_high_voltage': <String, String>{
      'label': 'Maximale Ladespannung',
      'unit': 'V',
      'description': 'Obere Schutzgrenze der Ladespannung.',
    },
    'charge_critical_high_current': <String, String>{
      'label': 'Maximaler Ladestrom',
      'unit': 'A',
      'description': 'Maximaler Ladestrom vor Schutzabschaltung.',
    },
  };

  final statusPayload = <String, dynamic>{}.obs;
  final settings = <String, Map<String, dynamic>>{}.obs;
  final draftValues = <String, dynamic>{}.obs;
  final groupDraftValues = <String, String>{}.obs;
  final expertDraftValues = <String, bool>{}.obs;
  final dirtyKeys = <String>{}.obs;
  final dirtyGroupKeys = <String>{}.obs;
  final dirtyExpertKeys = <String>{}.obs;
  final editorRevision = 0.obs;

  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final lastRemarks = <String>[].obs;

  Timer? _responseTimeout;
  int _responseWaitGeneration = 0;
  Set<String> _pendingValueKeys = <String>{};
  Set<String> _pendingGroupKeys = <String>{};
  Set<String> _pendingExpertKeys = <String>{};

  bool get hasData => settings.isNotEmpty;
  int get settingCount => settings.length;
  int get differenceCount => settings.entries.where((entry) => isDifferent(entry.key)).length;
  int get restartRequiredCount => settings.values.where((setting) => _bool(setting['restart_required'])).length;
  int get dirtyCount => {...dirtyKeys, ...dirtyGroupKeys, ...dirtyExpertKeys}.length;
  int get sessionDirtyCount => settings.entries.where((entry) => dirtyKeys.contains(entry.key) && sessionApplySupported(entry.key)).length;

  String get rawStatusJson {
    if (statusPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(statusPayload);
  }

  List<String> groupsForMode({required bool expertModeEnabled}) {
    final groupNames = settings.values
        .where((setting) => expertModeEnabled || !_settingIsExpert(setting))
        .map((setting) => _groupSeed(setting))
        .toSet()
        .toList();
    groupNames.sort((a, b) => _groupOrder(a).compareTo(_groupOrder(b)));
    return groupNames;
  }

  List<String> visibleKeys({required bool expertModeEnabled}) => settingsForMode(expertModeEnabled: expertModeEnabled)
      .map((entry) => entry.key)
      .toList(growable: false);

  List<MapEntry<String, Map<String, dynamic>>> settingsForMode({required bool expertModeEnabled}) {
    final entries = settings.entries.where((entry) => expertModeEnabled || !_settingIsExpert(entry.value)).toList();
    entries.sort(_compareSettingsEntries);
    return entries;
  }

  List<String> keysForGroup(String group, {required bool expertModeEnabled}) => settingsForGroup(group, expertModeEnabled: expertModeEnabled)
      .map((entry) => entry.key)
      .toList(growable: false);

  List<MapEntry<String, Map<String, dynamic>>> settingsForGroup(String group, {bool expertModeEnabled = true}) {
    final entries = settings.entries
        .where((entry) => _groupSeed(entry.value) == group)
        .where((entry) => expertModeEnabled || !_settingIsExpert(entry.value))
        .toList();
    entries.sort(_compareSettingsEntries);
    return entries;
  }

  int _compareSettingsEntries(MapEntry<String, Map<String, dynamic>> a, MapEntry<String, Map<String, dynamic>> b) {
    final orderA = _int(a.value['order']) ?? _fallbackKeyOrder(a.key);
    final orderB = _int(b.value['order']) ?? _fallbackKeyOrder(b.key);
    final byOrder = orderA.compareTo(orderB);
    return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
  }

  int _fallbackKeyOrder(String key) {
    final index = orderedKeys.indexOf(key);
    return index < 0 ? 999999 : (index + 1) * 10;
  }

  int dirtyCountForGroup(String group, {required bool expertModeEnabled}) => settingsForGroup(group, expertModeEnabled: expertModeEnabled)
      .where((entry) => dirtyKeys.contains(entry.key) || dirtyGroupKeys.contains(entry.key) || dirtyExpertKeys.contains(entry.key))
      .length;

  int differenceCountForGroup(String group, {required bool expertModeEnabled}) =>
      settingsForGroup(group, expertModeEnabled: expertModeEnabled).where((entry) => isDifferent(entry.key)).length;

  int metadataDirtyCountForGroup(String group, {required bool expertModeEnabled}) => settingsForGroup(group, expertModeEnabled: expertModeEnabled)
      .where((entry) => dirtyGroupKeys.contains(entry.key) || dirtyExpertKeys.contains(entry.key))
      .length;

  int sessionSupportedDirtyCountForGroup(String group, {required bool expertModeEnabled}) => settingsForGroup(group, expertModeEnabled: expertModeEnabled)
      .where((entry) => dirtyKeys.contains(entry.key) && sessionApplySupported(entry.key))
      .length;

  String groupLabel(String group) {
    switch (group) {
      case 'll_board':
        return 'Low-Level Board';
      case 'battery':
        return 'Akku';
      case 'charge':
      case 'charging':
        return 'Laden';
      case 'speed':
      case 'drive':
        return 'Fahrverhalten';
      case 'safety':
        return 'Sicherheit';
      default:
        return group;
    }
  }

  IconData groupIcon(String group) {
    switch (group) {
      case 'battery':
        return Icons.battery_full_outlined;
      case 'charge':
      case 'charging':
        return Icons.ev_station_outlined;
      case 'speed':
      case 'drive':
        return Icons.speed;
      case 'safety':
        return Icons.health_and_safety_outlined;
      case 'll_board':
        return Icons.memory_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  int _groupOrder(String group) {
    switch (group) {
      case 'll_board':
        return 100;
      case 'battery':
        return 200;
      case 'charge':
      case 'charging':
        return 300;
      case 'speed':
      case 'drive':
        return 400;
      case 'safety':
        return 900;
      default:
        return 999;
    }
  }

  void requestStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastRemarks.clear();
    lastStatus.value = 'Low-Level-Board-Status wird neu angefordert ...';
    lastTopic.value = 'settings/ll_board/set/renew/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine Low-Level-Board-Antwort empfangen. Bitte MQTT-Topic settings/ll_board/json prüfen.');
    Get.find<MqttConnection>().requestLowLevelPowerSettings();
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = 'settings/ll_board/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final rawSettings = root['settings'];

    final next = <String, Map<String, dynamic>>{};
    if (rawSettings is Map) {
      rawSettings.forEach((key, value) {
        final settingKey = key.toString();
        if (value is Map) {
          final normalized = Map<String, dynamic>.from(value);
          normalized.putIfAbsent('group', () => 'll_board');
          normalized.putIfAbsent('expert', () => false);
          next[settingKey] = normalized;
        }
      });
    } else {
      // Limited legacy compatibility for old ll_power/json payloads.
      for (final key in orderedKeys) {
        final value = root[key];
        if (value != null) {
          next[key] = <String, dynamic>{
            'value': value,
            'active': value,
            'persistent': value,
            'group': 'll_board',
            'expert': false,
            'type': 'number',
            ...?fallbackMeta[key],
          };
        }
      }
    }

    if (next.isEmpty) {
      setError('Low-Level-Board-Status enthält kein gültiges settings-Objekt.', topic: topic);
      return;
    }

    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));
    settings
      ..clear()
      ..addAll(next);

    for (final entry in settings.entries) {
      if (!dirtyKeys.contains(entry.key)) {
        draftValues[entry.key] = _seedValue(entry.value);
      }
      if (!dirtyGroupKeys.contains(entry.key)) {
        groupDraftValues[entry.key] = _groupSeed(entry.value);
      }
      if (!dirtyExpertKeys.contains(entry.key)) {
        expertDraftValues[entry.key] = _expertSeed(entry.value);
      }
    }
    draftValues.removeWhere((key, value) => !settings.containsKey(key));
    groupDraftValues.removeWhere((key, value) => !settings.containsKey(key));
    expertDraftValues.removeWhere((key, value) => !settings.containsKey(key));
    dirtyKeys.removeWhere((key) => !settings.containsKey(key));
    dirtyGroupKeys.removeWhere((key) => !settings.containsKey(key));
    dirtyExpertKeys.removeWhere((key) => !settings.containsKey(key));
    editorRevision.value++;

    _clearResponseTimeout();
    waitingForResponse.value = false;
    lastStatusOk.value ??= true;
    if (lastStatus.value.isEmpty || lastStatus.value.contains('angefordert')) {
      lastStatus.value = 'Low-Level-Board-Status vom Backend empfangen.';
    }
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  bool importBackupJson(String jsonText, {String? filename}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (e) {
      setError('JSON-Datei ist ungültig: $e', topic: 'local/upload');
      return false;
    }
    if (decoded is! Map) {
      setError('JSON-Datei muss ein Objekt enthalten.', topic: 'local/upload');
      return false;
    }

    final root = decoded['d'] is Map ? Map<String, dynamic>.from(decoded['d'] as Map) : Map<String, dynamic>.from(decoded);
    final namespace = root['namespace']?.toString();
    if (namespace != null && namespace.isNotEmpty && namespace != 'll_board') {
      setError('JSON-Datei gehört zu „$namespace“ und nicht zu „ll_board“.', topic: 'local/upload');
      return false;
    }
    final rawSettings = root['settings'];
    if (rawSettings is! Map) {
      setError('JSON-Datei enthält kein gültiges settings-Objekt.', topic: 'local/upload');
      return false;
    }

    final next = <String, Map<String, dynamic>>{};
    rawSettings.forEach((key, value) {
      final settingKey = key.toString();
      if (settingKey.isEmpty || value is! Map) {
        return;
      }
      final normalized = Map<String, dynamic>.from(value);
      normalized.putIfAbsent('group', () => 'll_board');
      normalized.putIfAbsent('expert', () => false);
      next[settingKey] = normalized;
    });
    if (next.isEmpty) {
      setError('JSON-Datei enthält keine gültigen Low-Level-Board-Einstellungen.', topic: 'local/upload');
      return false;
    }

    _clearResponseTimeout();
    waitingForResponse.value = false;

    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));
    settings
      ..clear()
      ..addAll(next);

    draftValues.clear();
    groupDraftValues.clear();
    expertDraftValues.clear();
    dirtyKeys.clear();
    dirtyGroupKeys.clear();
    dirtyExpertKeys.clear();

    for (final entry in settings.entries) {
      draftValues[entry.key] = _seedValue(entry.value);
      groupDraftValues[entry.key] = _groupSeed(entry.value);
      expertDraftValues[entry.key] = _expertSeed(entry.value);
      dirtyKeys.add(entry.key);
      dirtyGroupKeys.add(entry.key);
      dirtyExpertKeys.add(entry.key);
    }

    editorRevision.value++;
    lastRemarks.assignAll(const <String>[
      'Die Sicherung wurde lokal als Entwurf geladen.',
      'Zum Wiederherstellen bitte die betroffenen Gruppen dauerhaft speichern.',
    ]);
    lastStatusOk.value = null;
    lastStatus.value = filename == null || filename.isEmpty
        ? 'LL-Board-JSON wurde lokal geladen.'
        : 'LL-Board-JSON „$filename“ wurde lokal geladen.';
    lastTopic.value = 'local/upload';
    lastUpdated.value = DateTime.now();
    return true;
  }

  void setValidation(Map<String, dynamic> payload, {String topic = 'settings/ll_board/validation/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final valid = _boolOrNull(root['valid']);
    final mode = _text(root['mode'] ?? root['scope']);
    final accepted = _acceptedFields(root['accepted'] ?? root['applied']);
    final remarks = <String>[
      ..._stringList(root['remarks']),
      ..._rejectedRemarks(root['rejected']),
    ];

    lastRemarks.assignAll(remarks);
    lastStatusOk.value = valid;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _clearResponseTimeout();
    waitingForResponse.value = false;

    if (accepted.isNotEmpty) {
      accepted.forEach(_clearAcceptedFields);
    } else if (valid == true) {
      for (final key in _pendingValueKeys) {
        dirtyKeys.remove(key);
      }
      for (final key in _pendingGroupKeys) {
        dirtyGroupKeys.remove(key);
      }
      for (final key in _pendingExpertKeys) {
        dirtyExpertKeys.remove(key);
      }
    }
    if (valid == true || valid == false) {
      _pendingValueKeys = <String>{};
      _pendingGroupKeys = <String>{};
      _pendingExpertKeys = <String>{};
    }

    if (valid == true) {
      if (mode == 'persistent') {
        lastStatus.value = 'Low-Level-Board-Werte und Metadaten wurden dauerhaft gespeichert.';
      } else if (mode == 'session') {
        lastStatus.value = 'Low-Level-Board-Werte wurden für die aktuelle Session angewendet.';
      } else {
        lastStatus.value = 'Low-Level-Board-Änderung wurde bestätigt.';
      }
    } else if (valid == false) {
      lastStatus.value = 'Low-Level-Board-Änderung wurde teilweise oder vollständig abgelehnt.';
    } else {
      lastStatus.value = 'Low-Level-Board-Validierungsantwort empfangen.';
    }
  }

  void setError(String message, {String topic = 'local/error'}) {
    _clearResponseTimeout();
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

  String labelFor(String key) => _text(settings[key]?['label'], fallback: fallbackMeta[key]?['label'] ?? key);
  String unitFor(String key) => _text(settings[key]?['unit'], fallback: fallbackMeta[key]?['unit'] ?? '');
  String descriptionFor(String key) => _text(settings[key]?['description'], fallback: fallbackMeta[key]?['description'] ?? '');
  String activeText(String key) => _valueText(_seedValue(settings[key]));
  String draftText(String key) => _valueText(draftValues[key] ?? _seedValue(settings[key]));
  String persistentText(String key) => _valueText(settings[key]?['persistent']);
  bool hasPersistentValue(String key) => settings[key]?.containsKey('persistent') == true;
  String groupOriginalText(String key) => _groupSeed(settings[key]);
  String groupDraftText(String key) => groupDraftValues[key] ?? groupOriginalText(key);
  bool expertOriginalBool(String key) => _expertSeed(settings[key]);
  bool expertDraftBool(String key) => expertDraftValues[key] ?? expertOriginalBool(key);

  String typeForKey(String key) => typeFor(settings[key]);
  bool isBoolKey(String key) => typeForKey(key) == 'bool';
  bool isIntKey(String key) => typeForKey(key) == 'int';
  bool isDoubleKey(String key) => typeForKey(key) == 'double';
  bool isNumericKey(String key) => isIntKey(key) || isDoubleKey(key);
  bool isStringKey(String key) => typeForKey(key) == 'string';

  bool draftBool(String key) => _bool(draftValues[key] ?? _seedValue(settings[key]));

  String rangeText(String key) {
    final setting = settings[key];
    final min = setting?['min'];
    final max = setting?['max'];
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

  bool isDifferent(String key) {
    final setting = settings[key];
    if (setting == null) {
      return false;
    }
    if (_bool(setting['different'])) {
      return true;
    }
    if (!setting.containsKey('persistent')) {
      return false;
    }
    return !_sameValue(_normalizedSettingValue(_seedValue(setting), setting), _normalizedSettingValue(setting['persistent'], setting));
  }

  bool sessionApplySupported(String key) {
    final raw = settings[key]?['session_apply_supported'];
    return raw == null ? true : _bool(raw);
  }

  bool restartRequired(String key) => _bool(settings[key]?['restart_required']);

  String typeFor(Map<String, dynamic>? setting) {
    if (setting == null) {
      return 'double';
    }
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
        return _inferredScalarType(setting);
    }

    final active = setting['active'];
    final persistent = setting['persistent'];
    if (active is bool || persistent is bool) {
      return 'bool';
    }
    if (active is double || persistent is double) {
      return 'double';
    }
    if (active is int || persistent is int) {
      return 'int';
    }

    final activeInt = _int(active);
    final persistentInt = _int(persistent);
    final minInt = _int(setting['min']);
    final maxInt = _int(setting['max']);
    if ((active != null && activeInt != null) ||
        (persistent != null && persistentInt != null) ||
        ((setting['min'] != null || setting['max'] != null) && minInt != null && maxInt != null)) {
      return 'int';
    }

    final activeDouble = _double(active);
    final persistentDouble = _double(persistent);
    if ((active != null && activeDouble != null) ||
        (persistent != null && persistentDouble != null) ||
        setting['min'] is num || setting['max'] is num) {
      return 'double';
    }
    return _inferredScalarType(setting);
  }

  String _inferredScalarType(Map<String, dynamic> setting) {
    final evidence = <dynamic>[
      setting['value'],
      setting['active'],
      setting['persistent'],
      setting['min'],
      setting['max'],
    ].where((value) => value != null).toList();

    if (evidence.any(_isExplicitBoolEvidence)) {
      return 'bool';
    }

    var hasNumericEvidence = false;
    var needsDouble = false;
    for (final value in evidence) {
      final parsedDouble = _double(value);
      if (parsedDouble == null) {
        continue;
      }
      hasNumericEvidence = true;
      if (_int(value) == null) {
        needsDouble = true;
      }
    }

    if (hasNumericEvidence) {
      return needsDouble ? 'double' : 'int';
    }
    return 'string';
  }

  bool _isExplicitBoolEvidence(dynamic value) {
    if (value is bool) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == 'false' || normalized == 'yes' || normalized == 'no' || normalized == 'on' || normalized == 'off';
    }
    return false;
  }

  void updateDraftText(String key, String rawValue) {
    final setting = settings[key];
    final parsed = _parseTextValue(rawValue, setting);
    if (parsed == null && rawValue.trim().isNotEmpty && typeFor(setting) != 'string') {
      draftValues[key] = rawValue;
    } else {
      draftValues[key] = parsed ?? '';
    }
    _updateDirtyState(key);
  }

  void updateDraftBool(String key, bool value) {
    draftValues[key] = value;
    _updateDirtyState(key);
  }

  void updateDraftGroup(String key, String rawValue) {
    groupDraftValues[key] = rawValue;
    _updateGroupDirtyState(key);
  }

  void updateDraftExpert(String key, bool value) {
    expertDraftValues[key] = value;
    _updateExpertDirtyState(key);
  }

  void resetDrafts() {
    for (final entry in settings.entries) {
      draftValues[entry.key] = _seedValue(entry.value);
      groupDraftValues[entry.key] = _groupSeed(entry.value);
      expertDraftValues[entry.key] = _expertSeed(entry.value);
      dirtyKeys.remove(entry.key);
      dirtyGroupKeys.remove(entry.key);
      dirtyExpertKeys.remove(entry.key);
    }
    editorRevision.value++;
    setInfo('Low-Level-Board-Entwürfe wurden zurückgesetzt.', topic: 'local/reset');
  }

  void resetGroupDrafts(String group, {required bool expertModeEnabled}) {
    for (final entry in settingsForGroup(group, expertModeEnabled: expertModeEnabled)) {
      draftValues[entry.key] = _seedValue(entry.value);
      groupDraftValues[entry.key] = _groupSeed(entry.value);
      expertDraftValues[entry.key] = _expertSeed(entry.value);
      dirtyKeys.remove(entry.key);
      dirtyGroupKeys.remove(entry.key);
      dirtyExpertKeys.remove(entry.key);
    }
    editorRevision.value++;
    setInfo('Entwürfe in „${groupLabel(group)}“ wurden zurückgesetzt.', topic: 'local/reset');
  }

  void applySessionChanges() {
    final payload = _payloadFromDrafts(sessionOnly: true);
    if (payload == null) return;
    _sendPayload(payload, sessionOnly: true, group: null);
  }

  void savePersistentChanges() {
    final payload = _payloadFromDrafts(sessionOnly: false);
    if (payload == null) return;
    _sendPayload(payload, sessionOnly: false, group: null);
  }

  void applySessionForGroup(String group, {required bool expertModeEnabled}) {
    final keys = keysForGroup(group, expertModeEnabled: expertModeEnabled);
    final payload = _payloadFromDrafts(sessionOnly: true, onlyKeys: keys, groupLabel: groupLabel(group));
    if (payload == null) return;
    _sendPayload(payload, sessionOnly: true, group: group);
  }

  void savePersistentForGroup(String group, {required bool expertModeEnabled}) {
    final keys = keysForGroup(group, expertModeEnabled: expertModeEnabled);
    final payload = _payloadFromDrafts(sessionOnly: false, onlyKeys: keys, groupLabel: groupLabel(group));
    if (payload == null) return;
    _sendPayload(payload, sessionOnly: false, group: group);
  }

  void _sendPayload(Map<String, dynamic> payload, {required bool sessionOnly, String? group}) {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    if (sessionOnly) {
      lastStatus.value = group == null
          ? 'Low-Level-Board-Werte werden für die aktuelle Session gesendet ...'
          : 'Low-Level-Board-Werte in „${groupLabel(group)}“ werden für die aktuelle Session gesendet ...';
      lastTopic.value = 'settings/ll_board/set/session/json';
      _armResponseTimeout('Keine Backend-Bestätigung für die Low-Level-Board-Sessionänderung empfangen.');
      _rememberPendingAction(payload, sessionOnly: true);
      Get.find<MqttConnection>().publishLowLevelPowerSessionSettings(payload);
    } else {
      lastStatus.value = group == null
          ? 'Low-Level-Board-Werte und Metadaten werden dauerhaft gespeichert ...'
          : 'Low-Level-Board-Werte und Metadaten in „${groupLabel(group)}“ werden dauerhaft gespeichert ...';
      lastTopic.value = 'settings/ll_board/set/persistent/json';
      _armResponseTimeout('Keine Backend-Bestätigung für das dauerhafte Speichern der Low-Level-Board-Werte empfangen.');
      _rememberPendingAction(payload, sessionOnly: false);
      Get.find<MqttConnection>().publishLowLevelPowerPersistentSettings(payload);
    }
    lastUpdated.value = DateTime.now();
  }

  Map<String, dynamic>? _payloadFromDrafts({required bool sessionOnly, Iterable<String>? onlyKeys, String? groupLabel}) {
    final payload = <String, dynamic>{};
    final keys = onlyKeys ?? settings.keys;
    for (final key in keys) {
      final setting = settings[key];
      if (setting == null) continue;
      final valueDirty = dirtyKeys.contains(key) && (!sessionOnly || sessionApplySupported(key));
      final groupDirty = dirtyGroupKeys.contains(key);
      final expertDirty = dirtyExpertKeys.contains(key);
      if (!valueDirty && (!groupDirty || sessionOnly) && (!expertDirty || sessionOnly)) {
        continue;
      }

      final fields = <String, dynamic>{};
      if (valueDirty) {
        final value = _normalizedDraftValue(key);
        if (value == _invalidValue) {
          setError('Der Wert für „${labelFor(key)}“ ist nicht gültig.', topic: 'local/validation');
          return null;
        }
        fields['value'] = value;
      }
      if (groupDirty && !sessionOnly) {
        final groupValue = _normalizedGroupDraftValue(key);
        if (groupValue == null) {
          setError('Die Gruppe für „${labelFor(key)}“ darf nicht leer sein, maximal 80 Zeichen haben und keine Steuerzeichen enthalten.', topic: 'local/validation');
          return null;
        }
        fields['group'] = groupValue;
      }
      if (expertDirty && !sessionOnly) {
        fields['expert'] = expertDraftBool(key);
      }
      if (fields.isNotEmpty) {
        payload[key] = fields;
      }
    }

    if (payload.isEmpty) {
      if (sessionOnly) {
        setInfo(groupLabel == null
            ? 'Es gibt keine live anwendbaren Low-Level-Board-Werte. Metadaten werden nur dauerhaft gespeichert.'
            : 'In „$groupLabel“ gibt es keine live anwendbaren Änderungen.', topic: 'local/info');
      } else {
        setInfo(groupLabel == null
            ? 'Es gibt keine geänderten Low-Level-Board-Werte oder Metadaten.'
            : 'In „$groupLabel“ gibt es keine geänderten Werte.', topic: 'local/info');
      }
      return null;
    }
    return payload;
  }

  dynamic _normalizedDraftValue(String key) => _normalizedSettingValue(draftValues[key], settings[key]);

  dynamic _normalizedSettingValue(dynamic raw, Map<String, dynamic>? setting) {
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
        if (raw is! String) return _invalidValue;
        value = raw;
        break;
      default:
        value = raw;
    }

    final min = _double(setting?['min']);
    final max = _double(setting?['max']);
    if (value is num) {
      if (min != null && value.toDouble() < min) return _invalidValue;
      if (max != null && value.toDouble() > max) return _invalidValue;
    }
    return value;
  }

  void _updateDirtyState(String key) {
    final setting = settings[key];
    final normalized = _normalizedDraftValue(key);
    final seed = _seedValue(setting);
    if (normalized == _invalidValue || !_sameValue(normalized, _normalizedSettingValue(seed, setting))) {
      dirtyKeys.add(key);
    } else {
      dirtyKeys.remove(key);
    }
  }

  void _updateGroupDirtyState(String key) {
    final normalized = _normalizedGroupDraftValue(key);
    final seed = groupOriginalText(key);
    if (normalized == null || normalized != seed) {
      dirtyGroupKeys.add(key);
    } else {
      dirtyGroupKeys.remove(key);
    }
  }

  void _updateExpertDirtyState(String key) {
    final normalized = expertDraftBool(key);
    final seed = expertOriginalBool(key);
    if (normalized != seed) {
      dirtyExpertKeys.add(key);
    } else {
      dirtyExpertKeys.remove(key);
    }
  }

  dynamic _parseTextValue(String rawValue, Map<String, dynamic>? setting) {
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

  dynamic _seedValue(Map<String, dynamic>? setting) {
    if (setting == null) return null;
    if (setting.containsKey('value')) return setting['value'];
    if (setting.containsKey('active')) return setting['active'];
    return setting['persistent'];
  }

  String _groupSeed(Map<String, dynamic>? setting) => _text(setting?['group'], fallback: 'll_board');
  bool _expertSeed(Map<String, dynamic>? setting) => setting?['expert'] is bool ? setting!['expert'] as bool : false;
  bool _settingIsExpert(Map<String, dynamic> setting) => _expertSeed(setting);

  String? _normalizedGroupDraftValue(String key) {
    final value = (groupDraftValues[key] ?? groupOriginalText(key)).trim();
    if (value.isEmpty || value.length > 80 || _containsControlCharacters(value)) {
      return null;
    }
    return value;
  }

  bool _containsControlCharacters(String value) => value.runes.any((char) => char < 0x20 || char == 0x7f);

  void _rememberPendingAction(Map<String, dynamic> payload, {required bool sessionOnly}) {
    final valueKeys = <String>{};
    final groupKeys = <String>{};
    final expertKeys = <String>{};
    payload.forEach((key, value) {
      final settingKey = key.toString();
      if (value is Map) {
        if (value.containsKey('value')) valueKeys.add(settingKey);
        if (!sessionOnly && value.containsKey('group')) groupKeys.add(settingKey);
        if (!sessionOnly && value.containsKey('expert')) expertKeys.add(settingKey);
      } else {
        valueKeys.add(settingKey);
      }
    });
    _pendingValueKeys = valueKeys;
    _pendingGroupKeys = groupKeys;
    _pendingExpertKeys = expertKeys;
  }

  Map<String, Set<String>> _acceptedFields(dynamic raw) {
    final result = <String, Set<String>>{};
    void add(String key, Iterable<String> fields) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) return;
      result.putIfAbsent(normalizedKey, () => <String>{}).addAll(fields);
    }

    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map && value['fields'] is List) {
          add(key.toString(), (value['fields'] as List).map((field) => field.toString()));
        } else if (value is List) {
          add(key.toString(), value.map((field) => field.toString()));
        } else {
          add(key.toString(), const ['value', 'group', 'expert']);
        }
      });
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final key = item['key']?.toString() ?? '';
          final fields = item['fields'] is List
              ? (item['fields'] as List).map((field) => field.toString())
              : const ['value', 'group', 'expert'];
          add(key, fields);
        } else {
          add(item.toString(), const ['value', 'group', 'expert']);
        }
      }
    }
    return result;
  }

  void _clearAcceptedFields(String key, Set<String> fields) {
    if (fields.contains('value')) dirtyKeys.remove(key);
    if (fields.contains('group')) dirtyGroupKeys.remove(key);
    if (fields.contains('expert')) dirtyExpertKeys.remove(key);
  }

  void _armResponseTimeout(String timeoutMessage) {
    _responseTimeout?.cancel();
    final generation = ++_responseWaitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _responseWaitGeneration || !waitingForResponse.value) return;
      waitingForResponse.value = false;
      lastStatusOk.value = null;
      lastStatus.value = timeoutMessage;
      lastUpdated.value = DateTime.now();
    });
  }

  void _clearResponseTimeout() {
    _responseWaitGeneration++;
    _responseTimeout?.cancel();
    _responseTimeout = null;
  }

  @override
  void onClose() {
    _clearResponseTimeout();
    super.onClose();
  }

  static const Object _invalidValue = Object();

  bool _sameValue(dynamic left, dynamic right) {
    if (left is num && right is num) {
      return left.toDouble() == right.toDouble();
    }
    return left == right;
  }

  String _valueText(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'An' : 'Aus';
    if (value is double) {
      final text = value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      return text.isEmpty ? '0' : text;
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
      if (!numeric.isFinite || numeric != numeric.truncateToDouble()) return null;
      return numeric.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }

  double? _double(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString().trim().replaceAll(',', '.') ?? '');
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
    if (raw == null) return const <String>[];
    final text = raw.toString().trim();
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  List<String> _rejectedRemarks(dynamic raw) {
    if (raw is Map) return raw.entries.map((entry) => '${entry.key}: ${entry.value}').toList();
    if (raw is! List) return const <String>[];
    final remarks = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final key = item['key']?.toString() ?? 'unbekannt';
        final field = item['field']?.toString();
        final reason = item['reason']?.toString() ?? 'abgelehnt';
        remarks.add(field == null || field.isEmpty ? '$key: $reason' : '$key / $field: $reason');
      } else {
        remarks.add(item.toString());
      }
    }
    return remarks;
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}
