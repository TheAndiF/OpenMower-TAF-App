import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/messenger_settings_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';

class MessengerSettingsScreen extends StatefulWidget {
  const MessengerSettingsScreen({super.key});

  @override
  State<MessengerSettingsScreen> createState() => _MessengerSettingsScreenState();
}

class _MessengerSettingsScreenState extends State<MessengerSettingsScreen> {
  final controller = Get.find<MessengerSettingsController>();
  final appSettings = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, controller.requestAll);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expert = appSettings.expertModeEnabled.value;
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _header(context),
          const SizedBox(height: 12),
          _settingsSection(context, expert),
          const SizedBox(height: 12),
          _runtimeSection(context),
          const SizedBox(height: 12),
          _diagnosticsSection(context, expert),
        ],
      );
    });
  }

  Widget _header(BuildContext context) {
    final status = controller.runtime['messenger/status/json'] ?? const <String, dynamic>{};
    final online = status['online'] == true;
    final text = (status['text'] ?? controller.lastStatus.value).toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.forum_outlined, size: 38, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Einstellungen Messenger', style: Theme.of(context).textTheme.headlineSmall),
              const Text('Offener MQTT-Aufbau wie bei Hardware- und Softwareeinstellungen'),
            ])),
            Icon(online ? Icons.check_circle : Icons.warning_amber_rounded,
                color: online ? Colors.green : Colors.orange, size: 30),
          ]),
          if (text.isNotEmpty) ...[const SizedBox(height: 10), Text(text)],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text('${controller.settings.length} Einstellungen')),
            Chip(label: Text('${controller.dirtyCount} geändert')),
            Chip(label: Text('${controller.differenceCount} Abweichungen')),
            OutlinedButton.icon(onPressed: controller.requestAll, icon: const Icon(Icons.refresh), label: const Text('Neu laden')),
          ]),
        ]),
      ),
    );
  }

  Widget _settingsSection(BuildContext context, bool expert) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.tune),
        title: const Text('Einstellungen'),
        subtitle: const Text('Änderbare Werte, gruppiert und durch Backend-Metadaten gesteuert'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (!controller.hasSettings)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Noch keine messenger/settings/json-Metadaten empfangen. Betriebsstatus und Diagnose funktionieren bereits über die vorhandenen Messenger-Topics.'),
            )
          else
            ...controller.groups(expertMode: expert).map((g) => _group(context, g, expert)),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String group, bool expert) {
    final entries = controller.entriesForGroup(group, expertMode: expert);
    final dirty = entries.where((e) => controller.isDirty(e.key)).length;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        initiallyExpanded: group == 'general' || group == 'connection',
        leading: Icon(controller.groupIcon(group), color: Theme.of(context).primaryColor),
        title: Text(controller.groupLabel(group)),
        subtitle: Text('${entries.length} Felder${dirty > 0 ? ' · $dirty geändert' : ''}'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          ...entries.map((e) => _field(context, e.key, e.value)),
          const Divider(),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: dirty == 0 ? null : () => controller.discard(group: group), child: const Text('Verwerfen')),
            OutlinedButton(onPressed: dirty == 0 ? null : () => controller.applySession(group: group), child: const Text('Jetzt anwenden')),
            FilledButton(onPressed: dirty == 0 ? null : () => controller.applyPersistent(group: group), child: const Text('Dauerhaft speichern')),
          ]),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String key, Map<String, dynamic> meta) {
    final label = (meta['label'] ?? key).toString();
    final description = (meta['description'] ?? '').toString();
    final type = (meta['type'] ?? 'string').toString();
    final readonly = meta['readonly'] == true;
    final value = controller.valueFor(key);
    Widget input;
    if (type == 'bool' || type == 'boolean') {
      input = Switch(value: value == true, onChanged: readonly ? null : (v) => controller.updateDraft(key, v));
    } else if (type == 'enum' && meta['options'] is List) {
      final options = (meta['options'] as List).map((e) => e.toString()).toList();
      input = DropdownButton<String>(value: options.contains(value?.toString()) ? value.toString() : null,
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: readonly ? null : (v) => controller.updateDraft(key, v));
    } else {
      input = SizedBox(width: 220, child: TextFormField(
        key: ValueKey('$key-$value'), initialValue: value?.toString() ?? '', readOnly: readonly,
        decoration: InputDecoration(isDense: true, suffixText: meta['unit']?.toString()),
        onChanged: (v) {
          dynamic parsed = v;
          if (type == 'int' || type == 'integer') parsed = int.tryParse(v) ?? v;
          if (type == 'double' || type == 'number') parsed = double.tryParse(v) ?? v;
          controller.updateDraft(key, parsed);
        },
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (description.isNotEmpty) Text(description, style: Theme.of(context).textTheme.bodySmall),
          if (meta['active'] != null || meta['persistent'] != null)
            Text('Aktiv: ${meta['active']} · Persistent: ${meta['persistent']}', style: Theme.of(context).textTheme.bodySmall),
        ])),
        const SizedBox(width: 12), input,
      ]),
    );
  }

  Widget _runtimeSection(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.monitor_heart_outlined),
        title: const Text('Betriebsstatus'),
        subtitle: const Text('Live-Zustand von WAHA, Session, Bot, Gruppen und Statusmeldungen'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _statusTile('Messenger', controller.runtime['messenger/status/json']),
          _statusTile('WAHA', controller.runtime['messenger/waha/json']),
          _statusTile('Session', controller.runtime['messenger/waha/session/json']),
          _statusTile('Mobert-Bot', controller.runtime['messenger/bot/json']),
          _statusTile('Listener', controller.runtime['messenger/bot/listener/json']),
          _statusTile('Gruppen', controller.runtime['messenger/waha/groups/json']),
          _statusTile('Status-Push', controller.runtime['messenger/bot/status_push/json']),
          _actions(context),
        ],
      ),
    );
  }

  Widget _statusTile(String title, Map<String, dynamic>? value) {
    if (value == null) return ListTile(title: Text(title), subtitle: const Text('Noch keine Daten empfangen'), leading: const Icon(Icons.cloud_off_outlined));
    final summary = (value['text'] ?? value['summary'] ?? value['status'] ?? value['count'] ?? 'Daten vorhanden').toString();
    return ExpansionTile(title: Text(title), subtitle: Text(summary), leading: const Icon(Icons.check_circle_outline),
      children: [SelectableText(controller.prettyJson(value), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))]);
  }

  Widget _actions(BuildContext context) {
    if (controller.actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8,
        children: controller.actions.map((a) {
          final enabled = a['enabled'] == true || a['enabled'] == 1;
          return OutlinedButton.icon(
            onPressed: enabled ? () => controller.runAction((a['action_id'] ?? '').toString()) : null,
            icon: const Icon(Icons.play_arrow), label: Text((a['label'] ?? a['action_id']).toString()));
        }).toList())),
    );
  }

  Widget _diagnosticsSection(BuildContext context, bool expert) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.troubleshoot),
        title: const Text('Diagnose'),
        subtitle: Text(expert ? 'Fehler, Reparatur, Validierung und MQTT-Rohdaten' : 'Technische Details im Expertenmodus'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: expert
            ? [
                _statusTile('Session-Reparatur', controller.diagnostics['messenger/waha/session/repair/json']),
                _statusTile('Kontakte', controller.diagnostics['messenger/waha/contacts/status/json']),
                _statusTile('Nachrichten', controller.diagnostics['messenger/waha/messages/json']),
                _statusTile('Bot-Konfiguration', controller.diagnostics['messenger/bot/commands/json']),
                _statusTile('Validierung', controller.lastValidation),
              ]
            : const [Padding(padding: EdgeInsets.all(12), child: Text('Aktiviere den Expertenmodus, um Rohdaten und technische Diagnosewerte einzublenden.'))],
      ),
    );
  }
}
