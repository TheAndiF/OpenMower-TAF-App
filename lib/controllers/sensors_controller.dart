import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';
import 'package:open_mower_app/models/sensor_state.dart';

class SensorsController extends GetxController {
  static const Set<String> builtInHiddenSensorIds = {
    'mow_motor_direction',
  };

  final sensorStates = <String, SensorState>{}.obs;
  final settingsPayload = <String, dynamic>{}.obs;
  final sensorSettings = <String, Map<String, dynamic>>{}.obs;

  final labelDraftValues = <String, String>{}.obs;
  final descriptionDraftValues = <String, String>{}.obs;
  final groupDraftValues = <String, String>{}.obs;
  final orderDraftValues = <String, int>{}.obs;
  final visibleDraftValues = <String, bool>{}.obs;
  final expertDraftValues = <String, bool>{}.obs;
  final dirtyKeys = <String>{}.obs;
  final editorRevision = 0.obs;

  final lastRemarks = <String>[].obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final statusRefreshInProgress = false.obs;
  final actionInProgress = false.obs;

  Timer? _statusResponseTimeout;
  Timer? _actionResponseTimeout;
  Set<String> _pendingKeys = <String>{};
  int _statusResponseWaitGeneration = 0;
  int _actionResponseWaitGeneration = 0;

  bool get hasSensorSettings => sensorSettings.isNotEmpty;
  int get visibleSensorCount => visibleSensorsForMode(expertModeEnabled: true).length;
  int get hiddenSensorCount => sensorSettings.entries.where((entry) => !_visibleSeed(entry.value)).length;
  int get expertSensorCount => sensorSettings.entries.where((entry) => _expertSeed(entry.value)).length;
  int get missingLiveValueCount => sensorSettings.keys.where((key) => !sensorStates.containsKey(key)).length;
  int get dirtyCount => dirtyKeys.length;

  String get rawSettingsJson {
    if (settingsPayload.isEmpty) return '{}';
    return const JsonEncoder.withIndent('  ').convert(settingsPayload);
  }

  void requestSensorSettings() {
    statusRefreshInProgress.value = true;
    _syncWaitingState();
    lastStatusOk.value = null;
    lastRemarks.clear();
    lastStatus.value = 'Sensor-Metadaten werden neu angefordert ...';
    lastTopic.value = MqttConnection.sensorSettingsRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armStatusResponseTimeout(
      'Keine Sensor-Metadaten empfangen. Bitte MQTT-Topic ${MqttConnection.sensorSettingsJsonTopic} prüfen.',
    );
    Get.find<MqttConnection>().requestSensorSettings();
  }

