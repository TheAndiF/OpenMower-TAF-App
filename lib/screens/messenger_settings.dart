import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/messenger_settings_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
          _surfaceSection(context, MessengerSurface.bot, expert),
          const SizedBox(height: 12),
          _surfaceSection(context, MessengerSurface.waha, expert),
          const SizedBox(height: 12),
          _diagnostics(context, expert),
        ],
      );
    });
  }

  Widget _header(BuildContext context) {
    final botReady = controller.hasBotSnapshot;
    final wahaReady = controller.hasWahaSnapshot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.forum_outlined, size: 38, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Einstellungen Messenger', style: Theme.of(context).textTheme.headlineSmall),
                      const Text('MQTT-Vertrag bot_v1 / waha_v1 - Snapshot, Session, Persistent und Validierung'),
                    ],
                  ),
                ),
                if (controller.botWaitingMode.isNotEmpty || controller.wahaWaitingMode.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ),
              ],
            ),
            if (controller.lastStatus.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(controller.lastStatus.value),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(botReady ? 'Bot: ${_displayState(controller.botState)}' : 'Bot: keine Daten')),
                Chip(label: Text(wahaReady ? 'WAHA: ${_displayState(controller.wahaState)}' : 'WAHA: keine Daten')),
                Chip(label: Text('${controller.dirtyCount} lokale Änderung(en)')),
                OutlinedButton.icon(
                  onPressed: controller.requestAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Alles neu laden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _surfaceSection(BuildContext context, MessengerSurface surface, bool expert) {
    final isBot = surface == MessengerSurface.bot;
    final hasSnapshot = isBot ? controller.hasBotSnapshot : controller.hasWahaSnapshot;
    final state = isBot ? controller.botState : controller.wahaState;
    final status = controller.statusFor(surface);
    final settings = controller.settingsFor(surface);
    final title = isBot ? 'Messenger Bot' : 'WAHA / WhatsApp';
    final subtitle = isBot
        ? 'Provider-neutrale Bot-Einstellungen und Aktivierung vorhandener Flows'
        : 'Technischer WAHA-Status, QR-Anmeldung und WAHA-Einstellungen';

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(isBot ? Icons.smart_toy_outlined : Icons.chat_outlined),
        title: Text(title),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _statusCard(context, surface, status, state),
          if (!hasSnapshot)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isBot
                    ? 'Noch kein gültiger messenger/bot/json-Snapshot mit namespace=messenger_bot, schema=bot_v1 und schema_version=1.0 empfangen.'
                    : 'Noch kein gültiger messenger/waha/json-Snapshot mit namespace=messenger_waha, schema=waha_v1 und schema_version=1.0 empfangen.',
              ),
            )
          else ...[
            if (!isBot) _qrCard(context),
            if (settings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Der Snapshot enthält aktuell keine editierbaren Settings.'),
              )
            else
              ...controller.groups(surface, expertMode: expert).map((group) => _settingsGroup(context, surface, group, expert)),
            if (isBot) _flowsSection(context, expert),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(
    BuildContext context,
    MessengerSurface surface,
    Map<String, dynamic> status,
    String state,
  ) {
    final text = (status['text'] ?? '').toString();
    final error = (status['last_error'] ?? '').toString();
    final ready = status['ready'] == true;
    final differenceCount = controller.differenceCount(surface);
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('Status: ${_displayState(state)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Chip(label: Text(ready ? 'bereit' : 'nicht bereit')),
                if (differenceCount > 0) Chip(label: Text('$differenceCount Abweichung(en)')),
                OutlinedButton.icon(
                  onPressed: () => controller.request(surface),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Status neu laden'),
                ),
              ],
            ),
            if (text.isNotEmpty) ...[const SizedBox(height: 6), Text(text)],
            if (error.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Letzter Fehler: $error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _settingsGroup(BuildContext context, MessengerSurface surface, String group, bool expert) {
    final entries = controller.entriesForGroup(surface, group, expertMode: expert);
    final dirty = entries.where((entry) => controller.isSettingDirty(surface, entry.key)).length;
    final canSession = controller.canApplySession(surface, group: group);
    final canPersistent = controller.hasPersistentChanges(surface, group: group);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        initiallyExpanded: group == 'general' || group == 'messenger' || group == 'session',
        leading: Icon(controller.groupIcon(group), color: Theme.of(context).colorScheme.primary),
        title: Text(controller.groupLabel(surface, group)),
        subtitle: Text('${entries.length} Feld(er)${dirty > 0 ? ' - $dirty geändert' : ''}'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          ...entries.map((entry) => _settingField(context, surface, entry.key, entry.value)),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: dirty == 0 ? null : () => controller.discardSettings(surface, group: group),
                child: const Text('Entwurf zurücksetzen'),
              ),
              OutlinedButton(
                onPressed: canSession ? () => controller.applySession(surface, group: group) : null,
                child: const Text('Jetzt anwenden'),
              ),
              FilledButton(
                onPressed: canPersistent ? () => controller.applyPersistent(surface, group: group) : null,
                child: const Text('Dauerhaft speichern'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingField(
    BuildContext context,
    MessengerSurface surface,
    String key,
    Map<String, dynamic> meta,
  ) {
    final label = (meta['label'] ?? key).toString();
    final description = (meta['description'] ?? '').toString();
    final readonly = meta['readonly'] == true;
    final value = controller.settingValue(surface, key);
    final error = controller.validationErrorFor(surface, key);
    final options = controller.optionItems(meta);
    final type = (meta['type'] ?? 'string').toString().toLowerCase();
    final sessionSupported = meta['session_apply_supported'] != false;

    Widget editor;
    if (type == 'bool' || type == 'boolean') {
      editor = Switch(
        value: value == true,
        onChanged: readonly ? null : (next) => controller.updateSettingDraft(surface, key, next),
      );
    } else if (options.isNotEmpty) {
      final selected = options.any((option) => _same(option.value, value)) ? value : null;
      editor = SizedBox(
        width: 280,
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<dynamic>(
                value: selected,
                isExpanded: true,
                decoration: InputDecoration(isDense: true, errorText: error),
                hint: const Text('Auswahl'),
                items: options
                    .map((option) => DropdownMenuItem<dynamic>(value: option.value, child: Text(option.label)))
                    .toList(),
                onChanged: readonly ? null : (next) => controller.updateSettingDraft(surface, key, next),
              ),
            ),
            if (surface == MessengerSurface.bot && key == 'group') ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Gruppenoptionen neu laden',
                onPressed: controller.requestGroupOptions,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ],
        ),
      );
    } else {
      editor = SizedBox(
        width: 280,
        child: TextFormField(
          key: ValueKey('$surface-$key-${value.runtimeType}-$value'),
          initialValue: value?.toString() ?? '',
          readOnly: readonly,
          keyboardType: type == 'int' || type == 'integer' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            suffixText: meta['unit']?.toString(),
            errorText: error,
          ),
          onChanged: readonly
              ? null
              : (raw) {
                  dynamic next = raw;
                  if (type == 'int' || type == 'integer') next = int.tryParse(raw.trim()) ?? raw;
                  controller.updateSettingDraft(surface, key, next);
                },
        ),
      );
    }

    final details = <String>[];
    if (meta.containsKey('active')) details.add('Aktiv: ${meta['active']}');
    if (meta.containsKey('persistent')) details.add('Gespeichert: ${meta['persistent']}');
    if (meta['min'] != null || meta['max'] != null) details.add('Bereich: ${meta['min'] ?? '...'} bis ${meta['max'] ?? '...'}');

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (description.isNotEmpty) ...[const SizedBox(height: 2), Text(description, style: Theme.of(context).textTheme.bodySmall)],
        if (details.isNotEmpty) ...[const SizedBox(height: 4), Text(details.join(' - '), style: Theme.of(context).textTheme.bodySmall)],
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (controller.isSettingDirty(surface, key)) const Chip(label: Text('geändert'), visualDensity: VisualDensity.compact),
            if (meta['different'] == true) const Chip(label: Text('Aktiv != gespeichert'), visualDensity: VisualDensity.compact),
            if (meta['expert'] == true) const Chip(label: Text('Expert'), visualDensity: VisualDensity.compact),
            if (readonly) const Chip(label: Text('Nur lesen'), visualDensity: VisualDensity.compact),
            if (!sessionSupported) const Chip(label: Text('nur persistent'), visualDensity: VisualDensity.compact),
            if (meta['restart_required'] == true) const Chip(label: Text('Neustart nötig'), visualDensity: VisualDensity.compact),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: editor)],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: info), const SizedBox(width: 16), editor],
          );
        },
      ),
    );
  }

  Widget _flowsSection(BuildContext context, bool expert) {
    final flows = controller.flowsForBot().entries.where((entry) {
      if (entry.value['show'] == false) return false;
      if (!expert && entry.value['expert'] == true) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final ao = _asInt(a.value['order']) ?? 9999;
        final bo = _asInt(b.value['order']) ?? 9999;
        final order = ao.compareTo(bo);
        return order == 0 ? a.key.compareTo(b.key) : order;
      });
    if (flows.isEmpty) return const SizedBox.shrink();

    final canSession = controller.canApplySession(MessengerSurface.bot, group: '__flows__', includeFlows: true);
    final canPersistent = controller.hasPersistentChanges(MessengerSurface.bot, group: '__flows__', includeFlows: true);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.account_tree_outlined),
        title: const Text('Flows'),
        subtitle: Text('${flows.length} vorhandene Flow-Aktivierungen'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          ...flows.map((entry) {
            final meta = entry.value;
            final readonly = meta['readonly'] == true;
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((meta['label'] ?? entry.key).toString()),
              subtitle: Text((meta['description'] ?? entry.key).toString()),
              value: controller.flowValue(entry.key) == true,
              onChanged: readonly ? null : (value) => controller.updateFlowDraft(entry.key, value),
              secondary: controller.isFlowDirty(entry.key) ? const Icon(Icons.edit_outlined) : null,
            );
          }),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: controller.botDirtyFlows.isEmpty ? null : controller.discardFlows,
                child: const Text('Entwurf zurücksetzen'),
              ),
              OutlinedButton(
                onPressed: canSession
                    ? () => controller.applySession(MessengerSurface.bot, group: '__flows__', includeFlows: true)
                    : null,
                child: const Text('Jetzt anwenden'),
              ),
              FilledButton(
                onPressed: canPersistent
                    ? () => controller.applyPersistent(MessengerSurface.bot, group: '__flows__', includeFlows: true)
                    : null,
                child: const Text('Dauerhaft speichern'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrCard(BuildContext context) {
    final raw = controller.qrCodeData;
    if (raw == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: Theme.of(context).colorScheme.primary, size: 30),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WhatsApp koppeln', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                      Text('Der QR-Code wird ausschließlich aus status.QR_Code_Data des aktuellen waha/json-Snapshots erzeugt.'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(14),
                child: QrImageView(
                  data: raw,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'WhatsApp QR-Code zur WAHA-Anmeldung',
                  errorStateBuilder: (context, error) => const SizedBox(
                    width: 260,
                    height: 260,
                    child: Center(child: Text('QR-Code konnte nicht erzeugt werden.', textAlign: TextAlign.center)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => controller.request(MessengerSurface.waha),
                  icon: const Icon(Icons.refresh),
                  label: const Text('WAHA neu laden'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'QR-Rohdaten werden nicht in der Diagnoseansicht ausgegeben und nicht dauerhaft gespeichert. Sobald die Session verbunden ist, wird die Anzeige entfernt.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagnostics(BuildContext context, bool expert) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.troubleshoot_outlined),
        title: const Text('Diagnose und Validierung'),
        subtitle: Text(expert ? 'Validierungen, redigierte Snapshots und Bot-Runtime-Kanäle' : 'Technische Rohdaten nur im Expertenmodus'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: expert
            ? [
                _jsonTile('Bot-Validierung', controller.botValidation),
                _jsonTile('WAHA-Validierung', controller.wahaValidation),
                _jsonTile('Bot-Snapshot (QR-sicher)', controller.botSnapshot),
                _jsonTile('WAHA-Snapshot (QR_Code_Data redigiert)', controller.wahaSnapshot),
                _jsonTile('Bot-Ereignis', controller.botEvents),
                _jsonTile('Ausstehende Bestätigungen', controller.botPendingConfirmations),
              ]
            : const [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Aktiviere den Expertenmodus, um technische JSON-Daten einzublenden.'),
                ),
              ],
      ),
    );
  }

  Widget _jsonTile(String title, Map<String, dynamic> value) {
    if (value.isEmpty) return ListTile(title: Text(title), subtitle: const Text('Noch keine Daten empfangen'));
    return ExpansionTile(
      title: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SelectableText(
            controller.prettyJsonSafe(value),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _displayState(String state) => state.trim().isEmpty ? 'unbekannt' : state;

  bool _same(dynamic a, dynamic b) => a == b || a?.toString() == b?.toString();

  int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}
