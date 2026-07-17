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
  final qrCode = <String, dynamic>{}.obs;

  bool get hasSettings => settings.isNotEmpty;
  bool get hasQrCode => qrCode.isNotEmpty;
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

  void ensureFallbackSettings() {
    if (settings.isNotEmpty) return;
    final session = runtime['messenger/waha/session/json'] ?? const <String, dynamic>{};
    final waha = runtime['messenger/waha/json'] ?? const <String, dynamic>{};
    final bot = runtime['messenger/bot/json'] ?? const <String, dynamic>{};
    final listener = runtime['messenger/bot/listener/json'] ?? const <String, dynamic>{};
    final groups = runtime['messenger/waha/groups/json'] ?? const <String, dynamic>{};
    final push = runtime['messenger/bot/status_push/json'] ?? const <String, dynamic>{};
    final messages = diagnostics['messenger/waha/messages/json'] ?? const <String, dynamic>{};
    final repair = diagnostics['messenger/waha/session/repair/json'] ??
        (session['repair'] is Map ? Map<String, dynamic>.from(session['repair']) : const <String, dynamic>{});
    final defaultGroup = groups['default_group'] is Map ? Map<String, dynamic>.from(groups['default_group']) : const <String, dynamic>{};
    final listenerGroup = listener['group'] is Map ? Map<String, dynamic>.from(listener['group']) : const <String, dynamic>{};
    final targetGroup = push['target_group'] ?? push['target'] ?? defaultGroup['alias'];
    settings.assignAll(<String, Map<String, dynamic>>{
      'messenger_enabled': _meta('Messenger aktiviert', 'Aktiviert die Messenger-Funktion.', 'general', 10, 'bool', true),
      'waha_enabled': _meta('WAHA aktiviert', 'Aktiviert die WhatsApp-Bridge.', 'connection', 10, 'bool', waha['enabled'] ?? true),
      'waha_api_url': _meta('WAHA-API-URL', 'Interne Adresse der WAHA-API.', 'connection', 20, 'string', waha['url'] ?? 'http://waha:3000', expert: true),
      'session_name': _meta('Sessionname', 'Name der verwendeten WhatsApp-Session.', 'session', 10, 'string', session['name'] ?? ''),
      'bot_enabled': _meta('Mobert-Bot aktiviert', 'Aktiviert die Bot-Befehlsverarbeitung.', 'bot', 10, 'bool', bot['enabled'] ?? true),
      'wake_word': _meta('Wake Word', 'Präfix für Messenger-Befehle.', 'bot', 20, 'string', listener['wake_word'] ?? 'Mobert'),
      'wake_word_required': _meta('Wake Word erforderlich', 'Befehle werden nur mit Wake Word erkannt.', 'bot', 30, 'bool', true),
      'wake_word_case_sensitive': _meta('Groß-/Kleinschreibung beachten', 'Vergleicht das Wake Word unter Beachtung der Schreibweise.', 'bot', 40, 'bool', false, expert: true),
      'wake_word_syntax': _meta('Wake-Word-Syntax', 'Syntax zwischen Wake Word und Befehl.', 'bot', 50, 'enum', 'colon', expert: true, options: const ['colon']),
      'default_group': _meta('Standard-Zielgruppe', 'Standardgruppe für Antworten und Meldungen.', 'groups', 10, 'string', defaultGroup['alias'] ?? ''),
      'listener_group': _meta('Lauschgruppe', 'Gruppe, in der Mobert auf Befehle lauscht.', 'groups', 20, 'string', listenerGroup['alias'] ?? ''),
      'status_push_enabled': _meta('Automatischer Status aktiviert', 'Sendet regelmäßig den OpenMower-Status.', 'status_push', 10, 'bool', push['enabled'] ?? false),
      'status_push_interval_minutes': _meta('Statusintervall', 'Intervall automatischer Statusmeldungen.', 'status_push', 20, 'int', push['interval_minutes'] ?? 30, unit: 'min', min: 5, max: 1440),
      'status_push_target_group': _meta('Status-Zielgruppe', 'Zielgruppe der automatischen Statusmeldungen.', 'status_push', 30, 'string', targetGroup ?? ''),
      'append_status_to_confirmations': _meta('Status nach Befehl anhängen', 'Hängt den OpenMower-Status an Befehlsbestätigungen an.', 'status_push', 40, 'bool', false),
      'message_history_enabled': _meta('Nachrichtenverlauf aktiviert', 'Speichert die begrenzte Ein- und Ausgangshistorie.', 'messages', 10, 'bool', messages['enabled'] ?? true),
      'message_history_limit': _meta('Verlaufslimit', 'Maximale Anzahl gespeicherter Verlaufseinträge.', 'messages', 20, 'int', messages['limit'] ?? 10, expert: true, min: 1, max: 100),
      'repair_enabled': _meta('Reparatur-Watchdog aktiviert', 'Überwacht und repariert die WAHA-Session.', 'repair', 10, 'bool', repair['enabled'] ?? true, expert: true),
      'repair_start_stopped_session': _meta('Gestoppte Session automatisch starten', 'Startet eine gestoppte Session automatisch.', 'repair', 20, 'bool', repair['start_stopped_session'] ?? true, expert: true),
      'repair_starting_timeout_seconds': _meta('Start-Timeout', 'Maximale Startdauer der Session.', 'repair', 30, 'int', repair['starting_timeout_seconds'] ?? 90, unit: 's', expert: true, min: 10, max: 600),
      'repair_cooldown_seconds': _meta('Reparatur-Cooldown', 'Pause zwischen Reparaturversuchen.', 'repair', 40, 'int', repair['repair_cooldown_seconds'] ?? 300, unit: 's', expert: true, min: 10, max: 3600),
      'repair_max_restarts_per_hour': _meta('Maximale Neustarts pro Stunde', 'Begrenzt automatische Session-Neustarts.', 'repair', 50, 'int', repair['max_restarts_per_hour'] ?? 3, expert: true, min: 0, max: 20),
      'repair_send_ready_wait_seconds': _meta('Wartezeit auf Versandbereitschaft', 'Wartezeit nach Sessionstart bis zum Versandtest.', 'repair', 60, 'int', repair['send_ready_wait_seconds'] ?? 30, unit: 's', expert: true, min: 0, max: 300),
      'repair_watchdog_seconds': _meta('Watchdog-Intervall', 'Prüfintervall des Session-Watchdogs.', 'repair', 70, 'int', repair['watchdog_seconds'] ?? 60, unit: 's', expert: true, min: 10, max: 3600),
    });
  }

  Map<String, dynamic> _meta(String label, String description, String group, int order,
      String type, dynamic value,
      {bool expert = false, String? unit, num? min, num? max, List<String>? options}) {
    return <String, dynamic>{
      'label': label,
      'description': description,
      'group': group,
      'order': order,
      'type': type,
      'value': value,
      'active': value,
      'persistent': value,
      'different': false,
      'visible': true,
      'expert': expert,
      'readonly': false,
      'session_apply_supported': true,
      'persistent_apply_supported': true,
      if (unit != null) 'unit': unit,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (options != null) 'options': options,
    };
  }

  void setQrPayload(Map<String, dynamic> payload) {
    qrCode.assignAll(_root(payload));
    lastUpdated.value = DateTime.now();
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
    ensureFallbackSettings();
    lastUpdated.value = DateTime.now();
  }

  void setDiagnosticPayload(String topic, Map<String, dynamic> payload) {
    diagnostics[topic] = _root(payload);
    ensureFallbackSettings();
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

  void requestQrCode() {
    Get.find<MqttConnection>().publishMessengerAction('messenger:waha/session/qr');
    lastStatus.value = 'QR-Code wurde angefordert.';
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
