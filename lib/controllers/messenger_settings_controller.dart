import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

enum MessengerSurface { bot, waha }

class MessengerSettingsController extends GetxController {
  static const Duration responseTimeout = Duration(seconds: 8);

  final botSnapshot = <String, dynamic>{}.obs;
  final wahaSnapshot = <String, dynamic>{}.obs;
  final botValidation = <String, dynamic>{}.obs;
  final wahaValidation = <String, dynamic>{}.obs;
  final botEvents = <String, dynamic>{}.obs;
  final botPendingConfirmations = <String, dynamic>{}.obs;

  final botSettingDrafts = <String, dynamic>{}.obs;
  final wahaSettingDrafts = <String, dynamic>{}.obs;
  final botFlowDrafts = <String, dynamic>{}.obs;
  final botDirtySettings = <String>{}.obs;
  final wahaDirtySettings = <String>{}.obs;
  final botDirtyFlows = <String>{}.obs;

  final botWaitingMode = ''.obs;
  final wahaWaitingMode = ''.obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastUpdated = Rxn<DateTime>();

  Timer? _botTimer;
  Timer? _wahaTimer;

  bool get hasBotSnapshot => botSnapshot.isNotEmpty;
  bool get hasWahaSnapshot => wahaSnapshot.isNotEmpty;
  bool get hasQrCode => qrCodeData != null;
  int get dirtyCount => botDirtySettings.length + wahaDirtySettings.length + botDirtyFlows.length;

  String get botState => _statusValue(MessengerSurface.bot, 'state');
  String get wahaState => _statusValue(MessengerSurface.waha, 'state');

