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

  /// Logging defaults are exposed through the same GPS-State settings API as
  /// the other editable values. The runtime logger remains on
  /// gps_state/logging/* and snapshots the effective values when a request is
  /// started.
  static const List<String> loggingSettingKeys = <String>[
    'logging_default_trigger',
    'logging_default_mode',
    'logging_default_area_id',
  ];

  static const List<String> loggingTriggerFallbackOptions = <String>[
    'ad_hoc',
    'next_cycle',
    'area_id',
  ];

  static const List<String> loggingModeFallbackOptions = <String>[
    'manual',
    'until_docking',
    'from_start_to_docking',
    'from_docking_to_docking',
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

  final state0Definition = <String, dynamic>{}.obs;
  final state0Status = <String, dynamic>{}.obs;
  final state1 = <String, dynamic>{}.obs;
  final state1Definition = <String, dynamic>{}.obs;
  final state1Status = <String, dynamic>{}.obs;
  final state2 = <String, dynamic>{}.obs;
  final state2Definition = <String, dynamic>{}.obs;
  final state2Status = <String, dynamic>{}.obs;
  final state3 = <String, dynamic>{}.obs;
  final state3Definition = <String, dynamic>{}.obs;
  final state3Status = <String, dynamic>{}.obs;
  final state4 = <String, dynamic>{}.obs;
  final state4Definition = <String, dynamic>{}.obs;
  final state4Status = <String, dynamic>{}.obs;

  /// Raw canonical MQTT payloads and receive metadata. The display maps above
  /// additionally flatten the state-specific `data` object so the UI remains
  /// independent of transitional top-level compatibility fields.
  final stateDefinitionPayloads = <int, Map<String, dynamic>>{}.obs;
  final stateStatusPayloads = <int, Map<String, dynamic>>{}.obs;
  final stateDefinitionTopics = <int, String>{}.obs;
  final stateStatusTopics = <int, String>{}.obs;
  final stateDefinitionReceivedAt = <int, DateTime>{}.obs;
  final stateStatusReceivedAt = <int, DateTime>{}.obs;
  final settingsPayload = <String, dynamic>{}.obs;
  final validationPayload = <String, dynamic>{}.obs;
  final restartStatusPayload = <String, dynamic>{}.obs;
  final restartLastPayload = <String, dynamic>{}.obs;
  final restartValidationPayload = <String, dynamic>{}.obs;
  final draftValues = <String, dynamic>{}.obs;
  final dirtyKeys = <String>{}.obs;
  final _pendingSettingKeys = <String>{};

  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final editorRevision = 0.obs;
  final restartResetMode = 'controlled_software'.obs;

  final settingsReceivedAt = Rxn<DateTime>();
  final validationReceivedAt = Rxn<DateTime>();
  final restartStatusReceivedAt = Rxn<DateTime>();
  final restartLastReceivedAt = Rxn<DateTime>();
  final restartValidationReceivedAt = Rxn<DateTime>();

  // State0 has its own refresh lifecycle. The central renew command can be
  // satisfied by another State first, therefore it must not be used as proof
  // that the 12 State0 decision checks are current.
  final state0WaitingForUpdate = false.obs;
  final state0UpdateMessage = ''.obs;
  final state0UpdateRequestedAt = Rxn<DateTime>();
  final state0StatusReceivedAt = Rxn<DateTime>();

  Timer? _responseTimeout;
  Timer? _state0ResponseTimeout;
  int _responseWaitGeneration = 0;
  int _state0WaitGeneration = 0;

  bool get hasState => stateDefinitionPayloads.isNotEmpty || stateStatusPayloads.isNotEmpty;
  bool get hasSettings => settingsPayload.isNotEmpty;
  bool get hasLoggingSettings =>
      loggingSettingKeys.every(hasSetting);
  bool get hasLoggingDrafts => loggingSettingKeys.any(dirtyKeys.contains);
  int get loggingDirtyCount =>
      loggingSettingKeys.where(dirtyKeys.contains).length;
  bool get state0Active => settingBool('publish_state0', fallback: state0Definition.isNotEmpty || state0Status.isNotEmpty);
  bool get state4Active => settingBool('publish_state4', fallback: state4.isNotEmpty);
  bool get hasRestartStatus =>
      restartStatusPayload.isNotEmpty || restartLastPayload.isNotEmpty || restartValidationPayload.isNotEmpty;

  bool get restartInProgress {
    final status = restartStatusPayload['status']?.toString().trim().toLowerCase() ?? '';
    return status == 'resetting' || status == 'waiting_for_receiver' || status == 'validating';
  }

  bool get restartControlsDisabled => waitingForResponse.value || restartInProgress;

  /// True only when a State0 status was received after the most recent
  /// explicit/automatic State0 refresh request. This prevents an old retained
  /// drive_ready value from being presented as a current decision.
  bool get state0SnapshotIsCurrent {
    final requested = state0UpdateRequestedAt.value;
    final received = state0StatusReceivedAt.value;
    if (requested == null || received == null) return false;
    return !received.isBefore(requested) && state0UpdateMessage.value.isEmpty;
  }

  String get rawJson => exportJsonString();

  /// Builds the read-only GPS diagnosis snapshot used by the JSON view and by
  /// the download action. Refreshing MQTT data and downloading this snapshot
  /// intentionally remain separate actions.
  Map<String, dynamic> buildDebugExport() {
    final states = <String, dynamic>{};
    for (var stateNumber = 0; stateNumber <= 4; stateNumber++) {
      states['state$stateNumber'] = <String, dynamic>{
        'definition': _partSnapshot(
          payload: stateDefinitionPayloads[stateNumber],
          topic: stateDefinitionTopics[stateNumber] ?? 'gps_state/state$stateNumber/definition',
          receivedAt: stateDefinitionReceivedAt[stateNumber],
        ),
        'status': _partSnapshot(
          payload: stateStatusPayloads[stateNumber],
          topic: stateStatusTopics[stateNumber] ?? 'gps_state/state$stateNumber/status',
          receivedAt: stateStatusReceivedAt[stateNumber],
        ),
      };
    }

    return <String, dynamic>{
      'schema': 'openmower.gps_state_debug.v1',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'source': 'OpenMower-TAF-App',
      'snapshot_kind': 'local_app_snapshot',
      'gps_state_schema': 'gps_state.v3',
      'renew_topic': MqttConnection.gpsStateRenewJsonTopic,
      'settings_renew_topic': MqttConnection.gpsStateSettingsRenewJsonTopic,
      'app_context': <String, dynamic>{
        'last_status': lastStatus.value,
        'last_topic': lastTopic.value,
        'last_status_ok': lastStatusOk.value,
        'last_updated': lastUpdated.value?.toUtc().toIso8601String(),
        'waiting_for_response': waitingForResponse.value,
        'state0_refresh': <String, dynamic>{
          'waiting': state0WaitingForUpdate.value,
          'requested_at': state0UpdateRequestedAt.value?.toUtc().toIso8601String(),
          'status_received_at': state0StatusReceivedAt.value?.toUtc().toIso8601String(),
          'snapshot_is_current': state0SnapshotIsCurrent,
          'message': state0UpdateMessage.value,
        },
        'settings_editor': <String, dynamic>{
          'has_unsaved_changes': dirtyKeys.isNotEmpty,
          'dirty_keys': dirtyKeys.toList(growable: false)..sort(),
          'draft_values': _deepCopy(draftValues),
          'logging': <String, dynamic>{
            'backend_supported': hasLoggingSettings,
            'dirty_count': loggingDirtyCount,
            'effective_trigger': confirmedSettingValue('logging_default_trigger'),
            'effective_mode': confirmedSettingValue('logging_default_mode'),
            'effective_area_id': confirmedSettingValue('logging_default_area_id'),
          },
        },
      },
      'settings': _partSnapshot(
        payload: settingsPayload,
        topic: MqttConnection.gpsStateSettingsJsonTopic,
        receivedAt: settingsReceivedAt.value,
      ),
      'states': states,
      'auxiliary': <String, dynamic>{
        'settings_validation': _partSnapshot(
          payload: validationPayload,
          topic: MqttConnection.gpsStateValidationJsonTopic,
          receivedAt: validationReceivedAt.value,
        ),
        'restart_status': _partSnapshot(
          payload: restartStatusPayload,
          topic: MqttConnection.gpsStateRestartStatusJsonTopic,
          receivedAt: restartStatusReceivedAt.value,
        ),
        'restart_last': _partSnapshot(
          payload: restartLastPayload,
          topic: MqttConnection.gpsStateRestartLastJsonTopic,
          receivedAt: restartLastReceivedAt.value,
        ),
        'restart_validation': _partSnapshot(
          payload: restartValidationPayload,
          topic: MqttConnection.gpsStateRestartValidationJsonTopic,
          receivedAt: restartValidationReceivedAt.value,
        ),
      },
    };
  }

  String exportJsonString() => const JsonEncoder.withIndent('  ').convert(buildDebugExport());

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

  /// Requests only the GPS-State settings payload. This mirrors the renew
  /// action on the software and hardware settings screens and avoids a full
  /// State0-State4 refresh when only logging defaults are being edited.
  void requestSettings() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'GPS-State-Settings werden neu angefordert ...';
    lastTopic.value = MqttConnection.gpsStateSettingsRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine GPS-State-Settings empfangen. Bitte Topic gps_state/settings/json prüfen.',
    );
    Get.find<MqttConnection>().requestGpsStateSettings();
  }

  /// Requests only the live State0 status through the central v3 renew topic.
  void requestState0Update({bool automatic = false}) {
    final requestedAt = DateTime.now();
    state0WaitingForUpdate.value = true;
    state0UpdateRequestedAt.value = requestedAt;
    state0UpdateMessage.value = automatic
        ? 'Aktuelle State0-Werte werden beim Öffnen angefordert ...'
        : 'Aktuelle State0-Werte werden manuell angefordert ...';
    lastStatusOk.value = null;
    lastStatus.value = state0UpdateMessage.value;
    lastTopic.value = MqttConnection.gpsStateRenewJsonTopic;
    lastUpdated.value = requestedAt;
    _armState0ResponseTimeout();
    Get.find<MqttConnection>().requestGpsState0Snapshot();
  }

  void setStatePayload(int stateNumber, Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    final type = root['type']?.toString().trim().toLowerCase();
    final isDefinition = type == 'definition' || topic.endsWith('/definition');
    final isStatus = type == 'status' || topic.endsWith('/status');

    if (isDefinition) {
      _setStateDefinition(stateNumber, root, topic: topic);
    } else if (isStatus) {
      _setStateStatus(stateNumber, root, topic: topic);
    } else {
      setError(
        'GPS-State $stateNumber enthält weder type=definition noch type=status.',
        topic: topic,
      );
      return;
    }
    lastStatusOk.value = true;
    lastStatus.value = 'GPS-State $stateNumber empfangen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }


  void _setStateDefinition(int stateNumber, Map<String, dynamic> root, {required String topic}) {
    final receivedAt = DateTime.now();
    final raw = _deepCopy(root);
    stateDefinitionPayloads[stateNumber] = raw;
    stateDefinitionTopics[stateNumber] = topic;
    stateDefinitionReceivedAt[stateNumber] = receivedAt;

    switch (stateNumber) {
      case 0:
        state0Definition.assignAll(raw);
        break;
      case 1:
        state1Definition.assignAll(raw);
        break;
      case 2:
        state2Definition.assignAll(raw);
        break;
      case 3:
        state3Definition.assignAll(raw);
        break;
      case 4:
        state4Definition.assignAll(raw);
        break;
    }
  }

  void _setStateStatus(int stateNumber, Map<String, dynamic> root, {required String topic}) {
    final receivedAt = DateTime.now();
    final raw = _deepCopy(root);
    final view = _statusView(raw);
    stateStatusPayloads[stateNumber] = raw;
    stateStatusTopics[stateNumber] = topic;
    stateStatusReceivedAt[stateNumber] = receivedAt;

    switch (stateNumber) {
      case 0:
        state0Status.assignAll(view);
        state0StatusReceivedAt.value = receivedAt;
        state0WaitingForUpdate.value = false;
        state0UpdateMessage.value = '';
        _clearState0ResponseTimeout();
        break;
      case 1:
        state1Status.assignAll(view);
        state1.assignAll(view);
        break;
      case 2:
        state2Status.assignAll(view);
        state2.assignAll(view);
        break;
      case 3:
        state3Status.assignAll(view);
        state3.assignAll(view);
        break;
      case 4:
        state4Status.assignAll(view);
        state4.assignAll(view);
        break;
    }
  }

  Map<String, dynamic> _statusView(Map<String, dynamic> raw) {
    final view = _deepCopy(raw);
    final data = raw['data'];
    if (data is Map) {
      for (final entry in data.entries) {
        view[entry.key.toString()] = _deepCopyValue(entry.value);
      }
    }
    return view;
  }

  void setSettingsPayload(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    settingsPayload.assignAll(_deepCopy(root));
    settingsReceivedAt.value = DateTime.now();
    // Keep unrelated local drafts during a backend refresh, matching the
    // software and hardware settings editors. Only fields no longer published
    // by the backend are discarded.
    draftValues.removeWhere((key, value) => !hasSetting(key));
    dirtyKeys.removeWhere((key) => !hasSetting(key));
    _pendingSettingKeys.removeWhere((key) => !hasSetting(key));
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
    validationReceivedAt.value = DateTime.now();
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
      if (_pendingSettingKeys.isEmpty) {
        draftValues.clear();
        dirtyKeys.clear();
      } else {
        for (final key in _pendingSettingKeys) {
          draftValues.remove(key);
          dirtyKeys.remove(key);
        }
      }
      _pendingSettingKeys.clear();
      editorRevision.value++;
      requestSettings();
    } else {
      _pendingSettingKeys.clear();
    }
  }

  void setRestartStatus(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    restartStatusPayload.assignAll(_deepCopy(root));
    restartStatusReceivedAt.value = DateTime.now();
    final accepted = _bool(root['accepted'] ?? root['ok'] ?? root['success'], fallback: false);
    final status = root['status']?.toString();
    final normalizedStatus = status?.trim().toLowerCase() ?? '';
    final successful = normalizedStatus == 'success' || normalizedStatus == 'ok';
    final acceptedCommand = normalizedStatus == 'sent' ||
        normalizedStatus == 'requested' ||
        normalizedStatus == 'accepted' ||
        accepted;
    final inProgress = normalizedStatus == 'resetting' ||
        normalizedStatus == 'waiting_for_receiver' ||
        normalizedStatus == 'validating';
    final rejected = normalizedStatus == 'rejected' ||
        normalizedStatus == 'send_failed' ||
        normalizedStatus == 'failed' ||
        normalizedStatus == 'error';
    lastStatusOk.value = rejected
        ? false
        : successful
            ? true
            : inProgress
                ? null
                : acceptedCommand
                    ? true
                    : null;
    lastStatus.value = status == null || status.isEmpty
        ? 'F9P-Neustartstatus empfangen.'
        : 'F9P-Neustartstatus: $status';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void setRestartLast(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    restartLastPayload.assignAll(_deepCopy(root));
    restartLastReceivedAt.value = DateTime.now();
    final status = root['status']?.toString().trim().toLowerCase() ?? '';
    final successful = status == 'success' || _bool(root['receiver_restart_confirmed'], fallback: false);
    final failed = status == 'failed' || status == 'error';
    lastStatusOk.value = failed ? false : successful ? true : lastStatusOk.value;
    lastStatus.value = successful
        ? 'Letzter F9P-Neustart wurde erfolgreich bestätigt.'
        : failed
            ? 'Letzter F9P-Neustart ist fehlgeschlagen.'
            : 'Letzter abgeschlossener F9P-Neustart empfangen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    waitingForResponse.value = false;
    _clearResponseTimeout();
  }

  void setRestartValidation(Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    restartValidationPayload.assignAll(_deepCopy(root));
    restartValidationReceivedAt.value = DateTime.now();
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
    if (state0WaitingForUpdate.value && topic == MqttConnection.gpsStateRenewJsonTopic) {
      state0WaitingForUpdate.value = false;
      state0UpdateMessage.value = message;
      _clearState0ResponseTimeout();
    }
  }

  void setDraftValue(String key, dynamic value) {
    draftValues[key] = value;
    final confirmed = confirmedSettingValue(key);
    if (_valuesEqual(value, confirmed)) {
      dirtyKeys.remove(key);
      draftValues.remove(key);
    } else {
      dirtyKeys.add(key);
    }
  }

  void resetDrafts(Iterable<String> keys, {String? message}) {
    for (final key in keys) {
      draftValues.remove(key);
      dirtyKeys.remove(key);
    }
    editorRevision.value++;
    lastStatusOk.value = null;
    lastStatus.value = message ?? 'Lokale GPS-State-Entwürfe wurden zurückgesetzt.';
    lastTopic.value = 'local/reset';
    lastUpdated.value = DateTime.now();
  }

  void resetLoggingDrafts() {
    resetDrafts(
      loggingSettingKeys,
      message: 'Logging-Entwürfe wurden auf die bestätigten Backendwerte zurückgesetzt.',
    );
  }

  void applySession() {
    _publishDraft(persistent: false);
  }

  void applyPersistent() {
    _publishDraft(persistent: true);
  }

  void applyLoggingSession() {
    _publishDraft(
      persistent: false,
      onlyKeys: loggingSettingKeys,
      actionLabel: 'Logging-Einstellungen',
    );
  }

  void applyLoggingPersistent() {
    _publishDraft(
      persistent: true,
      onlyKeys: loggingSettingKeys,
      actionLabel: 'Logging-Einstellungen',
    );
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
    _pendingSettingKeys
      ..clear()
      ..add('publish_state4');
    Get.find<MqttConnection>().publishGpsStateSessionSettings(payload);
  }

  void _publishDraft({
    required bool persistent,
    Iterable<String>? onlyKeys,
    String actionLabel = 'GPS-State-Settings',
  }) {
    final candidateKeys = onlyKeys ?? dirtyKeys;
    final keys = candidateKeys.where(dirtyKeys.contains).toList(growable: false);
    if (keys.isEmpty) {
      lastStatusOk.value = null;
      lastStatus.value = 'Es gibt keine geänderten $actionLabel.';
      lastTopic.value = 'local/info';
      lastUpdated.value = DateTime.now();
      return;
    }

    final payload = <String, dynamic>{};
    for (final key in keys) {
      payload[key] = <String, dynamic>{'value': draftValues[key]};
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = persistent
        ? '$actionLabel werden dauerhaft gespeichert ...'
        : '$actionLabel werden für die Session angewendet ...';
    lastTopic.value = persistent
        ? MqttConnection.gpsStateSetPersistentJsonTopic
        : MqttConnection.gpsStateSetSessionJsonTopic;
    lastUpdated.value = DateTime.now();
    _pendingSettingKeys
      ..clear()
      ..addAll(keys);
    _armResponseTimeout('Keine GPS-State-Validierung empfangen.');
    if (persistent) {
      Get.find<MqttConnection>().publishGpsStatePersistentSettings(payload);
    } else {
      Get.find<MqttConnection>().publishGpsStateSessionSettings(payload);
    }
  }

  bool settingBool(String key, {bool fallback = false}) =>
      _bool(settingValue(key), fallback: fallback);

  double settingDouble(String key, {double fallback = 0.0}) =>
      _double(settingValue(key), fallback: fallback);

  dynamic settingValue(String key) =>
      draftValues.containsKey(key) ? draftValues[key] : confirmedSettingValue(key);

  dynamic confirmedSettingValue(String key) {
    final item = _settingItem(key);
    if (item is Map) {
      if (item.containsKey('value')) return item['value'];
      if (item.containsKey('session')) return item['session'];
      if (item.containsKey('persistent')) return item['persistent'];
      if (item.containsKey('default')) return item['default'];
    }
    return item;
  }

  dynamic persistentSettingValue(String key) {
    final item = _settingItem(key);
    if (item is Map) {
      if (item.containsKey('persistent')) return item['persistent'];
      if (item.containsKey('stored')) return item['stored'];
      if (item.containsKey('value')) return item['value'];
    }
    return item;
  }

  dynamic defaultSettingValue(String key) {
    final item = _settingItem(key);
    if (item is Map && item.containsKey('default')) {
      return item['default'];
    }
    return null;
  }

  bool hasSetting(String key) => _settingItem(key) != null;

  dynamic _settingItem(String key) {
    final direct = settingsPayload[key];
    final fromSettings = settingsPayload['settings'];
    if (direct != null) return direct;
    if (fromSettings is Map) return fromSettings[key];
    return null;
  }

  List<String> optionsFor(String key, {List<String> fallback = const <String>[]}) {
    final item = _settingMeta(key);
    final raw = item['options'] ?? item['allowed_values'] ?? item['enum'];
    if (raw is Iterable) {
      final values = <String>[];
      for (final entry in raw) {
        if (entry is Map) {
          final value = entry['value'] ?? entry['id'] ?? entry['key'];
          if (value != null && value.toString().trim().isNotEmpty) {
            values.add(value.toString());
          }
        } else if (entry != null && entry.toString().trim().isNotEmpty) {
          values.add(entry.toString());
        }
      }
      if (values.isNotEmpty) return values;
    }
    return List<String>.from(fallback);
  }

  Map<String, dynamic> buildLoggingStartPayload() {
    final payload = <String, dynamic>{
      'command': 'start',
      'request_id': 'gps-ui-${DateTime.now().millisecondsSinceEpoch}',
    };

    // New backends resolve a start request from the active GPS-State settings.
    // Older backends do not expose these settings, so retain the previous
    // explicit command as a compatibility fallback.
    if (!hasLoggingSettings) {
      payload['trigger'] = 'ad_hoc';
      payload['mode'] = 'until_docking';
    }
    return payload;
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
      case 'logging_default_trigger':
        return 'Startbedingung';
      case 'logging_default_mode':
        return 'Aufzeichnungszeitraum';
      case 'logging_default_area_id':
        return 'Zielfläche';
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
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString();
    }
    switch (key) {
      case 'logging_default_trigger':
        return 'Legt fest, wann die nächste GPS-/RTK-Aufzeichnung startet.';
      case 'logging_default_mode':
        return 'Legt fest, welcher Arbeitsabschnitt aufgezeichnet wird.';
      case 'logging_default_area_id':
        return 'Wird nur für die Startbedingung „Bestimmte Fläche“ verwendet.';
    }
    return '';
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

  dynamic _deepCopyValue(dynamic value) => jsonDecode(jsonEncode(value));

  Map<String, dynamic> _partSnapshot({
    required Map<String, dynamic>? payload,
    required String topic,
    required DateTime? receivedAt,
  }) {
    final available = payload != null && payload.isNotEmpty;
    return <String, dynamic>{
      'topic': topic,
      'received_at': receivedAt?.toUtc().toIso8601String(),
      'available': available,
      'payload': available ? _deepCopy(payload!) : <String, dynamic>{},
    };
  }

  bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a is num && b is num) return a.toDouble() == b.toDouble();
    return a?.toString() == b?.toString();
  }

  bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized == 'null') return fallback;
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on' ||
        normalized == 'ok' ||
        normalized == 'success' ||
        normalized == 'accepted' ||
        normalized == 'ready';
  }

  double _double(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _armState0ResponseTimeout() {
    _state0ResponseTimeout?.cancel();
    final generation = ++_state0WaitGeneration;
    _state0ResponseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _state0WaitGeneration) return;
      state0WaitingForUpdate.value = false;
      state0UpdateMessage.value =
          'Keine neue State0-Statusantwort empfangen. Der angezeigte Stand wird nicht als aktuell gewertet.';
      lastStatusOk.value = null;
      lastStatus.value = state0UpdateMessage.value;
      lastUpdated.value = DateTime.now();
    });
  }

  void _clearState0ResponseTimeout() {
    _state0ResponseTimeout?.cancel();
    _state0ResponseTimeout = null;
    _state0WaitGeneration++;
  }

  @override
  void onClose() {
    _responseTimeout?.cancel();
    _state0ResponseTimeout?.cancel();
    super.onClose();
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