  void setSettingsPayload(Map<String, dynamic> payload, {String topic = MqttConnection.sensorSettingsJsonTopic}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final rawSettings = root['settings'];
    if (rawSettings is! Map) {
      setError('Sensor-Metadaten enthalten kein gültiges settings-Objekt.', topic: topic);
      return;
    }

    final next = <String, Map<String, dynamic>>{};
    rawSettings.forEach((key, value) {
      final sensorId = key.toString();
      if (sensorId.isEmpty || value is! Map) return;
      final metadata = Map<String, dynamic>.from(value);
      metadata['sensor_id'] = metadata['sensor_id']?.toString() ?? sensorId;
      metadata.putIfAbsent('group', () => _fallbackGroup(sensorId));
      metadata.putIfAbsent('label', () => metadata['sensor_name']?.toString() ?? sensorId);
      metadata.putIfAbsent('visible', () => !builtInHiddenSensorIds.contains(sensorId));
      metadata.putIfAbsent('expert', () => false);
      metadata.putIfAbsent('order', () => _fallbackOrder(sensorId));
      metadata.putIfAbsent('value_topic', () => 'sensors/$sensorId/data');
      next[sensorId] = metadata;
    });

    settingsPayload
      ..clear()
      ..addAll(_deepCopy(root));
    sensorSettings
      ..clear()
      ..addAll(next);

    for (final entry in sensorSettings.entries) {
      _seedDrafts(entry.key, entry.value, overwriteDirty: false);
      _ensureSensorStateFromMetadata(entry.key, entry.value);
      sensorStates[entry.key]?.applyMetadata(entry.value);
    }
    _removeDraftsForMissingSensors();
    sensorStates.refresh();
    editorRevision.value++;

    _clearStatusResponseTimeout();
    statusRefreshInProgress.value = false;
    _syncWaitingState();
    lastStatusOk.value ??= true;
    if (lastStatus.value.isEmpty || lastStatus.value.contains('angefordert')) {
      lastStatus.value = 'Sensor-Metadaten vom Backend empfangen.';
    }
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void upsertSensorFromInfo(Map<String, dynamic> sensorInfo) {
    final sensorId = sensorInfo['sensor_id']?.toString() ?? '';
    if (sensorId.isEmpty) return;

    final metadata = _metadataFor(sensorId, sensorInfo: sensorInfo);
    final type = (sensorInfo['value_type'] ?? metadata['type'] ?? '').toString().toUpperCase();
    SensorState sensor;
    switch (type) {
      case 'DOUBLE':
      case 'FLOAT':
      case 'NUMBER':
        sensor = DoubleSensorState(
          sensorId,
          _text(sensorInfo['sensor_name'] ?? metadata['sensor_name'], fallback: sensorId),
          _text(sensorInfo['unit'] ?? metadata['unit']),
          _double(sensorInfo['min_value']),
          _double(sensorInfo['max_value']),
          sensorInfo['has_min_max'] == 1 || sensorInfo['has_min_max'] == true,
          _double(sensorInfo['lower_critical_value']),
          sensorInfo['has_critical_low'] == 1 || sensorInfo['has_critical_low'] == true,
          _double(sensorInfo['upper_critical_value']),
          sensorInfo['has_critical_high'] == 1 || sensorInfo['has_critical_high'] == true,
          label: _text(metadata['label'], fallback: _text(sensorInfo['sensor_name'], fallback: sensorId)),
          description: _text(metadata['description']),
          group: _text(metadata['group'], fallback: _fallbackGroup(sensorId)),
          order: _int(metadata['order']) ?? _fallbackOrder(sensorId),
          visible: _visibleSeed(metadata),
          expert: _expertSeed(metadata),
          valueTopic: _text(metadata['value_topic'], fallback: 'sensors/$sensorId/data'),
        );
        break;
      default:
        sensor = StringSensorState(
          sensorId,
          _text(sensorInfo['sensor_name'] ?? metadata['sensor_name'], fallback: sensorId),
          _text(sensorInfo['unit'] ?? metadata['unit']),
          label: _text(metadata['label'], fallback: _text(sensorInfo['sensor_name'], fallback: sensorId)),
          description: _text(metadata['description']),
          group: _text(metadata['group'], fallback: _fallbackGroup(sensorId)),
          order: _int(metadata['order']) ?? _fallbackOrder(sensorId),
          visible: _visibleSeed(metadata),
          expert: _expertSeed(metadata),
          valueTopic: _text(metadata['value_topic'], fallback: 'sensors/$sensorId/data'),
        );
        break;
    }

    sensorStates[sensorId] = sensor;
    sensorStates.refresh();
  }

  void _ensureSensorStateFromMetadata(String sensorId, Map<String, dynamic> metadata, {dynamic valueHint}) {
    if (sensorStates.containsKey(sensorId)) {
      sensorStates[sensorId]?.applyMetadata(metadata);
      return;
    }

    final normalizedValue = _normalizeLiveValue(valueHint);
    final type = _text(metadata['type'] ?? metadata['value_type']).toLowerCase();
    final unit = _text(metadata['unit']);
    final isNumeric = type == 'double' ||
        type == 'float' ||
        type == 'number' ||
        type == 'int' ||
        type == 'integer' ||
        normalizedValue is num ||
        (normalizedValue is String && double.tryParse(normalizedValue) != null && normalizedValue.trim().isNotEmpty);

    final sensorName = _text(metadata['sensor_name'], fallback: sensorId);
    if (isNumeric) {
      sensorStates[sensorId] = DoubleSensorState(
        sensorId,
        sensorName,
        unit,
        _double(metadata['min_value']),
        _double(metadata['max_value']),
        _bool(metadata['has_min_max']),
        _double(metadata['lower_critical_value']),
        _bool(metadata['has_critical_low']),
        _double(metadata['upper_critical_value']),
        _bool(metadata['has_critical_high']),
        label: _labelSeed(sensorId, metadata),
        description: _descriptionSeed(metadata),
        group: _groupSeed(metadata),
        order: _int(metadata['order']) ?? _fallbackOrder(sensorId),
        visible: _visibleSeed(metadata),
        expert: _expertSeed(metadata),
        valueTopic: _text(metadata['value_topic'], fallback: 'sensors/$sensorId/data'),
      );
    } else {
      sensorStates[sensorId] = StringSensorState(
        sensorId,
        sensorName,
        unit,
        label: _labelSeed(sensorId, metadata),
        description: _descriptionSeed(metadata),
        group: _groupSeed(metadata),
        order: _int(metadata['order']) ?? _fallbackOrder(sensorId),
        visible: _visibleSeed(metadata),
        expert: _expertSeed(metadata),
        valueTopic: _text(metadata['value_topic'], fallback: 'sensors/$sensorId/data'),
      );
    }
  }


  void updateSensorValue(String sensorId, dynamic value) {
    if (sensorId.isEmpty) return;
    final metadata = _metadataFor(sensorId);
    _ensureSensorStateFromMetadata(sensorId, metadata, valueHint: value);

    final sensor = sensorStates[sensorId];
    if (sensor is DoubleSensorState) {
      sensor.value = _double(_normalizeLiveValue(value));
    } else if (sensor is StringSensorState) {
      final normalized = _normalizeLiveValue(value);
      sensor.value = normalized?.toString() ?? '';
    }
    sensorStates.refresh();
  }

  List<String> groupsForMode({required bool expertModeEnabled}) {
    final groupNames = visibleSensorsForMode(expertModeEnabled: expertModeEnabled)
        .map((entry) => entry.value.group)
        .toSet()
        .toList();
    groupNames.sort((a, b) => _groupOrder(a).compareTo(_groupOrder(b)));
    return groupNames;
  }

  List<MapEntry<String, SensorState>> visibleSensorsForMode({required bool expertModeEnabled}) {
    final entries = sensorStates.entries
        .where((entry) => !builtInHiddenSensorIds.contains(entry.key))
        .where((entry) => entry.value.visible)
        .where((entry) => expertModeEnabled || !entry.value.expert)
        .toList();
    entries.sort(_compareSensorEntries);
    return entries;
  }

  List<MapEntry<String, SensorState>> visibleSensorsForGroup(String group, {required bool expertModeEnabled}) {
    return visibleSensorsForMode(expertModeEnabled: expertModeEnabled)
        .where((entry) => entry.value.group == group)
        .toList(growable: false);
  }

  List<String> settingGroupsForMode({required bool expertModeEnabled}) {
    final groupNames = sensorSettings.values
        .where((setting) => expertModeEnabled || !_expertSeed(setting))
        .map((setting) => _groupSeed(setting))
        .toSet()
        .toList();
    groupNames.sort((a, b) => _groupOrder(a).compareTo(_groupOrder(b)));
    return groupNames;
  }

  List<MapEntry<String, Map<String, dynamic>>> settingsForGroup(String group, {required bool expertModeEnabled}) {
    final entries = sensorSettings.entries
        .where((entry) => _groupSeed(entry.value) == group)
        .where((entry) => expertModeEnabled || !_expertSeed(entry.value))
        .toList();
    entries.sort((a, b) {
      final orderA = _int(a.value['order']) ?? _fallbackOrder(a.key);
      final orderB = _int(b.value['order']) ?? _fallbackOrder(b.key);
      final byOrder = orderA.compareTo(orderB);
      return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
    });
    return entries;
  }

  int dirtyCountForGroup(String group, {required bool expertModeEnabled}) =>
      settingsForGroup(group, expertModeEnabled: expertModeEnabled).where((entry) => dirtyKeys.contains(entry.key)).length;

  String groupLabel(String group) {
    switch (group) {
      case 'battery':
        return 'Akku';
      case 'charging':
      case 'charge':
        return 'Laden';
      case 'mowing_motor':
        return 'Mähmotor';
      case 'drive':
        return 'Antrieb';
      case 'temperature':
        return 'Temperatur';
      case 'gps':
        return 'GPS';
      case 'host_system':
        return 'Host-System';
      case 'system':
        return 'System';
      case 'general':
        return 'Allgemein';
      default:
        return group;
    }
  }

  IconData groupIcon(String group) {
    switch (group) {
      case 'battery':
        return Icons.battery_full_outlined;
      case 'charging':
      case 'charge':
        return Icons.ev_station_outlined;
      case 'mowing_motor':
        return Icons.grass;
      case 'drive':
        return Icons.speed;
      case 'temperature':
        return Icons.device_thermostat;
      case 'gps':
        return Icons.gps_fixed;
      case 'host_system':
      case 'system':
        return Icons.memory_outlined;
      default:
        return Icons.sensors_outlined;
    }
  }

  String labelDraftText(String key, Map<String, dynamic> setting) => labelDraftValues[key] ?? _labelSeed(key, setting);
  String descriptionDraftText(String key, Map<String, dynamic> setting) => descriptionDraftValues[key] ?? _descriptionSeed(setting);
  String groupDraftText(String key, Map<String, dynamic> setting) => groupDraftValues[key] ?? _groupSeed(setting);
  int orderDraftInt(String key, Map<String, dynamic> setting) => orderDraftValues[key] ?? (_int(setting['order']) ?? _fallbackOrder(key));
  bool visibleDraftBool(String key, Map<String, dynamic> setting) => visibleDraftValues[key] ?? _visibleSeed(setting);
  bool expertDraftBool(String key, Map<String, dynamic> setting) => expertDraftValues[key] ?? _expertSeed(setting);

  void updateDraftLabel(String key, Map<String, dynamic> setting, String value) {
    labelDraftValues[key] = value;
    _updateDirtyState(key, setting);
  }

  void updateDraftDescription(String key, Map<String, dynamic> setting, String value) {
    descriptionDraftValues[key] = value;
    _updateDirtyState(key, setting);
  }

  void updateDraftGroup(String key, Map<String, dynamic> setting, String value) {
    groupDraftValues[key] = value;
    _updateDirtyState(key, setting);
  }

  void updateDraftOrder(String key, Map<String, dynamic> setting, String value) {
    orderDraftValues[key] = int.tryParse(value.trim()) ?? orderDraftInt(key, setting);
    _updateDirtyState(key, setting);
  }

  void updateDraftVisible(String key, Map<String, dynamic> setting, bool value) {
    visibleDraftValues[key] = value;
    _updateDirtyState(key, setting);
  }

  void updateDraftExpert(String key, Map<String, dynamic> setting, bool value) {
    expertDraftValues[key] = value;
    _updateDirtyState(key, setting);
  }

  void resetGroupDrafts(String group, {required bool expertModeEnabled}) {
    for (final entry in settingsForGroup(group, expertModeEnabled: expertModeEnabled)) {
      _seedDrafts(entry.key, entry.value, overwriteDirty: true);
      dirtyKeys.remove(entry.key);
    }
    editorRevision.value++;
    setInfo('Entwürfe in „${groupLabel(group)}“ wurden zurückgesetzt.', topic: 'local/reset');
  }

  void savePersistentForGroup(String group, {required bool expertModeEnabled}) {
    final payload = _payloadForGroup(group, expertModeEnabled: expertModeEnabled);
    if (payload == null) return;
    actionInProgress.value = true;
    _syncWaitingState();
    lastStatusOk.value = null;
    lastStatus.value = 'Sensor-Metadaten werden dauerhaft gespeichert ...';
    lastTopic.value = MqttConnection.sensorSettingsSetPersistentJsonTopic;
    lastUpdated.value = DateTime.now();
    _armActionResponseTimeout(
      'Keine Backend-Bestätigung für das dauerhafte Speichern empfangen. Bitte Validation-Topic prüfen.',
    );
    _pendingKeys = payload.keys.toSet();
    Get.find<MqttConnection>().publishSensorPersistentSettings(payload);
  }

  Map<String, dynamic>? _payloadForGroup(String group, {required bool expertModeEnabled}) {
    final payload = <String, dynamic>{};
    for (final entry in settingsForGroup(group, expertModeEnabled: expertModeEnabled)) {
      final key = entry.key;
      final setting = entry.value;
      if (!dirtyKeys.contains(key)) continue;

      final label = labelDraftText(key, setting).trim();
      final description = descriptionDraftText(key, setting).trim();
      final groupValue = groupDraftText(key, setting).trim();
      if (label.isEmpty || groupValue.isEmpty || label.length > 120 || groupValue.length > 80 || _hasControlChars(label) || _hasControlChars(groupValue)) {
        setError('Sensor „$key“ enthält ungültige Metadaten. Label und Gruppe dürfen nicht leer sein.', topic: 'local/validation');
        return null;
      }

      payload[key] = <String, dynamic>{
        'label': label,
        'description': description,
        'group': groupValue,
        'order': orderDraftInt(key, setting),
        'visible': visibleDraftBool(key, setting),
        'expert': expertDraftBool(key, setting),
      };
    }
    if (payload.isEmpty) {
      setInfo('In „${groupLabel(group)}“ gibt es keine geänderten Sensor-Metadaten.', topic: 'local/info');
      return null;
    }
    return payload;
  }

  void setValidation(Map<String, dynamic> payload, {String topic = MqttConnection.sensorSettingsValidationJsonTopic}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final valid = _boolOrNull(root['valid']);
    final remarks = <String>[
      ..._stringList(root['remarks']),
      ..._rejectedRemarks(root['rejected']),
    ];
    final accepted = _acceptedKeys(root['accepted'] ?? root['applied']);

    lastRemarks.assignAll(remarks);
    lastStatusOk.value = valid;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _clearActionResponseTimeout();
    actionInProgress.value = false;
    _syncWaitingState();

    if (accepted.isNotEmpty) {
      for (final key in accepted) {
        dirtyKeys.remove(key);
      }
    } else if (valid == true) {
      for (final key in _pendingKeys) {
        dirtyKeys.remove(key);
      }
    }
    if (valid == true || valid == false) {
      _pendingKeys = <String>{};
    }

    if (valid == true) {
      lastStatus.value = 'Sensor-Metadaten wurden dauerhaft gespeichert.';
    } else if (valid == false) {
      lastStatus.value = 'Sensor-Metadaten wurden teilweise oder vollständig abgelehnt. Bitte Hinweise prüfen.';
    } else {
      lastStatus.value = 'Sensor-Validierungsantwort empfangen.';
    }
  }

  void setError(String message, {String topic = 'local/error'}) {
    _clearStatusResponseTimeout();
    _clearActionResponseTimeout();
    statusRefreshInProgress.value = false;
    actionInProgress.value = false;
    _syncWaitingState();
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

  void _syncWaitingState() {
    waitingForResponse.value = statusRefreshInProgress.value || actionInProgress.value;
  }

  void _seedDrafts(String key, Map<String, dynamic> setting, {required bool overwriteDirty}) {
    if (overwriteDirty || !dirtyKeys.contains(key)) {
      labelDraftValues[key] = _labelSeed(key, setting);
      descriptionDraftValues[key] = _descriptionSeed(setting);
      groupDraftValues[key] = _groupSeed(setting);
      orderDraftValues[key] = _int(setting['order']) ?? _fallbackOrder(key);
      visibleDraftValues[key] = _visibleSeed(setting);
      expertDraftValues[key] = _expertSeed(setting);
    }
  }

  void _removeDraftsForMissingSensors() {
    labelDraftValues.removeWhere((key, value) => !sensorSettings.containsKey(key));
    descriptionDraftValues.removeWhere((key, value) => !sensorSettings.containsKey(key));
    groupDraftValues.removeWhere((key, value) => !sensorSettings.containsKey(key));
    orderDraftValues.removeWhere((key, value) => !sensorSettings.containsKey(key));
    visibleDraftValues.removeWhere((key, value) => !sensorSettings.containsKey(key));
    expertDraftValues.removeWhere((key, value) => !sensorSettings.containsKey(key));
    dirtyKeys.removeWhere((key) => !sensorSettings.containsKey(key));
  }

  void _updateDirtyState(String key, Map<String, dynamic> setting) {
    final dirty = labelDraftText(key, setting).trim() != _labelSeed(key, setting) ||
        descriptionDraftText(key, setting).trim() != _descriptionSeed(setting) ||
        groupDraftText(key, setting).trim() != _groupSeed(setting) ||
        orderDraftInt(key, setting) != (_int(setting['order']) ?? _fallbackOrder(key)) ||
        visibleDraftBool(key, setting) != _visibleSeed(setting) ||
        expertDraftBool(key, setting) != _expertSeed(setting);
    if (dirty) {
      dirtyKeys.add(key);
    } else {
      dirtyKeys.remove(key);
    }
  }

  dynamic _normalizeLiveValue(dynamic value) {
    if (value is Map) {
      if (value.containsKey('d')) return _normalizeLiveValue(value['d']);
      if (value.containsKey('value')) return _normalizeLiveValue(value['value']);
      if (value.containsKey('data')) return _normalizeLiveValue(value['data']);
    }
    return value;
  }

  Map<String, dynamic> _metadataFor(String sensorId, {Map<String, dynamic>? sensorInfo}) {
    final existing = sensorSettings[sensorId];
    if (existing != null) return existing;
    return <String, dynamic>{
      'sensor_id': sensorId,
      'sensor_name': sensorInfo?['sensor_name']?.toString() ?? sensorId,
      'label': sensorInfo?['sensor_name']?.toString() ?? sensorId,
      'description': '',
      'group': _fallbackGroup(sensorId),
      'order': _fallbackOrder(sensorId),
      'visible': !builtInHiddenSensorIds.contains(sensorId),
      'expert': false,
      'unit': sensorInfo?['unit']?.toString() ?? '',
      'type': sensorInfo?['value_type']?.toString().toLowerCase() ?? 'string',
      'value_topic': 'sensors/$sensorId/data',
    };
  }

  int _compareSensorEntries(MapEntry<String, SensorState> a, MapEntry<String, SensorState> b) {
    final byGroup = _groupOrder(a.value.group).compareTo(_groupOrder(b.value.group));
    if (byGroup != 0) return byGroup;
    final byOrder = a.value.order.compareTo(b.value.order);
    return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
  }

  String _fallbackGroup(String sensorId) {
    if (sensorId.contains('battery') || sensorId == 'om_v_battery') return 'battery';
    if (sensorId.contains('charge') || sensorId == 'om_v_charge') return 'charging';
    if (sensorId.contains('mow_motor') || sensorId.contains('mow_esc')) return 'mowing_motor';
    if (sensorId.contains('left_esc') || sensorId.contains('right_esc')) return 'drive';
    if (sensorId.contains('gps')) return 'gps';
    if (sensorId.contains('wifi') || sensorId.contains('disk') || sensorId.contains('system') || sensorId.contains('reboot')) return 'host_system';
    if (sensorId.contains('temp')) return 'temperature';
    return 'general';
  }

  int _fallbackOrder(String sensorId) {
    const order = <String>[
      'om_gps_accuracy',
      'om_v_battery',
      'om_v_charge',
      'om_charge_current',
      'om_mow_motor_rpm',
      'om_mow_motor_current',
      'om_mow_motor_temp',
      'om_mow_esc_temp',
      'om_left_esc_temp',
      'om_right_esc_temp',
      'om_system_wifi_signal_percent',
      'om_system_wifi_ssid',
      'om_system_disk_free_percent',
      'om_system_time',
      'om_system_date',
      'om_system_last_reboot',
    ];
    final index = order.indexOf(sensorId);
    return index < 0 ? 999999 : (index + 1) * 10;
  }

  int _groupOrder(String group) {
    switch (group) {
      case 'battery':
        return 100;
      case 'charging':
      case 'charge':
        return 200;
      case 'mowing_motor':
        return 300;
      case 'drive':
        return 400;
      case 'temperature':
        return 500;
      case 'gps':
        return 600;
      case 'host_system':
      case 'system':
        return 700;
      case 'general':
        return 900;
      default:
        return 999;
    }
  }

  String _labelSeed(String key, Map<String, dynamic> setting) => _text(setting['label'], fallback: _text(setting['sensor_name'], fallback: key));
  String _descriptionSeed(Map<String, dynamic> setting) => _text(setting['description']);
  String _groupSeed(Map<String, dynamic> setting) => _text(setting['group'], fallback: 'general');
  bool _visibleSeed(Map<String, dynamic> setting) => _bool(setting['visible'], fallback: true);
  bool _expertSeed(Map<String, dynamic> setting) => _bool(setting['expert'], fallback: false);

  bool _hasControlChars(String value) => value.runes.any((rune) => rune < 32 && rune != 9 && rune != 10 && rune != 13);

  bool? _boolOrNull(dynamic value) {
    if (value == null) return null;
    return _bool(value);
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((value) => value.toString()).toList();
    if (raw == null) return const <String>[];
    return <String>[raw.toString()];
  }

  Set<String> _acceptedKeys(dynamic raw) {
    if (raw is Map) return raw.keys.map((key) => key.toString()).toSet();
    if (raw is List) {
      return raw.map((item) {
        if (item is Map && item['key'] != null) return item['key'].toString();
        return item.toString();
      }).where((key) => key.isNotEmpty).toSet();
    }
    return <String>{};
  }

  List<String> _rejectedRemarks(dynamic raw) {
    if (raw is Map) return raw.entries.map((entry) => '${entry.key}: ${entry.value}').toList();
    if (raw is! List) return const <String>[];
    return raw.map((item) => item.toString()).toList();
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> input) {
    return jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on';
  }

  void _armStatusResponseTimeout(String message) {
    _clearStatusResponseTimeout();
    final generation = ++_statusResponseWaitGeneration;
    _statusResponseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _statusResponseWaitGeneration || !statusRefreshInProgress.value) return;
      setError(message, topic: MqttConnection.sensorSettingsJsonTopic);
    });
  }

  void _armActionResponseTimeout(String message) {
    _clearActionResponseTimeout();
    final generation = ++_actionResponseWaitGeneration;
    _actionResponseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _actionResponseWaitGeneration || !actionInProgress.value) return;
      setError(message, topic: MqttConnection.sensorSettingsValidationJsonTopic);
    });
  }

  void _clearStatusResponseTimeout() {
    _statusResponseWaitGeneration++;
    _statusResponseTimeout?.cancel();
    _statusResponseTimeout = null;
  }

  void _clearActionResponseTimeout() {
    _actionResponseWaitGeneration++;
    _actionResponseTimeout?.cancel();
    _actionResponseTimeout = null;
  }

  @override
  void onClose() {
    _clearStatusResponseTimeout();
    _clearActionResponseTimeout();
    super.onClose();
  }
}