  String? get qrCodeData {
    final status = statusFor(MessengerSurface.waha);
    final connected = _bool(status['connected']);
    final authRequired = _bool(status['authentication_required']);
    final available = _bool(status['qr_code_available']);
    final raw = status['QR_Code_Data'];
    if (connected || !authRequired || !available || raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Map<String, dynamic> snapshotFor(MessengerSurface surface) =>
      surface == MessengerSurface.bot ? botSnapshot : wahaSnapshot;

  Map<String, dynamic> validationFor(MessengerSurface surface) =>
      surface == MessengerSurface.bot ? botValidation : wahaValidation;

  Map<String, dynamic> statusFor(MessengerSurface surface) =>
      _map(snapshotFor(surface)['status']);

  Map<String, dynamic> metaFor(MessengerSurface surface) =>
      _map(snapshotFor(surface)['meta']);

  Map<String, Map<String, dynamic>> settingsFor(MessengerSurface surface) =>
      _mapOfMaps(snapshotFor(surface)['settings']);

  Map<String, Map<String, dynamic>> flowsForBot() => _mapOfMaps(botSnapshot['flows']);

  bool isWaiting(MessengerSurface surface) => waitingMode(surface).isNotEmpty;

  String waitingMode(MessengerSurface surface) =>
      surface == MessengerSurface.bot ? botWaitingMode.value : wahaWaitingMode.value;

  int differenceCount(MessengerSurface surface) => settingsFor(surface)
      .values
      .where((entry) => _bool(entry['different']) || !_same(entry['active'], entry['persistent']))
      .length;

  List<String> groups(MessengerSurface surface, {required bool expertMode}) {
    final result = settingsFor(surface)
        .values
        .where((setting) => expertMode || !_bool(setting['expert']))
        .map((setting) => (setting['group'] ?? 'general').toString())
        .toSet()
        .toList();
    result.sort((a, b) {
      final order = groupOrder(surface, a).compareTo(groupOrder(surface, b));
      return order == 0 ? a.compareTo(b) : order;
    });
    return result;
  }

  List<MapEntry<String, Map<String, dynamic>>> entriesForGroup(
    MessengerSurface surface,
    String group, {
    required bool expertMode,
  }) {
    final entries = settingsFor(surface)
        .entries
        .where((entry) => (entry.value['group'] ?? 'general').toString() == group)
        .where((entry) => expertMode || !_bool(entry.value['expert']))
        .toList();
    entries.sort((a, b) {
      final order = (_int(a.value['order']) ?? 9999).compareTo(_int(b.value['order']) ?? 9999);
      return order == 0 ? a.key.compareTo(b.key) : order;
    });
    return entries;
  }

  String groupLabel(MessengerSurface surface, String group) {
    final descriptor = _groupDescriptor(surface, group);
    final label = descriptor['label'] ?? descriptor['name'] ?? descriptor['title'];
    if (label != null && label.toString().trim().isNotEmpty) return label.toString();
    return const <String, String>{
          'general': 'Allgemein',
          'messenger': 'Messenger',
          'notifications': 'Benachrichtigungen',
          'commands': 'Befehle und Flows',
          'session': 'Session',
          'repair': 'Automatische Reparatur',
        }[group] ??
        group;
  }

  IconData groupIcon(String group) => const <String, IconData>{
        'general': Icons.tune,
        'messenger': Icons.groups_outlined,
        'notifications': Icons.notifications_active_outlined,
        'commands': Icons.account_tree_outlined,
        'session': Icons.chat_outlined,
        'repair': Icons.build_circle_outlined,
      }[group] ?? Icons.settings_outlined;

  int groupOrder(MessengerSurface surface, String group) {
    final descriptor = _groupDescriptor(surface, group);
    final order = _int(descriptor['order']);
    if (order != null) return order;
    return const <String, int>{
          'general': 100,
          'messenger': 200,
          'notifications': 300,
          'session': 400,
          'repair': 500,
          'commands': 600,
        }[group] ??
        9999;
  }

  dynamic settingValue(MessengerSurface surface, String key) {
    final drafts = _settingDrafts(surface);
    if (drafts.containsKey(key)) return drafts[key];
    final setting = settingsFor(surface)[key];
    return setting == null ? null : _initialValue(setting);
  }

  dynamic flowValue(String key) {
    if (botFlowDrafts.containsKey(key)) return botFlowDrafts[key];
    final flow = flowsForBot()[key];
    return flow == null ? null : _initialValue(flow);
  }

  bool isSettingDirty(MessengerSurface surface, String key) => _dirtySettings(surface).contains(key);
  bool isFlowDirty(String key) => botDirtyFlows.contains(key);

  void updateSettingDraft(MessengerSurface surface, String key, dynamic value) {
    final setting = settingsFor(surface)[key];
    if (setting == null || _bool(setting['readonly'])) return;
    final drafts = _settingDrafts(surface);
    final dirty = _dirtySettings(surface);
    final original = _initialValue(setting);
    if (_same(original, value)) {
      drafts.remove(key);
      dirty.remove(key);
    } else {
      drafts[key] = value;
      dirty.add(key);
    }
    drafts.refresh();
    dirty.refresh();
  }

  void updateFlowDraft(String key, bool value) {
    final flow = flowsForBot()[key];
    if (flow == null || _bool(flow['readonly'])) return;
    final original = _bool(_initialValue(flow));
    if (original == value) {
      botFlowDrafts.remove(key);
      botDirtyFlows.remove(key);
    } else {
      botFlowDrafts[key] = value;
      botDirtyFlows.add(key);
    }
    botFlowDrafts.refresh();
    botDirtyFlows.refresh();
  }

  void discardSettings(MessengerSurface surface, {String? group}) {
    final drafts = _settingDrafts(surface);
    final dirty = _dirtySettings(surface);
    if (group == null) {
      drafts.clear();
      dirty.clear();
      return;
    }
    final keys = settingsFor(surface)
        .entries
        .where((entry) => (entry.value['group'] ?? 'general').toString() == group)
        .map((entry) => entry.key)
        .toSet();
    drafts.removeWhere((key, _) => keys.contains(key));
    dirty.removeWhere(keys.contains);
  }

  void discardFlows() {
    botFlowDrafts.clear();
    botDirtyFlows.clear();
  }

  bool canApplySession(MessengerSurface surface, {String? group, bool includeFlows = false}) {
    final settings = settingsFor(surface);
    final hasSetting = _dirtySettings(surface).any((key) {
      final setting = settings[key];
      if (setting == null) return false;
      if (group != null && (setting['group'] ?? 'general').toString() != group) return false;
      return !_bool(setting['readonly']) && _boolDefault(setting['session_apply_supported'], true);
    });
    if (hasSetting) return true;
    if (surface == MessengerSurface.bot && includeFlows) {
      final flows = flowsForBot();
      return botDirtyFlows.any((key) {
        final flow = flows[key];
        return flow != null && !_bool(flow['readonly']) && _boolDefault(flow['session_apply_supported'], true);
      });
    }
    return false;
  }

  bool hasPersistentChanges(MessengerSurface surface, {String? group, bool includeFlows = false}) {
    final settings = settingsFor(surface);
    final hasSetting = _dirtySettings(surface).any((key) {
      final setting = settings[key];
      if (setting == null) return false;
      if (group != null && (setting['group'] ?? 'general').toString() != group) return false;
      return !_bool(setting['readonly']);
    });
    if (hasSetting) return true;
    return surface == MessengerSurface.bot && includeFlows && botDirtyFlows.isNotEmpty;
  }

  Map<String, dynamic> buildWritePayload(
    MessengerSurface surface, {
    String? group,
    required bool session,
    bool includeFlows = false,
  }) {
    final payload = <String, dynamic>{};
    final settingsPayload = <String, dynamic>{};
    final settings = settingsFor(surface);
    for (final key in _dirtySettings(surface)) {
      final meta = settings[key];
      if (meta == null || _bool(meta['readonly'])) continue;
      if (group != null && (meta['group'] ?? 'general').toString() != group) continue;
      if (session && !_boolDefault(meta['session_apply_supported'], true)) continue;
      final value = _settingDrafts(surface)[key];
      if (_validateValue(surface, key, meta, value) != null) continue;
      settingsPayload[key] = <String, dynamic>{'value': value};
    }
    if (settingsPayload.isNotEmpty) payload['settings'] = settingsPayload;

    if (surface == MessengerSurface.bot && includeFlows) {
      final flowPayload = <String, dynamic>{};
      final flows = flowsForBot();
      for (final key in botDirtyFlows) {
        final meta = flows[key];
        if (meta == null || _bool(meta['readonly'])) continue;
        if (session && !_boolDefault(meta['session_apply_supported'], true)) continue;
        flowPayload[key] = <String, dynamic>{'value': _bool(botFlowDrafts[key])};
      }
      if (flowPayload.isNotEmpty) payload['flows'] = flowPayload;
    }
    return payload;
  }

  String? validationErrorFor(MessengerSurface surface, String key) {
    final setting = settingsFor(surface)[key];
    if (setting == null || !_settingDrafts(surface).containsKey(key)) return null;
    return _validateValue(surface, key, setting, _settingDrafts(surface)[key]);
  }

  void request(MessengerSurface surface) {
    _beginWait(surface, 'renew');
    final mqtt = Get.find<MqttConnection>();
    if (surface == MessengerSurface.bot) {
      mqtt.requestMessengerBot();
    } else {
      mqtt.requestMessengerWaha();
    }
  }

  void requestAll() {
    request(MessengerSurface.bot);
    request(MessengerSurface.waha);
  }

  void requestGroupOptions() => request(MessengerSurface.bot);

  void applySession(MessengerSurface surface, {String? group, bool includeFlows = false}) {
    final error = _firstValidationError(surface, group: group);
    if (error != null) {
      lastStatus.value = error;
      return;
    }
    final payload = buildWritePayload(surface, group: group, session: true, includeFlows: includeFlows);
    if (payload.isEmpty) {
      lastStatus.value = 'Keine session-fähigen Änderungen zum Senden.';
      return;
    }
    _beginWait(surface, 'session');
    final mqtt = Get.find<MqttConnection>();
    if (surface == MessengerSurface.bot) {
      mqtt.publishMessengerBotSession(payload);
    } else {
      mqtt.publishMessengerWahaSession(payload);
    }
  }

  void applyPersistent(MessengerSurface surface, {String? group, bool includeFlows = false}) {
    final error = _firstValidationError(surface, group: group);
    if (error != null) {
      lastStatus.value = error;
      return;
    }
    final payload = buildWritePayload(surface, group: group, session: false, includeFlows: includeFlows);
    if (payload.isEmpty) {
      lastStatus.value = 'Keine Änderungen zum dauerhaften Speichern.';
      return;
    }
    _beginWait(surface, 'persistent');
    final mqtt = Get.find<MqttConnection>();
    if (surface == MessengerSurface.bot) {
      mqtt.publishMessengerBotPersistent(payload);
    } else {
      mqtt.publishMessengerWahaPersistent(payload);
    }
  }

  void setSnapshot(MessengerSurface surface, Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    final error = _schemaError(surface, root);
    if (error != null) {
      lastTopic.value = topic;
      lastStatus.value = error;
      return;
    }

    if (surface == MessengerSurface.waha) {
      final status = _map(root['status']);
      if (!_bool(status['authentication_required']) || !_bool(status['qr_code_available']) || _bool(status['connected'])) {
        status['QR_Code_Data'] = null;
        root['status'] = status;
      }
      wahaSnapshot.assignAll(root);
    } else {
      botSnapshot.assignAll(root);
    }

    _reconcileDrafts(surface);
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    if (waitingMode(surface) == 'renew') _finishWait(surface);
  }

  void setValidation(MessengerSurface surface, Map<String, dynamic> payload, {required String topic}) {
    final root = _root(payload);
    if (surface == MessengerSurface.bot) {
      botValidation.assignAll(root);
    } else {
      wahaValidation.assignAll(root);
    }
    _applyAccepted(surface, root['accepted']);
    _finishWait(surface);
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    lastStatus.value = _validationSummary(root);
  }

  void setBotRuntime(String topic, Map<String, dynamic> payload) {
    final root = _root(payload);
    if (topic == MqttConnection.messengerBotEventsJsonTopic) {
      botEvents.assignAll(root);
    } else if (topic == MqttConnection.messengerBotPendingConfirmationsJsonTopic) {
      botPendingConfirmations.assignAll(root);
    }
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  String prettyJsonSafe(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(_redact(value));
    } catch (_) {
      return _redact(value).toString();
    }
  }

  @override
  void onClose() {
    _botTimer?.cancel();
    _wahaTimer?.cancel();
    super.onClose();
  }

  RxMap<String, dynamic> _settingDrafts(MessengerSurface surface) =>
      surface == MessengerSurface.bot ? botSettingDrafts : wahaSettingDrafts;

  RxSet<String> _dirtySettings(MessengerSurface surface) =>
      surface == MessengerSurface.bot ? botDirtySettings : wahaDirtySettings;

  String _statusValue(MessengerSurface surface, String key) =>
      (statusFor(surface)[key] ?? '').toString();

  dynamic _initialValue(Map<String, dynamic> meta) {
    if (meta.containsKey('value')) return meta['value'];
    if (meta.containsKey('active')) return meta['active'];
    return meta['persistent'];
  }

  String? _firstValidationError(MessengerSurface surface, {String? group}) {
    final settings = settingsFor(surface);
    for (final key in _dirtySettings(surface)) {
      final meta = settings[key];
      if (meta == null) continue;
      if (group != null && (meta['group'] ?? 'general').toString() != group) continue;
      final error = _validateValue(surface, key, meta, _settingDrafts(surface)[key]);
      if (error != null) return error;
    }
    return null;
  }

  String? _validateValue(MessengerSurface surface, String key, Map<String, dynamic> meta, dynamic value) {
    final type = (meta['type'] ?? '').toString().toLowerCase();
    if (type == 'bool' || type == 'boolean') {
      if (value is! bool) return '${meta['label'] ?? key}: boolescher Wert erforderlich.';
    } else if (type == 'int' || type == 'integer') {
      if (value is! int) return '${meta['label'] ?? key}: Ganzzahl erforderlich.';
    } else if (type == 'string') {
      if (value is! String) return '${meta['label'] ?? key}: Textwert erforderlich.';
    }

    if (value is num) {
      final min = _num(meta['min']);
      final max = _num(meta['max']);
      if (min != null && value < min) return '${meta['label'] ?? key}: Mindestwert ist $min.';
      if (max != null && value > max) return '${meta['label'] ?? key}: Höchstwert ist $max.';
    }

    final options = optionItems(meta);
    if (options.isNotEmpty && !options.any((option) => _same(option.value, value))) {
      return '${meta['label'] ?? key}: nur ein aktuell gelieferter Auswahlwert ist zulässig.';
    }

    if ((surface == MessengerSurface.bot && key == 'wake_word') ||
        (surface == MessengerSurface.waha && key == 'session')) {
      if (value is! String || value.trim().isEmpty) return '${meta['label'] ?? key}: darf nicht leer sein.';
    }
    return null;
  }

  List<MessengerOption> optionItems(Map<String, dynamic> meta) {
    final raw = meta['options'];
    if (raw is! List) return const <MessengerOption>[];
    final result = <MessengerOption>[];
    for (final item in raw) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (!map.containsKey('value')) continue;
        result.add(MessengerOption(map['value'], (map['label'] ?? map['value']).toString()));
      } else {
        result.add(MessengerOption(item, item.toString()));
      }
    }
    return result;
  }

