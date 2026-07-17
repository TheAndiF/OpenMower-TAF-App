import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class MessengerSettingsController extends GetxController {
  final settings = <String, Map<String, dynamic>>{}.obs;
  final drafts = <String, dynamic>{}.obs;
  final dirtyKeys = <String>{}.obs;
  final runtime = <String, Map<String, dynamic>>{}.obs;
  final diagnostics = <String, Map<String, dynamic>>{}.obs;
  final actions = <Map<String, dynamic>>[].obs;
  final lastValidation = <String, dynamic>{}.obs;
  final lastUpdated = Rxn<DateTime>();
  final lastStatus = ''.obs;

  bool get hasSettings => settings.isNotEmpty;
  int get dirtyCount => dirtyKeys.length;
  int get differenceCount => settings.entries.where((e) => _different(e.value)).length;

  List<String> groups({required bool expertMode}) {
    final result = settings.values
        .where((s) => expertMode || !_bool(s['expert']))
        .where((s) => _boolDefault(s['visible'], true))
        .map((s) => (s['group'] ?? 'general').toString())
        .toSet()
        .toList();
    result.sort((a, b) => groupOrder(a).compareTo(groupOrder(b)));
    return result;
  }

  List<MapEntry<String, Map<String, dynamic>>> entriesForGroup(String group, {required bool expertMode}) {
    final result = settings.entries
        .where((e) => (e.value['group'] ?? 'general').toString() == group)
        .where((e) => expertMode || !_bool(e.value['expert']))
        .where((e) => _boolDefault(e.value['visible'], true))
        .toList();
    result.sort((a, b) {
      final ao = _int(a.value['order']) ?? 9999;
      final bo = _int(b.value['order']) ?? 9999;
      final c = ao.compareTo(bo);
      return c == 0 ? a.key.compareTo(b.key) : c;
    });
    return result;
  }

  String groupLabel(String group) => const <String, String>{
        'general': 'Allgemein',
        'connection': 'WAHA-Verbindung',
        'session': 'WhatsApp-Session',
        'bot': 'Mobert-Bot',
        'groups': 'Gruppen und Ziele',
        'status_push': 'Automatische Statusmeldungen',
        'messages': 'Nachrichtenverlauf',
        'repair': 'Automatische Reparatur',
        'commands': 'Befehle und Flows',
        'security': 'Sicherheit',
      }[group] ?? group;

  IconData groupIcon(String group) => const <String, IconData>{
        'general': Icons.tune,
        'connection': Icons.hub_outlined,
        'session': Icons.chat_outlined,
        'bot': Icons.smart_toy_outlined,
        'groups': Icons.groups_outlined,
        'status_push': Icons.notifications_active_outlined,
        'messages': Icons.history_outlined,
        'repair': Icons.build_circle_outlined,
        'commands': Icons.account_tree_outlined,
        'security': Icons.security_outlined,
      }[group] ?? Icons.settings_outlined;

  int groupOrder(String group) => const <String, int>{
        'general': 10,
        'connection': 20,
        'session': 30,
        'bot': 40,
        'groups': 50,
        'status_push': 60,
        'messages': 70,
        'repair': 80,
        'commands': 90,
        'security': 100,
      }[group] ?? 999;

  dynamic valueFor(String key) => drafts.containsKey(key) ? drafts[key] : settings[key]?['value'];
  bool isDirty(String key) => dirtyKeys.contains(key);

  void updateDraft(String key, dynamic value) {
    drafts[key] = value;
    final original = settings[key]?['value'];
    if (_same(original, value)) {
      dirtyKeys.remove(key);
      drafts.remove(key);
    } else {
      dirtyKeys.add(key);
    }
    drafts.refresh();
    dirtyKeys.refresh();
  }

  void discard({String? group}) {
    if (group == null) {
      drafts.clear();
      dirtyKeys.clear();
      return;
    }
    final keys = entriesForGroup(group, expertMode: true).map((e) => e.key).toSet();
    drafts.removeWhere((key, _) => keys.contains(key));
    dirtyKeys.removeWhere(keys.contains);
  }

  void setSettingsPayload(Map<String, dynamic> payload) {
    final root = _root(payload);
    final raw = root['settings'];
    if (raw is! Map) return;
    final next = <String, Map<String, dynamic>>{};
    raw.forEach((key, value) {
      if (value is Map) next[key.toString()] = Map<String, dynamic>.from(value);
    });
    settings.assignAll(next);
    drafts.clear();
    dirtyKeys.clear();
    lastUpdated.value = DateTime.now();
    lastStatus.value = 'Messenger-Einstellungen aktualisiert.';
  }

  void setRuntimePayload(String topic, Map<String, dynamic> payload) {
    runtime[topic] = _root(payload);
    lastUpdated.value = DateTime.now();
  }

  void setDiagnosticPayload(String topic, Map<String, dynamic> payload) {
    diagnostics[topic] = _root(payload);
    lastUpdated.value = DateTime.now();
  }

  void setActionsPayload(Map<String, dynamic> payload) {
    final root = payload['d'] ?? payload;
    final list = root is List ? root : (root is Map ? root['actions'] : null);
    if (list is List) {
      actions.assignAll(list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    }
  }

  void setValidation(Map<String, dynamic> payload) {
    lastValidation.assignAll(_root(payload));
    lastUpdated.value = DateTime.now();
  }

  Map<String, dynamic> _changes({String? group}) {
    final result = <String, dynamic>{};
    for (final key in dirtyKeys) {
      if (group != null && (settings[key]?['group'] ?? 'general').toString() != group) continue;
      result[key] = drafts[key];
    }
    return result;
  }

  void requestAll() => Get.find<MqttConnection>().requestMessengerSettings();

  void applySession({String? group}) {
    final changes = _changes(group: group);
    if (changes.isEmpty) return;
    Get.find<MqttConnection>().publishMessengerSessionSettings({'settings': changes});
    lastStatus.value = 'Messenger-Sessionänderungen gesendet.';
  }

  void applyPersistent({String? group}) {
    final changes = _changes(group: group);
    if (changes.isEmpty) return;
    Get.find<MqttConnection>().publishMessengerPersistentSettings({'settings': changes});
    lastStatus.value = 'Dauerhafte Messenger-Änderungen gesendet.';
  }

  void runAction(String actionId) {
    Get.find<MqttConnection>().publishMessengerAction(actionId);
    lastStatus.value = 'Aktion gesendet: $actionId';
  }

  String prettyJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Map<String, dynamic> _root(Map<String, dynamic> payload) =>
      payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;

  bool _different(Map<String, dynamic> s) => _bool(s['different']) || !_same(s['active'], s['persistent']);
  bool _same(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);
  bool _bool(dynamic v) => v == true || v == 1 || v?.toString().toLowerCase() == 'true' || v?.toString().toLowerCase() == 'on';
  bool _boolDefault(dynamic v, bool fallback) => v == null ? fallback : _bool(v);
  int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
}
