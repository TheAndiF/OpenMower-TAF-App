import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class GpsStateController extends GetxController {
  static const List<String> settingKeys = <String>[
    'enabled',
    'publish_rate_hz',
    'publish_state0',
    'publish_state1',
    'publish_state2',
    'publish_state3',
    'publish_state4',
    'weak_cn0_threshold',
    'good_cn0_threshold',
  ];

  static const List<String> restartModes = <String>[
    'hot_start',
    'warm_start',
    'cold_start',
  ];

  static const List<String> restartResetModes = <String>[
    'controlled_software',
    'gnss_only',
    'hardware_watchdog',
  ];

  final state0 = <String, dynamic>{}.obs;
  final state0Legacy = <String, dynamic>{}.obs;
  final state0Definition = <String, dynamic>{}.obs;
  final state0Status = <String, dynamic>{}.obs;
  final state1 = <String, dynamic>{}.obs;
  final state2 = <String, dynamic>{}.obs;
  final state3 = <String, dynamic>{}.obs;
  final state4 = <String, dynamic>{}.obs;
  final settingsPayload = <String, dynamic>{}.obs;
  final validationPayload = <String, dynamic>{}.obs;
  final restartStatusPayload = <String, dynamic>{}.obs;
  final restartValidationPayload = <String, dynamic>{}.obs;
  final draftValues = <String, dynamic>{}.obs;
  final dirtyKeys = <String>{}.obs;

  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final editorRevision = 0.obs;
  final restartResetMode = 'controlled_software'.obs;

  Timer? _responseTimeout;
  int _responseWaitGeneration = 0;

  bool get hasState => state0.isNotEmpty || state0Legacy.isNotEmpty || state0Definition.isNotEmpty || state0Status.isNotEmpty || state1.isNotEmpty || state2.isNotEmpty || state3.isNotEmpty || state4.isNotEmpty;
  bool get hasSettings => settingsPayload.isNotEmpty;
  bool get state0Active => settingBool('publish_state0', fallback: state0.isNotEmpty || state0Legacy.isNotEmpty || state0Definition.isNotEmpty || state0Status.isNotEmpty);
  bool get state4Active => settingBool('publish_state4', fallback: state4.isNotEmpty);
  bool get hasRestartStatus => restartStatusPayload.isNotEmpty || restartValidationPayload.isNotEmpty;

  String get rawJson {
    final data = <String, dynamic>{
      'state0': state0,
      'state0_legacy': state0Legacy,
      'state0_definition': state0Definition,
      'state0_status': state0Status,
      'state1': state1,
      'state2': state2,
      'state3': state3,
      'state4': state4,
      'settings': settingsPayload,
      'validation': validationPayload,
      'restart_status': restartStatusPayload,
      'restart_validation': restartValidationPayload,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  List<Map<String, dynamic>> satellitesForState(int stateNumber) {
    final source = stateNumber == 4 ? state4 : state3;
    final rawSatellites = source['satellites'];
    if (rawSatellites is Iterable) {
      return rawSatellites
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  void requestStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'GPS-State wird neu angefordert ...';
    lastTopic.value = MqttConnection.gpsStateRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine GPS-State-Antwort empfangen. Bitte Topic gps_state/# prüfen.');
    Get.find<MqttConnection>().requestGpsState();
    Get.find<MqttConnection>().requestGpsRestartStatus();
  }

  void setStatePayload(int stateNumber, Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    switch (stateNumber) {
      case 0:
        _setState0Payload(root, topic: topic);
        break;
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
    lastStatusOk.value = true;
    lastStatus.value = 'GPS-State $stateNumber empfangen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }


  void _setState0Payload(Map<String, dynamic> root, {required String topic}) {
    final type = root['type']?.toString().trim().toLowerCase();
    final isDefinition = type == 'definition' || topic == MqttConnection.gpsState0DefinitionTopic;
    final isStatus = type == 'status' || topic == MqttConnection.gpsState0StatusTopic;

    // State0 is split by the ROS side into a retained static definition and a
    // frequently changing live status. Keep both payloads instead of allowing
    // the last received MQTT message to overwrite the other half.
    if (root['definition'] is Map || root['status'] is Map) {
      // Accept a combined State0 object as well, for example from tests or
      // older bridges that bundle definition and status in one retained value.
      if (root['definition'] is Map) {
        state0Definition.assignAll(_deepCopy(Map<String, dynamic>.from(root['definition'] as Map)));
      }
      if (root['status'] is Map) {
        state0Status.assignAll(_deepCopy(Map<String, dynamic>.from(root['status'] as Map)));
      }
    } else if (isDefinition) {
      state0Definition.assignAll(_deepCopy(root));
    } else if (isStatus) {
      state0Status.assignAll(_deepCopy(root));
    } else {
      // Backwards-compatible fallback for older packets that published a single
      // combined State0 object directly on gps_state/state0.
      state0Legacy.assignAll(_deepCopy(root));
    }

    final combined = <String, dynamic>{};
    if (state0Legacy.isNotEmpty) combined['legacy'] = _deepCopy(state0Legacy);
    if (state0Definition.isNotEmpty) combined['definition'] = _deepCopy(state0Definition);
    if (state0Status.isNotEmpty) combined['status'] = _deepCopy(state0Status);
    state0.assignAll(combined);
  }

  void setSettingsPayload(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    settingsPayload.assignAll(_deepCopy(root));
    draftValues.clear();
    dirtyKeys.clear();
    editorRevision.value++;
    lastStatusOk.value = true;
    lastStatus.value = 'GPS-State-Settings empfangen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void setValidation(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    validationPayload.assignAll(_deepCopy(root));
    final valid = _bool(root['valid'] ?? root['ok'] ?? root['success']);
    lastStatusOk.value = valid;
    lastStatus.value = valid
        ? 'GPS-State-Änderung wurde angenommen.'
        : 'GPS-State-Änderung wurde abgelehnt.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
    if (valid) {
      draftValues.clear();
      dirtyKeys.clear();
      requestStatus();
    }
  }

  void setRestartStatus(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    restartStatusPayload.assignAll(_deepCopy(root));
    final accepted = _bool(root['accepted'] ?? root['ok'] ?? root['success'], fallback: false);
    final status = root['status']?.toString();
    final normalizedStatus = status?.toLowerCase() ?? '';
    final sent = normalizedStatus == 'sent' || normalizedStatus == 'requested' || normalizedStatus == 'ok' || accepted;
    final rejected = normalizedStatus == 'rejected' || normalizedStatus == 'send_failed' || normalizedStatus == 'failed' || normalizedStatus == 'error';
    lastStatusOk.value = rejected ? false : sent;
    lastStatus.value = status == null || status.isEmpty
        ? 'F9P-Neustartstatus empfangen.'
        : 'F9P-Neustartstatus: $status';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void setRestartValidation(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    restartValidationPayload.assignAll(_deepCopy(root));
    final valid = _bool(root['valid'] ?? root['ok'] ?? root['success'] ?? root['accepted']);
    lastStatusOk.value = valid;
    lastStatus.value = valid
        ? 'F9P-Neustartbefehl wurde angenommen.'
        : 'F9P-Neustartbefehl wurde abgelehnt.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void requestRestartStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'F9P-Neustartstatus wird neu angefordert ...';
    lastTopic.value = MqttConnection.gpsStateRestartRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine F9P-Neustartstatus-Antwort empfangen. Bitte Topic gps_state/restart/# prüfen.');
    Get.find<MqttConnection>().requestGpsRestartStatus();
  }

  void restartF9p(String mode, {String? resetMode}) {
    final normalizedMode = restartModes.contains(mode) ? mode : 'hot_start';
    final normalizedResetMode = restartResetModes.contains(resetMode) ? resetMode! : restartResetMode.value;
    final payload = <String, dynamic>{
      'mode': normalizedMode,
      'reset_mode': normalizedResetMode,
    };
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'F9P-Neustart wird angefordert: $normalizedMode ...';
    lastTopic.value = MqttConnection.gpsStateRestartSetJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine F9P-Neustart-Rückmeldung empfangen. Bitte gps_state/restart/# prüfen.');
    Get.find<MqttConnection>().publishGpsRestartCommand(payload);
  }

  void setError(String message, {String topic = 'local/error'}) {
    waitingForResponse.value = false;
    lastStatusOk.value = false;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _clearResponseTimeout();
  }

  void setDraftValue(String key, dynamic value) {
    draftValues[key] = value;
    dirtyKeys.add(key);
  }

  void applySession() {
    _publishDraft(persistent: false);
  }

  void applyPersistent() {
    _publishDraft(persistent: true);
  }

  void setState4Enabled(bool enabled) {
    setDraftValue('publish_state4', enabled);
    final payload = <String, dynamic>{
      'publish_state4': <String, dynamic>{'value': enabled},
    };
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = enabled
        ? 'State4 wird temporär aktiviert ...'
        : 'State4 wird temporär deaktiviert ...';
    lastTopic.value = MqttConnection.gpsStateSetSessionJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine Validierung für State4-Änderung empfangen.');
    Get.find<MqttConnection>().publishGpsStateSessionSettings(payload);
  }

  void _publishDraft({required bool persistent}) {
    if (dirtyKeys.isEmpty) {
      requestStatus();
      return;
    }
    final payload = <String, dynamic>{};
    for (final key in dirtyKeys) {
      payload[key] = <String, dynamic>{'value': draftValues[key]};
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = persistent
        ? 'GPS-State-Settings werden dauerhaft gespeichert ...'
        : 'GPS-State-Settings werden für die Session angewendet ...';
    lastTopic.value = persistent
        ? MqttConnection.gpsStateSetPersistentJsonTopic
        : MqttConnection.gpsStateSetSessionJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine GPS-State-Validierung empfangen.');
    if (persistent) {
      Get.find<MqttConnection>().publishGpsStatePersistentSettings(payload);
    } else {
      Get.find<MqttConnection>().publishGpsStateSessionSettings(payload);
    }
  }

  bool settingBool(String key, {bool fallback = false}) => _bool(_settingValue(key), fallback: fallback);

  double settingDouble(String key, {double fallback = 0.0}) => _double(_settingValue(key), fallback: fallback);

  dynamic settingValue(String key) => draftValues.containsKey(key) ? draftValues[key] : _settingValue(key);

  dynamic _settingValue(String key) {
    if (draftValues.containsKey(key)) {
      return draftValues[key];
    }
    final direct = settingsPayload[key];
    final fromSettings = settingsPayload['settings'];
    dynamic item;
    if (direct != null) {
      item = direct;
    } else if (fromSettings is Map) {
      item = fromSettings[key];
    }
    if (item is Map) {
      if (item.containsKey('value')) return item['value'];
      if (item.containsKey('session')) return item['session'];
      if (item.containsKey('persistent')) return item['persistent'];
      if (item.containsKey('default')) return item['default'];
    }
    return item;
  }

  String labelFor(String key) {
    final item = _settingMeta(key);
    final raw = item['label'] ?? item['name'] ?? item['title'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString();
    }
    switch (key) {
      case 'enabled':
        return 'GPS-State aktiviert';
      case 'publish_rate_hz':
        return 'Publish-Rate';
      case 'publish_state0':
        return 'State0 veröffentlichen';
      case 'publish_state1':
        return 'State1 veröffentlichen';
      case 'publish_state2':
        return 'State2 veröffentlichen';
      case 'publish_state3':
        return 'State3 veröffentlichen';
      case 'publish_state4':
        return 'State4 veröffentlichen';
      case 'weak_cn0_threshold':
        return 'Schwellwert schwach';
      case 'good_cn0_threshold':
        return 'Schwellwert gut';
    }
    return key;
  }

  String unitFor(String key) {
    final item = _settingMeta(key);
    final unit = item['unit'];
    if (unit != null && unit.toString().trim().isNotEmpty) return unit.toString();
    if (key == 'publish_rate_hz') return 'Hz';
    if (key.endsWith('_cn0_threshold')) return 'dB-Hz';
    return '';
  }

  String descriptionFor(String key) {
    final item = _settingMeta(key);
    final raw = item['description'] ?? item['help'];
    return raw?.toString() ?? '';
  }

  Map<String, dynamic> _settingMeta(String key) {
    final direct = settingsPayload[key];
    final fromSettings = settingsPayload['settings'];
    if (direct is Map) return Map<String, dynamic>.from(direct);
    if (fromSettings is Map && fromSettings[key] is Map) {
      return Map<String, dynamic>.from(fromSettings[key] as Map);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _root(Map<String, dynamic> payload) {
    if (payload['d'] is Map) {
      return Map<String, dynamic>.from(payload['d'] as Map);
    }
    return Map<String, dynamic>.from(payload);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized == 'null') return fallback;
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on';
  }

  double _double(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _armResponseTimeout(String message) {
    _responseTimeout?.cancel();
    final generation = ++_responseWaitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _responseWaitGeneration) return;
      waitingForResponse.value = false;
      lastStatusOk.value = null;
      lastStatus.value = message;
      lastUpdated.value = DateTime.now();
    });
  }

  void _clearResponseTimeout() {
    _responseTimeout?.cancel();
    _responseTimeout = null;
    _responseWaitGeneration++;
  }
}
