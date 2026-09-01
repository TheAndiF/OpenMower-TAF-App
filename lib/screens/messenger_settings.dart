import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/messenger_settings_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';
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
    return Stack(
      children: [
        Obx(() {
          final expert = appSettings.expertModeEnabled.value;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _overviewSection(context),
                const SizedBox(height: 16),
                _expertModeSection(context),
                const SizedBox(height: 16),
                _surfaceSection(context, MessengerSurface.bot, expert),
                const SizedBox(height: 16),
                _surfaceSection(context, MessengerSurface.waha, expert),
                const SizedBox(height: 16),
                _diagnostics(context, expert),
              ],
            ),
          );
        }),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RobotStateWidget(),
        ),
      ],
    );
  }

  Widget _overviewSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final waiting = controller.botWaitingMode.isNotEmpty || controller.wahaWaitingMode.isNotEmpty;
    final botDifferences = controller.differenceCount(MessengerSurface.bot);
    final wahaDifferences = controller.differenceCount(MessengerSurface.waha);
    final flowDifferences = controller.flowsForBot().values.where((flow) {
      final active = flow['active'];
      final persistent = flow['persistent'];
      return flow['different'] == true || !_same(active, persistent);
    }).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 720;
                final header = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerIcon(
                      context,
                      Icons.forum_outlined,
                      active: controller.hasBotSnapshot || controller.hasWahaSnapshot,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Einstellungen Messenger',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Messenger Bot und WAHA nach bot_v1 / waha_v1 live testen oder dauerhaft speichern',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final refreshButton = OutlinedButton.icon(
                  onPressed: waiting ? null : controller.requestAll,
                  icon: waiting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Status neu laden'),
                );
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      refreshButton,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: 16),
                    refreshButton,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _overviewMetric(
                      context,
                      label: 'Bot',
                      value: controller.hasBotSnapshot ? _displayState(controller.botState) : 'keine Daten',
                      icon: Icons.smart_toy_outlined,
                    ),
                    _overviewMetric(
                      context,
                      label: 'WAHA',
                      value: controller.hasWahaSnapshot ? _displayState(controller.wahaState) : 'keine Daten',
                      icon: Icons.chat_outlined,
                    ),
                    _overviewMetric(
                      context,
                      label: 'Entwürfe',
                      value: controller.dirtyCount.toString(),
                      icon: Icons.edit_note,
                    ),
                    _overviewMetric(
                      context,
                      label: 'Abweichungen',
                      value: (botDifferences + wahaDifferences + flowDifferences).toString(),
                      icon: Icons.compare_arrows,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _globalStatusCard(context),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '„Jetzt anwenden“ verändert nur die laufende Session. „Dauerhaft speichern“ schreibt die persistenten Bot-/WAHA-Einstellungen. Der anschließend empfangene Snapshot bleibt der autoritative Zustand.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expertModeSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: Icon(Icons.admin_panel_settings_outlined, color: color),
        title: Text(
          'Expertenmodus',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Zeigt technische Bot-/WAHA-Einstellungen, Diagnose-JSON und erweiterte Metadaten. Schreibgrenzen des Schnittstellenvertrags bleiben unverändert.',
        ),
        value: appSettings.expertModeEnabled.value,
        onChanged: appSettings.setExpertModeEnabled,
      ),
    );
  }

  Widget _surfaceSection(BuildContext context, MessengerSurface surface, bool expert) {
    final color = Theme.of(context).primaryColor;
    final isBot = surface == MessengerSurface.bot;
    final hasSnapshot = isBot ? controller.hasBotSnapshot : controller.hasWahaSnapshot;
    final state = isBot ? controller.botState : controller.wahaState;
    final status = controller.statusFor(surface);
    final settings = controller.settingsFor(surface);
    final dirtyCount = isBot ? controller.botDirtySettings.length + controller.botDirtyFlows.length : controller.wahaDirtySettings.length;
    final differences = controller.differenceCount(surface);
    final title = isBot ? 'Messenger Bot' : 'WAHA / WhatsApp';
    final subtitle = isBot
        ? 'Provider-neutrale Bot-Einstellungen und Aktivierung vorhandener Flows'
        : 'Technischer WAHA-Status, QR-Anmeldung und WAHA-Einstellungen';

    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          backgroundColor: color.withValues(alpha: 0.08),
          collapsedBackgroundColor: color.withValues(alpha: 0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(isBot ? Icons.smart_toy_outlined : Icons.chat_outlined, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              if (hasSnapshot) Text('Status: ${_displayState(state)}', style: Theme.of(context).textTheme.bodyMedium),
              if (differences > 0) Text('$differences aktiv/gespeichert unterschiedlich', style: Theme.of(context).textTheme.bodyMedium),
              if (dirtyCount > 0) Text('$dirtyCount lokale Änderung(en)', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _surfaceStatusCard(context, surface, status, state),
                  if (!hasSnapshot)
                    _emptySurfaceCard(context, isBot)
                  else ...[
                    if (!isBot) _qrCard(context),
                    if (settings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Der Snapshot enthält aktuell keine editierbaren Settings.'),
                      )
                    else
                      ...controller.groups(surface, expertMode: expert).expand((group) sync* {
                        yield _settingsGroup(context, surface, group, expert);
                        yield const SizedBox(height: 12);
                      }),
                    if (isBot) _flowsSection(context, expert),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySurfaceCard(BuildContext context, bool isBot) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_download_outlined, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              isBot ? 'Noch keine Bot-Daten empfangen' : 'Noch keine WAHA-Daten empfangen',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              isBot
                  ? 'Erwartet wird messenger/bot/json mit namespace=messenger_bot, schema=bot_v1 und schema_version=1.0.'
                  : 'Erwartet wird messenger/waha/json mit namespace=messenger_waha, schema=waha_v1 und schema_version=1.0.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _globalStatusCard(BuildContext context) {
    final waiting = controller.botWaitingMode.isNotEmpty || controller.wahaWaitingMode.isNotEmpty;
    final lastStatus = controller.lastStatus.value;
    final topic = controller.lastTopic.value;
    final updated = controller.lastUpdated.value;

    final hasError = lastStatus.toLowerCase().contains('fehler') || lastStatus.toLowerCase().contains('abgelehnt');
    final Color accent;
    final Color background;
    final IconData icon;
    if (hasError) {
      accent = Colors.red.shade700;
      background = Colors.red.shade50;
      icon = Icons.error_outline;
    } else if (waiting) {
      accent = Theme.of(context).primaryColor;
      background = accent.withValues(alpha: 0.06);
      icon = Icons.sync;
    } else if (controller.hasBotSnapshot || controller.hasWahaSnapshot) {
      accent = Colors.green.shade700;
      background = Colors.green.shade50;
      icon = Icons.check_circle_outline;
    } else {
      accent = Theme.of(context).primaryColor;
      background = accent.withValues(alpha: 0.04);
      icon = Icons.info_outline;
    }

    final headline = lastStatus.isNotEmpty
        ? lastStatus
        : waiting
            ? 'Warte auf Backend-Antwort ...'
            : controller.hasBotSnapshot || controller.hasWahaSnapshot
                ? 'Messenger-Status empfangen.'
                : 'Noch keine Rückmeldung.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: accent, fontWeight: FontWeight.w600),
                ),
                if (topic.isNotEmpty || updated != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (topic.isNotEmpty) Text('Topic: $topic', style: Theme.of(context).textTheme.bodySmall),
                      if (updated != null) Text('Zeit: ${_formatTime(updated)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceStatusCard(
    BuildContext context,
    MessengerSurface surface,
    Map<String, dynamic> status,
    String state,
  ) {
    final text = (status['text'] ?? '').toString();
    final error = (status['last_error'] ?? '').toString();
    final ready = status['ready'] == true;
    final waiting = controller.isWaiting(surface);
    final differenceCount = controller.differenceCount(surface);

    final Color accent;
    final Color background;
    final IconData icon;
    if (error.isNotEmpty) {
      accent = Colors.red.shade700;
      background = Colors.red.shade50;
      icon = Icons.error_outline;
    } else if (waiting) {
      accent = Theme.of(context).primaryColor;
      background = accent.withValues(alpha: 0.06);
      icon = Icons.sync;
    } else if (ready) {
      accent = Colors.green.shade700;
      background = Colors.green.shade50;
      icon = Icons.check_circle_outline;
    } else {
      accent = Colors.orange.shade800;
      background = Colors.orange.shade50;
      icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;
          final statusContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${_displayState(state)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: accent, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _smallBadge(
                          context,
                          ready ? 'bereit' : 'nicht bereit',
                          ready ? Icons.check_circle_outline : Icons.hourglass_empty,
                          accent,
                        ),
                        if (differenceCount > 0)
                          _smallBadge(context, '$differenceCount Abweichung(en)', Icons.compare_arrows, Colors.orange.shade800),
                      ],
                    ),
                    if (text.isNotEmpty) ...[const SizedBox(height: 8), Text(text, style: Theme.of(context).textTheme.bodySmall)],
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Letzter Fehler: $error', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade700)),
                    ],
                  ],
                ),
              ),
            ],
          );
          final refreshButton = OutlinedButton.icon(
            onPressed: waiting ? null : () => controller.request(surface),
            icon: waiting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Status neu laden'),
          );
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [statusContent, const SizedBox(height: 12), refreshButton],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: statusContent), const SizedBox(width: 16), refreshButton],
          );
        },
      ),
    );
  }

  Widget _settingsGroup(BuildContext context, MessengerSurface surface, String group, bool expert) {
    final color = Theme.of(context).primaryColor;
    final entries = controller.entriesForGroup(surface, group, expertMode: expert);
    final dirty = entries.where((entry) => controller.isSettingDirty(surface, entry.key)).length;
    final differences = entries.where((entry) => entry.value['different'] == true || !_same(entry.value['active'], entry.value['persistent'])).length;
    final sessionDirty = entries.where((entry) =>
      controller.isSettingDirty(surface, entry.key) && entry.value['session_apply_supported'] != false).length;
    final canSession = controller.canApplySession(surface, group: group);
    final canPersistent = controller.hasPersistentChanges(surface, group: group);

    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group == 'general' || group == 'messenger' || group == 'session',
          backgroundColor: color.withValues(alpha: 0.08),
          collapsedBackgroundColor: color.withValues(alpha: 0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(controller.groupIcon(group), color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text(controller.groupLabel(surface, group), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text('${entries.length} Werte', style: Theme.of(context).textTheme.bodyMedium),
              if (differences > 0) Text('$differences aktiv/gespeichert unterschiedlich', style: Theme.of(context).textTheme.bodyMedium),
              if (dirty > 0) Text('$dirty lokale Änderung(en)', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _settingField(context, surface, entries[i].key, entries[i].value),
                  ],
                  const SizedBox(height: 14),
                  _groupActions(
                    context,
                    onReset: dirty == 0 ? null : () => controller.discardSettings(surface, group: group),
                    onSession: canSession ? () => controller.applySession(surface, group: group) : null,
                    onPersistent: canPersistent ? () => controller.applyPersistent(surface, group: group) : null,
                    dirty: dirty,
                    sessionDirty: sessionDirty,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingField(
    BuildContext context,
    MessengerSurface surface,
    String key,
    Map<String, dynamic> meta,
  ) {
    final color = Theme.of(context).primaryColor;
    final label = (meta['label'] ?? key).toString();
    final description = (meta['description'] ?? '').toString();
    final readonly = meta['readonly'] == true;
    final value = controller.settingValue(surface, key);
    final error = controller.validationErrorFor(surface, key);
    final options = controller.optionItems(meta);
    final type = (meta['type'] ?? 'string').toString().toLowerCase();
    final sessionSupported = meta['session_apply_supported'] != false;
    final dirty = controller.isSettingDirty(surface, key);
    final different = meta['different'] == true || !_same(meta['active'], meta['persistent']);
    final restartRequired = meta['restart_required'] == true;
    final expert = meta['expert'] == true;
    final unit = meta['unit']?.toString() ?? '';

    Widget editor;
    if (type == 'bool' || type == 'boolean') {
      editor = SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Entwurf'),
        subtitle: Text(readonly ? 'Nur lesen' : 'An oder Aus'),
        value: value == true,
        onChanged: readonly ? null : (next) => controller.updateSettingDraft(surface, key, next),
      );
    } else if (options.isNotEmpty) {
      final selected = options.any((option) => _same(option.value, value)) ? value : null;
      editor = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownButtonFormField<dynamic>(
              value: selected,
              isExpanded: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Entwurf',
                helperText: readonly ? 'Nur lesen' : 'Nur einen aktuell gelieferten Optionswert verwenden',
                errorText: error,
              ),
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
      );
    } else {
      editor = TextFormField(
        key: ValueKey('$surface-$key-${value.runtimeType}-$value'),
        initialValue: value?.toString() ?? '',
        readOnly: readonly,
        keyboardType: type == 'int' || type == 'integer' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: 'Entwurf',
          suffixText: unit.isEmpty ? null : unit,
          helperText: readonly ? 'Nur lesen' : (type == 'int' || type == 'integer' ? 'Ganzzahl vor dem Senden lokal prüfen' : null),
          errorText: error,
        ),
        onChanged: readonly
            ? null
            : (raw) {
                dynamic next = raw;
                if (type == 'int' || type == 'integer') next = int.tryParse(raw.trim()) ?? raw;
                controller.updateSettingDraft(surface, key, next);
              },
      );
    }

    final range = meta['min'] != null || meta['max'] != null ? 'Bereich: ${meta['min'] ?? '...'} bis ${meta['max'] ?? '...'}${unit.isEmpty ? '' : ' $unit'}' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dirty ? color.withValues(alpha: 0.05) : Theme.of(context).cardColor,
        border: Border.all(color: dirty ? color.withValues(alpha: 0.45) : Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 780;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (dirty) _smallBadge(context, 'Wert geändert', Icons.edit_outlined, color),
                ],
              ),
              const SizedBox(height: 2),
              Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (meta.containsKey('active'))
                    _valueChip(context, label: 'Aktiv', value: _withUnit(meta['active'], unit), emphasis: different),
                  if (meta.containsKey('persistent'))
                    _valueChip(context, label: 'Gespeichert', value: _withUnit(meta['persistent'], unit), emphasis: different),
                  if (sessionSupported) _smallBadge(context, 'Session-fähig', Icons.flash_on_outlined, Colors.green.shade700),
                  if (expert) _smallBadge(context, 'Expert', Icons.admin_panel_settings_outlined, Colors.blueGrey.shade700),
                  if (readonly) _smallBadge(context, 'Nur lesen', Icons.lock_outline, Colors.blueGrey.shade700),
                  if (!sessionSupported) _smallBadge(context, 'nur persistent', Icons.save_outlined, Colors.orange.shade800),
                  if (restartRequired) _smallBadge(context, 'Neustart nötig', Icons.restart_alt, Colors.orange.shade800),
                ],
              ),
              if (range.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(range, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 12), editor],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: info),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: editor),
            ],
          );
        },
      ),
    );
  }

  Widget _flowsSection(BuildContext context, bool expert) {
    final color = Theme.of(context).primaryColor;
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

    final dirty = flows.where((entry) => controller.isFlowDirty(entry.key)).length;
    final differences = flows.where((entry) => entry.value['different'] == true || !_same(entry.value['active'], entry.value['persistent'])).length;
    final canSession = controller.canApplySession(MessengerSurface.bot, group: '__flows__', includeFlows: true);
    final canPersistent = controller.hasPersistentChanges(MessengerSurface.bot, group: '__flows__', includeFlows: true);

    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: color.withValues(alpha: 0.08),
          collapsedBackgroundColor: color.withValues(alpha: 0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(Icons.account_tree_outlined, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text('Flows', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text('${flows.length} vorhandene Flow-Aktivierungen', style: Theme.of(context).textTheme.bodyMedium),
              if (differences > 0) Text('$differences aktiv/gespeichert unterschiedlich', style: Theme.of(context).textTheme.bodyMedium),
              if (dirty > 0) Text('$dirty lokale Änderung(en)', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  for (var i = 0; i < flows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _flowCard(context, flows[i].key, flows[i].value),
                  ],
                  const SizedBox(height: 14),
                  _groupActions(
                    context,
                    onReset: dirty == 0 ? null : controller.discardFlows,
                    onSession: canSession
                        ? () => controller.applySession(MessengerSurface.bot, group: '__flows__', includeFlows: true)
                        : null,
                    onPersistent: canPersistent
                        ? () => controller.applyPersistent(MessengerSurface.bot, group: '__flows__', includeFlows: true)
                        : null,
                    dirty: dirty,
                    sessionDirty: canSession ? dirty : 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowCard(BuildContext context, String key, Map<String, dynamic> meta) {
    final color = Theme.of(context).primaryColor;
    final readonly = meta['readonly'] == true;
    final dirty = controller.isFlowDirty(key);
    final different = meta['different'] == true || !_same(meta['active'], meta['persistent']);
    final sessionSupported = meta['session_apply_supported'] != false;
    final value = controller.flowValue(key) == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dirty ? color.withValues(alpha: 0.05) : Theme.of(context).cardColor,
        border: Border.all(color: dirty ? color.withValues(alpha: 0.45) : Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 780;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (meta['label'] ?? key).toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (dirty) _smallBadge(context, 'Wert geändert', Icons.edit_outlined, color),
                ],
              ),
              const SizedBox(height: 2),
              Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              if ((meta['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(meta['description'].toString(), style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (meta.containsKey('active')) _valueChip(context, label: 'Aktiv', value: '${meta['active']}', emphasis: different),
                  if (meta.containsKey('persistent')) _valueChip(context, label: 'Gespeichert', value: '${meta['persistent']}', emphasis: different),
                  if (sessionSupported) _smallBadge(context, 'Session-fähig', Icons.flash_on_outlined, Colors.green.shade700),
                  if (meta['expert'] == true) _smallBadge(context, 'Expert', Icons.admin_panel_settings_outlined, Colors.blueGrey.shade700),
                  if (readonly) _smallBadge(context, 'Nur lesen', Icons.lock_outline, Colors.blueGrey.shade700),
                ],
              ),
            ],
          );
          final editor = SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Entwurf'),
            subtitle: Text(readonly ? 'Nur lesen' : 'An oder Aus'),
            value: value,
            onChanged: readonly ? null : (next) => controller.updateFlowDraft(key, next),
          );
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 12), editor],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: info),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: editor),
            ],
          );
        },
      ),
    );
  }

  Widget _groupActions(
    BuildContext context, {
    required VoidCallback? onReset,
    required VoidCallback? onSession,
    required VoidCallback? onPersistent,
    required int dirty,
    required int sessionDirty,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    final resetButton = OutlinedButton.icon(
      onPressed: onReset,
      icon: const Icon(Icons.undo),
      label: const Text('Entwürfe zurücksetzen'),
    );
    final liveButton = ElevatedButton.icon(
      onPressed: onSession,
      icon: const Icon(Icons.flash_on_outlined),
      label: Text(sessionDirty > 0 ? 'Jetzt anwenden ($sessionDirty)' : 'Jetzt anwenden'),
    );
    final persistentButton = ElevatedButton.icon(
      onPressed: onPersistent,
      icon: const Icon(Icons.save_outlined),
      label: Text(dirty > 0 ? 'Dauerhaft speichern ($dirty)' : 'Dauerhaft speichern'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          resetButton,
          const SizedBox(height: 8),
          liveButton,
          const SizedBox(height: 8),
          persistentButton,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        resetButton,
        const SizedBox(width: 8),
        liveButton,
        const SizedBox(width: 8),
        persistentButton,
      ],
    );
  }

  Widget _qrCard(BuildContext context) {
    final raw = controller.qrCodeData;
    if (raw == null) return const SizedBox.shrink();
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _headerIcon(context, Icons.qr_code_2, active: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp koppeln',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'QR-Code aus status.QR_Code_Data des aktuellen waha/json-Snapshots',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                  borderRadius: BorderRadius.circular(6),
                ),
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
            OutlinedButton.icon(
              onPressed: () => controller.request(MessengerSurface.waha),
              icon: const Icon(Icons.refresh),
              label: const Text('WAHA neu laden'),
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
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          backgroundColor: color.withValues(alpha: 0.08),
          collapsedBackgroundColor: color.withValues(alpha: 0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(Icons.code, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text('Diagnose und Validierung', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Text(
            expert ? 'Validierungen, redigierte Snapshots und Bot-Runtime-Kanäle' : 'Technische Rohdaten nur im Expertenmodus',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.only(top: 12),
              child: expert
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _jsonTile(context, 'Bot-Validierung', controller.botValidation),
                        _jsonTile(context, 'WAHA-Validierung', controller.wahaValidation),
                        _jsonTile(context, 'Bot-Snapshot (QR-sicher)', controller.botSnapshot),
                        _jsonTile(context, 'WAHA-Snapshot (QR_Code_Data redigiert)', controller.wahaSnapshot),
                        _jsonTile(context, 'Bot-Ereignis', controller.botEvents),
                        _jsonTile(context, 'Ausstehende Bestätigungen', controller.botPendingConfirmations),
                      ],
                    )
                  : const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Aktiviere den Expertenmodus, um technische JSON-Daten einzublenden.'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jsonTile(BuildContext context, String title, Map<String, dynamic> value) {
    final color = Theme.of(context).primaryColor;
    if (value.isEmpty) {
      return ListTile(
        leading: Icon(Icons.data_object, color: color),
        title: Text(title),
        subtitle: const Text('Noch keine Daten empfangen'),
      );
    }
    return ExpansionTile(
      leading: Icon(Icons.data_object, color: color),
      title: Text(title),
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            controller.prettyJsonSafe(value),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _overviewMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueChip(
    BuildContext context, {
    required String label,
    required String value,
    required bool emphasis,
  }) {
    final color = emphasis ? Colors.orange.shade800 : Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _smallBadge(BuildContext context, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.65), width: 2),
      ),
      child: Icon(active ? icon : Icons.info_outline, color: color, size: 24),
    );
  }

  String _withUnit(dynamic value, String unit) {
    final text = value?.toString() ?? '-';
    if (unit.isEmpty || text == '-') return text;
    return '$text $unit';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _displayState(String state) => state.trim().isEmpty ? 'unbekannt' : state;

  bool _same(dynamic a, dynamic b) => a == b || a?.toString() == b?.toString();

  int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}