  Map<String, dynamic> _groupDescriptor(MessengerSurface surface, String group) {
    final raw = metaFor(surface)['groups'];
    if (raw is Map) {
      final value = raw[group];
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is num) return <String, dynamic>{'order': value};
      if (value != null) return <String, dynamic>{'label': value.toString()};
    }
    if (raw is List) {
      for (var index = 0; index < raw.length; index++) {
        final value = raw[index];
        if (value is String && value == group) return <String, dynamic>{'order': index};
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          final id = map['key'] ?? map['id'] ?? map['group'] ?? map['value'] ?? map['name'];
          if (id?.toString() == group) return <String, dynamic>{'order': index, ...map};
        }
      }
    }
    return const <String, dynamic>{};
  }

  void _reconcileDrafts(MessengerSurface surface) {
    final settings = settingsFor(surface);
    final drafts = _settingDrafts(surface);
    final dirty = _dirtySettings(surface);
    final resolved = <String>[];
    for (final key in dirty) {
      final meta = settings[key];
      if (meta == null || _same(_initialValue(meta), drafts[key])) resolved.add(key);
    }
    for (final key in resolved) {
      drafts.remove(key);
      dirty.remove(key);
    }

    if (surface == MessengerSurface.bot) {
      final flows = flowsForBot();
      final resolvedFlows = <String>[];
      for (final key in botDirtyFlows) {
        final flow = flows[key];
        if (flow == null || _same(_initialValue(flow), botFlowDrafts[key])) resolvedFlows.add(key);
      }
      for (final key in resolvedFlows) {
        botFlowDrafts.remove(key);
        botDirtyFlows.remove(key);
      }
    }
  }

  void _applyAccepted(MessengerSurface surface, dynamic accepted) {
    if (accepted is! Map) return;
    final acceptedMap = Map<String, dynamic>.from(accepted);
    final settingsAccepted = acceptedMap['settings'];
    if (settingsAccepted is Map) {
      for (final key in settingsAccepted.keys.map((key) => key.toString())) {
        _settingDrafts(surface).remove(key);
        _dirtySettings(surface).remove(key);
      }
    }
    if (surface == MessengerSurface.bot && acceptedMap['flows'] is Map) {
      final flowsAccepted = Map<dynamic, dynamic>.from(acceptedMap['flows'] as Map);
      for (final key in flowsAccepted.keys.map((key) => key.toString())) {
        botFlowDrafts.remove(key);
        botDirtyFlows.remove(key);
      }
    }
  }

  String _validationSummary(Map<String, dynamic> root) {
    final remarks = root['remarks'];
    final messages = <String>[];
    if (remarks is List) {
      messages.addAll(remarks.where((item) => item != null).map((item) => item.toString()));
    }
    final rejected = root['rejected'];
    final rejectedCount = rejected is Map ? rejected.length : 0;
    if (rejectedCount > 0) messages.add('$rejectedCount Bereich(e) abgelehnt.');
    if (messages.isNotEmpty) return messages.join(' ');
    final mode = (root['mode'] ?? '').toString();
    final valid = _bool(root['valid']);
    return valid ? 'Messenger-$mode erfolgreich bestätigt.' : 'Messenger-$mode wurde nicht vollständig bestätigt.';
  }

  String? _schemaError(MessengerSurface surface, Map<String, dynamic> root) {
    final expectedNamespace = surface == MessengerSurface.bot ? 'messenger_bot' : 'messenger_waha';
    final expectedSchema = surface == MessengerSurface.bot ? 'bot_v1' : 'waha_v1';
    if (root['namespace']?.toString() != expectedNamespace ||
        root['schema']?.toString() != expectedSchema ||
        root['schema_version']?.toString() != '1.0') {
      return 'Nicht unterstütztes Messenger-Schema. Erwartet: $expectedNamespace / $expectedSchema / 1.0.';
    }
    if (root['settings'] is! Map || root['status'] is! Map) {
      return 'Ungültiger Messenger-Snapshot: status/settings fehlen.';
    }
    if (surface == MessengerSurface.bot && root['flows'] is! Map) {
      return 'Ungültiger Bot-Snapshot: flows fehlt.';
    }
    return null;
  }

  void _beginWait(MessengerSurface surface, String mode) {
    _timerFor(surface)?.cancel();
    _setWaitingMode(surface, mode);
    lastStatus.value = mode == 'renew' ? 'Messenger-Status wird neu angefordert …' : 'Messenger-$mode wurde gesendet …';
    final timer = Timer(responseTimeout, () {
      if (waitingMode(surface) == mode) {
        _setWaitingMode(surface, '');
        lastStatus.value = 'Keine passende Backend-Antwort innerhalb von 8 Sekunden. Der nächste Snapshot kann den Zustand weiterhin aktualisieren.';
      }
    });
    if (surface == MessengerSurface.bot) {
      _botTimer = timer;
    } else {
      _wahaTimer = timer;
    }
  }

  void _finishWait(MessengerSurface surface) {
    _timerFor(surface)?.cancel();
    _setWaitingMode(surface, '');
  }

  Timer? _timerFor(MessengerSurface surface) => surface == MessengerSurface.bot ? _botTimer : _wahaTimer;

  void _setWaitingMode(MessengerSurface surface, String value) {
    if (surface == MessengerSurface.bot) {
      botWaitingMode.value = value;
    } else {
      wahaWaitingMode.value = value;
    }
  }

  Map<String, dynamic> _root(Map<String, dynamic> payload) =>
      payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : Map<String, dynamic>.from(payload);

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Map<String, Map<String, dynamic>> _mapOfMaps(dynamic value) {
    final result = <String, Map<String, dynamic>>{};
    if (value is Map) {
      value.forEach((key, entry) {
        if (entry is Map) result[key.toString()] = Map<String, dynamic>.from(entry);
      });
    }
    return result;
  }

  dynamic _redact(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, item) {
        result[key.toString()] = key.toString() == 'QR_Code_Data' && item != null ? '<redacted>' : _redact(item);
      });
      return result;
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }

  bool _same(dynamic a, dynamic b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return a == b;
    }
  }

  bool _bool(dynamic value) =>
      value == true || value == 1 || value?.toString().toLowerCase().trim() == 'true' || value?.toString().toLowerCase().trim() == 'on';

  bool _boolDefault(dynamic value, bool fallback) => value == null ? fallback : _bool(value);
  int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  num? _num(dynamic value) => value is num ? value : num.tryParse(value?.toString() ?? '');
}

class MessengerOption {
  const MessengerOption(this.value, this.label);

  final dynamic value;
  final String label;
}
