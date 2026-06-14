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
  final activeValues = <String, double>{}.obs;
  final draftTexts = <String, String>{}.obs;
  final groupDraftTexts = <String, String>{}.obs;
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

  bool get hasData => activeValues.isNotEmpty;
  int get settingCount => activeValues.length;
  int get differenceCount => orderedKeys.where((key) => activeValues.containsKey(key) && isDifferent(key)).length;
  int get restartRequiredCount => orderedKeys.where((key) => _boolOrFalse(settings[key]?['restart_required'])).length;
  int get dirtyCount => {...dirtyKeys, ...dirtyGroupKeys, ...dirtyExpertKeys}.length;
  int get sessionDirtyCount => dirtyKeys.length;

  List<String> visibleKeys({required bool expertModeEnabled}) => orderedKeys
      .where((key) => activeValues.containsKey(key))
      .where((key) => expertModeEnabled || !expertOriginalBool(key))
      .toList(growable: false);


  List<String> groupsForMode({required bool expertModeEnabled}) {
    final groups = visibleKeys(expertModeEnabled: expertModeEnabled)
        .map(groupOriginalText)
        .toSet()
        .toList(growable: false);
    groups.sort((a, b) => _groupOrder(a).compareTo(_groupOrder(b)));
    return groups;
  }

  List<String> keysForGroup(String group, {required bool expertModeEnabled}) => visibleKeys(expertModeEnabled: expertModeEnabled)
      .where((key) => groupOriginalText(key) == group)
      .toList(growable: false);

  int dirtyCountForGroup(String group, {required bool expertModeEnabled}) => keysForGroup(group, expertModeEnabled: expertModeEnabled)
      .where((key) => dirtyKeys.contains(key) || dirtyGroupKeys.contains(key) || dirtyExpertKeys.contains(key))
      .length;

  int differenceCountForGroup(String group, {required bool expertModeEnabled}) =>
      keysForGroup(group, expertModeEnabled: expertModeEnabled).where(isDifferent).length;

  int metadataDirtyCountForGroup(String group, {required bool expertModeEnabled}) => keysForGroup(group, expertModeEnabled: expertModeEnabled)
      .where((key) => dirtyGroupKeys.contains(key) || dirtyExpertKeys.contains(key))
      .length;

  int sessionSupportedDirtyCountForGroup(String group, {required bool expertModeEnabled}) => keysForGroup(group, expertModeEnabled: expertModeEnabled)
      .where((key) => dirtyKeys.contains(key) && sessionApplySupported(key))
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
      case 'safety':
        return Icons.health_and_safety_outlined;
      case 'll_board':
      default:
        return Icons.battery_charging_full_outlined;
    }
  }

  int _groupOrder(String group) {
    switch (group) {
      case 'll_board':
        return 0;
      case 'battery':
        return 10;
      case 'charge':
      case 'charging':
        return 20;
      case 'safety':
        return 30;
      default:
        return 1000 + group.hashCode.abs() % 100000;
    }
  }

  String get rawStatusJson {
    if (statusPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(statusPayload);
  }

  void requestStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastRemarks.clear();
    lastStatus.value = 'Low-Level-Board-Status wird neu angefordert ...';
    lastTopic.value = 'settings/ll_board/set/renew/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine Low-Level-Board-Antwort empfangen. Bitte MQTT-Topic settings/ll_board/json prüfen.',
    );
    Get.find<MqttConnection>().requestLowLevelPowerSettings();
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = 'settings/ll_board/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final rawSettings = root['settings'];
    final nextSettings = <String, Map<String, dynamic>>{};
    final parsed = <String, double>{};

    if (rawSettings is Map) {
      for (final key in orderedKeys) {
        final setting = rawSettings[key];
        if (setting is Map) {
          final normalized = Map<String, dynamic>.from(setting);
          nextSettings[key] = normalized;
          final active = _double(normalized['value'] ?? normalized['active'] ?? normalized['persistent'] ?? normalized['default']);
          if (active != null) {
            parsed[key] = active;
          }
        }
      }
    } else {
      // Limited legacy compatibility for old ll_power/json payloads.
      for (final key in orderedKeys) {
        final value = _double(root[key]);
        if (value != null) {
          parsed[key] = value;
          nextSettings[key] = <String, dynamic>{'value': value, 'active': value, 'group': 'll_board', 'expert': false};
        }
      }
    }

    if (parsed.isEmpty) {
      setError('Low-Level-Board-Status enthält keine unterstützten Zahlenwerte.', topic: topic);
      return;
    }

    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));
    settings
      ..clear()
      ..addAll(nextSettings);
    activeValues
      ..clear()
      ..addAll(parsed);

    for (final key in orderedKeys) {
      final active = activeValues[key];
      if (active == null) {
        continue;
      }
      if (dirtyKeys.contains(key)) {
        final draft = _double(draftTexts[key]);
        if (draft != null && draft == active) {
          dirtyKeys.remove(key);
          draftTexts[key] = _displayNumber(active);
        }
      } else {
        draftTexts[key] = _displayNumber(active);
      }
      if (!dirtyGroupKeys.contains(key)) {
        groupDraftTexts[key] = groupOriginalText(key);
      }
      if (!dirtyExpertKeys.contains(key)) {
        expertDraftValues[key] = expertOriginalBool(key);
      }
    }
    draftTexts.removeWhere((key, value) => !orderedKeys.contains(key));
    groupDraftTexts.removeWhere((key, value) => !orderedKeys.contains(key));
    expertDraftValues.removeWhere((key, value) => !orderedKeys.contains(key));
    dirtyKeys.removeWhere((key) => !orderedKeys.contains(key));
    dirtyGroupKeys.removeWhere((key) => !orderedKeys.contains(key));
    dirtyExpertKeys.removeWhere((key) => !orderedKeys.contains(key));
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

  void setValidation(Map<String, dynamic> payload, {String topic = 'settings/ll_board/validation/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final valid = _boolOrNull(root['valid']);
    final mode = root['mode']?.toString() ?? root['scope']?.toString() ?? '';
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

  String labelFor(String key) => settings[key]?['label']?.toString() ?? fallbackMeta[key]?['label'] ?? key;
  String unitFor(String key) => settings[key]?['unit']?.toString() ?? fallbackMeta[key]?['unit'] ?? '';
  String descriptionFor(String key) => settings[key]?['description']?.toString() ?? fallbackMeta[key]?['description'] ?? '';
  String activeText(String key) => activeValues.containsKey(key) ? _displayNumber(activeValues[key]!) : '-';
  String draftText(String key) => draftTexts[key] ?? activeText(key);
  String groupOriginalText(String key) => settings[key]?['group']?.toString().trim().isNotEmpty == true
      ? settings[key]!['group'].toString().trim()
      : 'll_board';
  String groupDraftText(String key) => groupDraftTexts[key] ?? groupOriginalText(key);
  bool expertOriginalBool(String key) => settings[key]?['expert'] is bool ? settings[key]!['expert'] as bool : false;
  bool expertDraftBool(String key) => expertDraftValues[key] ?? expertOriginalBool(key);
  String rangeText(String key) {
    final setting = settings[key];
    final min = setting?['min'];
    final max = setting?['max'];
    if (min == null && max == null) {
      return '';
    }
    if (min != null && max != null) {
      return 'Erlaubt: ${_displayAny(min)} bis ${_displayAny(max)}';
    }
    if (min != null) {
      return 'Mindestens ${_displayAny(min)}';
    }
    return 'Maximal ${_displayAny(max)}';
  }


  String persistentText(String key) {
    final persistent = _double(settings[key]?['persistent']);
    return persistent == null ? '-' : _displayNumber(persistent);
  }

  bool hasPersistentValue(String key) => _double(settings[key]?['persistent']) != null;

  bool isDifferent(String key) {
    if (_boolOrFalse(settings[key]?['different'])) {
      return true;
    }
    final active = activeValues[key];
    final persistent = _double(settings[key]?['persistent']);
    return active != null && persistent != null && active != persistent;
  }

  bool sessionApplySupported(String key) {
    final raw = settings[key]?['session_apply_supported'];
    return raw == null ? true : _boolOrFalse(raw);
  }

  bool restartRequired(String key) => _boolOrFalse(settings[key]?['restart_required']);

  void updateDraftText(String key, String rawValue) {
    draftTexts[key] = rawValue;
    final parsed = _double(rawValue);
    final active = activeValues[key];
    if (parsed == null || active == null || parsed != active) {
      dirtyKeys.add(key);
    } else {
      dirtyKeys.remove(key);
    }
  }

  void updateDraftGroup(String key, String rawValue) {
    groupDraftTexts[key] = rawValue;
    final normalized = _normalizedGroupDraftValue(key);
    final original = groupOriginalText(key);
    if (normalized == null || normalized != original) {
      dirtyGroupKeys.add(key);
    } else {
      dirtyGroupKeys.remove(key);
    }
  }

  void updateDraftExpert(String key, bool value) {
    expertDraftValues[key] = value;
    if (value != expertOriginalBool(key)) {
      dirtyExpertKeys.add(key);
    } else {
      dirtyExpertKeys.remove(key);
    }
  }

  void resetDrafts() {
    for (final key in orderedKeys) {
      final active = activeValues[key];
      if (active != null) {
        draftTexts[key] = _displayNumber(active);
      }
      groupDraftTexts[key] = groupOriginalText(key);
      expertDraftValues[key] = expertOriginalBool(key);
      dirtyKeys.remove(key);
      dirtyGroupKeys.remove(key);
      dirtyExpertKeys.remove(key);
    }
    editorRevision.value++;
    setInfo('Low-Level-Board-Entwürfe wurden zurückgesetzt.', topic: 'local/reset');
  }

  Map<String, dynamic>? _payloadFromDrafts({required bool sessionOnly, Iterable<String>? onlyKeys}) {
    final payload = <String, dynamic>{};
    final keys = onlyKeys ?? orderedKeys;
    for (final key in keys) {
      final valueDirty = dirtyKeys.contains(key) && (!sessionOnly || sessionApplySupported(key));
      final groupDirty = dirtyGroupKeys.contains(key);
      final expertDirty = dirtyExpertKeys.contains(key);
      if (!valueDirty && (!groupDirty || sessionOnly) && (!expertDirty || sessionOnly)) {
        continue;
      }

      final fields = <String, dynamic>{};

      if (valueDirty) {
        final parsed = _double(draftTexts[key]);
        if (parsed == null) {
          setError('Der Wert für „${labelFor(key)}“ ist keine gültige JSON-Zahl.', topic: 'local/validation');
          return null;
        }
        final min = _double(settings[key]?['min']);
        final max = _double(settings[key]?['max']);
        if ((min != null && parsed < min) || (max != null && parsed > max)) {
          setError('Der Wert für „${labelFor(key)}“ liegt außerhalb des erlaubten Bereichs.', topic: 'local/validation');
          return null;
        }
        fields['value'] = parsed;
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
      setInfo(sessionOnly
          ? 'Es gibt keine live anwendbaren Low-Level-Board-Werte. Metadaten werden nur dauerhaft gespeichert.'
          : 'Es gibt keine geänderten Low-Level-Board-Werte oder Metadaten.', topic: 'local/info');
      return null;
    }
    return payload;
  }

  void applySessionChanges() {
    final payload = _payloadFromDrafts(sessionOnly: true);
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Board-Werte werden für die aktuelle Session gesendet ...';
    lastTopic.value = 'settings/ll_board/set/session/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine Backend-Bestätigung für die Low-Level-Board-Sessionänderung empfangen.',
    );
    _rememberPendingAction(payload, sessionOnly: true);
    Get.find<MqttConnection>().publishLowLevelPowerSessionSettings(payload);
  }

  void savePersistentChanges() {
    final payload = _payloadFromDrafts(sessionOnly: false);
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Board-Werte und Metadaten werden dauerhaft gespeichert ...';
    lastTopic.value = 'settings/ll_board/set/persistent/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine Backend-Bestätigung für das dauerhafte Speichern der Low-Level-Board-Werte empfangen.',
    );
    _rememberPendingAction(payload, sessionOnly: false);
    Get.find<MqttConnection>().publishLowLevelPowerPersistentSettings(payload);
  }

  void resetGroupDrafts(String group, {required bool expertModeEnabled}) {
    for (final key in keysForGroup(group, expertModeEnabled: expertModeEnabled)) {
      final active = activeValues[key];
      if (active != null) {
        draftTexts[key] = _displayNumber(active);
      }
      groupDraftTexts[key] = groupOriginalText(key);
      expertDraftValues[key] = expertOriginalBool(key);
      dirtyKeys.remove(key);
      dirtyGroupKeys.remove(key);
      dirtyExpertKeys.remove(key);
    }
    editorRevision.value++;
    setInfo('Entwürfe in „${groupLabel(group)}“ wurden zurückgesetzt.', topic: 'local/reset');
  }

  void applySessionForGroup(String group, {required bool expertModeEnabled}) {
    final keys = keysForGroup(group, expertModeEnabled: expertModeEnabled);
    final payload = _payloadFromDrafts(sessionOnly: true, onlyKeys: keys);
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Board-Werte in „${groupLabel(group)}“ werden für die aktuelle Session gesendet ...';
    lastTopic.value = 'settings/ll_board/set/session/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine Backend-Bestätigung für die Low-Level-Board-Sessionänderung empfangen.');
    _rememberPendingAction(payload, sessionOnly: true);
    Get.find<MqttConnection>().publishLowLevelPowerSessionSettings(payload);
  }

  void savePersistentForGroup(String group, {required bool expertModeEnabled}) {
    final keys = keysForGroup(group, expertModeEnabled: expertModeEnabled);
    final payload = _payloadFromDrafts(sessionOnly: false, onlyKeys: keys);
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Board-Werte und Metadaten in „${groupLabel(group)}“ werden dauerhaft gespeichert ...';
    lastTopic.value = 'settings/ll_board/set/persistent/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine Backend-Bestätigung für das dauerhafte Speichern der Low-Level-Board-Werte empfangen.');
    _rememberPendingAction(payload, sessionOnly: false);
    Get.find<MqttConnection>().publishLowLevelPowerPersistentSettings(payload);
  }

  void _rememberPendingAction(Map<String, dynamic> payload, {required bool sessionOnly}) {
    final valueKeys = <String>{};
    final groupKeys = <String>{};
    final expertKeys = <String>{};
    payload.forEach((key, value) {
      final settingKey = key.toString();
      if (value is Map) {
        if (value.containsKey('value')) {
          valueKeys.add(settingKey);
        }
        if (!sessionOnly && value.containsKey('group')) {
          groupKeys.add(settingKey);
        }
        if (!sessionOnly && value.containsKey('expert')) {
          expertKeys.add(settingKey);
        }
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
    if (fields.contains('value')) {
      dirtyKeys.remove(key);
    }
    if (fields.contains('group')) {
      dirtyGroupKeys.remove(key);
    }
    if (fields.contains('expert')) {
      dirtyExpertKeys.remove(key);
    }
  }

  String? _normalizedGroupDraftValue(String key) {
    final value = (groupDraftTexts[key] ?? groupOriginalText(key)).trim();
    if (value.isEmpty || value.length > 80 || _containsControlCharacters(value)) {
      return null;
    }
    return value;
  }

  bool _containsControlCharacters(String value) => value.runes.any((char) => char < 0x20 || char == 0x7f);

  void _armResponseTimeout(String timeoutMessage) {
    _responseTimeout?.cancel();
    final generation = ++_responseWaitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _responseWaitGeneration || !waitingForResponse.value) {
        return;
      }
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

  double? _double(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim().replaceAll(',', '.') ?? '');
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }

  bool _boolOrFalse(dynamic value) => _boolOrNull(value) ?? false;

  bool? _boolOrNull(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    if (raw == null) {
      return const <String>[];
    }
    return <String>[raw.toString()];
  }

  List<String> _rejectedRemarks(dynamic raw) {
    if (raw is Map) {
      return raw.entries.map((entry) => '${entry.key}: ${entry.value}').toList();
    }
    if (raw is! List) {
      return const <String>[];
    }
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

  String _displayNumber(double value) {
    final text = value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  String _displayAny(dynamic value) {
    final number = _double(value);
    return number == null ? value.toString() : _displayNumber(number);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}
