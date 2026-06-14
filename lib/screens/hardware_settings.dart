import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/low_level_power_settings_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class HardwareSettingsScreen extends StatefulWidget {
  const HardwareSettingsScreen({super.key});

  @override
  State<HardwareSettingsScreen> createState() => _HardwareSettingsScreenState();
}

class _HardwareSettingsScreenState extends State<HardwareSettingsScreen> {
  final LowLevelPowerSettingsController controller = Get.find<LowLevelPowerSettingsController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  bool _renewSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final expertMode = settingsController.expertModeEnabled.value;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewSection(context),
                const SizedBox(height: 16),
                _buildExpertModeSection(context),
                const SizedBox(height: 16),
                if (!controller.hasData)
                  _buildEmptySettingsCard(context)
                else
                  ...controller.groupsForMode(expertModeEnabled: expertMode).expand((group) sync* {
                    yield _buildGroupSection(context, group);
                    yield const SizedBox(height: 16);
                  }),
                _buildJsonSection(context),
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

  Widget _buildOverviewSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final waiting = controller.waitingForResponse.value;
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
                    _headerIcon(context, Icons.build_outlined, active: controller.hasData),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Einstellungen Hardware',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Low-Level-Board-Parameter live testen oder dauerhaft speichern',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final refreshButton = OutlinedButton.icon(
                  onPressed: waiting ? null : controller.requestStatus,
                  icon: waiting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('LL-Board neu laden'),
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
                    _overviewMetric(context, label: 'Parameter', value: controller.settingCount.toString(), icon: Icons.list_alt),
                    _overviewMetric(context, label: 'Abweichungen', value: controller.differenceCount.toString(), icon: Icons.compare_arrows),
                    _overviewMetric(context, label: 'Entwürfe', value: controller.dirtyCount.toString(), icon: Icons.edit_note),
                    _overviewMetric(context, label: 'Neustart-Hinweise', value: controller.restartRequiredCount.toString(), icon: Icons.restart_alt),
                  ],
                ),
                const SizedBox(height: 14),
                _buildStatusCard(context),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    border: Border.all(color: color.withOpacity(0.18)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '„Jetzt anwenden“ verändert nur die laufende LL-Board-Session. „Dauerhaft speichern“ schreibt value und im Expertenmodus auch group/expert über settings/ll_board/set/persistent/json.',
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

  Widget _buildExpertModeSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Obx(() => SwitchListTile(
            secondary: Icon(Icons.admin_panel_settings_outlined, color: color),
            title: Text(
              'Expertenmodus',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Blendet erweiterte Low-Level-Board-Werte ein und zeigt editierbare JSON-Metadaten wie „group“ und „expert“. Die Gruppierung wird nach Speichern und Backend-Rückmeldung neu aufgebaut.',
            ),
            value: settingsController.expertModeEnabled.value,
            onChanged: settingsController.setExpertModeEnabled,
          )),
    );
  }

  Widget _buildEmptySettingsCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.cloud_download_outlined, size: 44, color: Theme.of(context).primaryColor),
            const SizedBox(height: 10),
            Text(
              'Noch keine Hardware-Settings empfangen',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Sobald das Backend auf settings/ll_board/json publiziert, werden Gruppen und Einstellfelder wie im Software-Bereich aufgebaut.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(BuildContext context, String group) {
    final color = Theme.of(context).primaryColor;
    final expertMode = settingsController.expertModeEnabled.value;
    final keys = controller.keysForGroup(group, expertModeEnabled: expertMode);
    final dirty = controller.dirtyCountForGroup(group, expertModeEnabled: expertMode);
    final differences = controller.differenceCountForGroup(group, expertModeEnabled: expertMode);
    final liveDirty = controller.sessionSupportedDirtyCountForGroup(group, expertModeEnabled: expertMode);
    final metadataDirty = controller.metadataDirtyCountForGroup(group, expertModeEnabled: expertMode);
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group == 'll_board' || group == 'battery',
          backgroundColor: color.withOpacity(0.08),
          collapsedBackgroundColor: color.withOpacity(0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(controller.groupIcon(group), color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text(controller.groupLabel(group), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text('${keys.length} Werte', style: Theme.of(context).textTheme.bodyMedium),
              if (differences > 0) Text('$differences aktiv/gespeichert unterschiedlich', style: Theme.of(context).textTheme.bodyMedium),
              if (dirty > 0) Text('$dirty lokale Änderung(en)', style: Theme.of(context).textTheme.bodyMedium),
              if (metadataDirty > 0) Text('$metadataDirty Metadaten', style: Theme.of(context).textTheme.bodyMedium),
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
                  for (var i = 0; i < keys.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildValueCard(context, keys[i]),
                  ],
                  const SizedBox(height: 14),
                  _buildGroupActions(context, group, dirty: dirty, liveDirty: liveDirty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard(BuildContext context, String key) {
    final color = Theme.of(context).primaryColor;
    final valueDirty = controller.dirtyKeys.contains(key);
    final groupDirty = controller.dirtyGroupKeys.contains(key);
    final expertDirty = controller.dirtyExpertKeys.contains(key);
    final dirty = valueDirty || groupDirty || expertDirty;
    final unit = controller.unitFor(key);
    final different = controller.isDifferent(key);
    final sessionSupported = controller.sessionApplySupported(key);
    final restartRequired = controller.restartRequired(key);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dirty ? color.withOpacity(0.05) : Theme.of(context).cardColor,
        border: Border.all(color: dirty ? color.withOpacity(0.45) : Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 780;
          final meta = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      controller.labelFor(key),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (valueDirty) _smallBadge(context, 'Wert geändert', Icons.edit_outlined, color),
                  if (groupDirty) ...[
                    const SizedBox(width: 6),
                    _smallBadge(context, 'Gruppe geändert', Icons.category_outlined, color),
                  ],
                  if (expertDirty) ...[
                    const SizedBox(width: 6),
                    _smallBadge(context, 'Expert geändert', Icons.admin_panel_settings_outlined, color),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              if (settingsController.expertModeEnabled.value) ...[
                const SizedBox(height: 4),
                Text(
                  'JSON group: ${controller.groupOriginalText(key)} · expert: ${controller.expertOriginalBool(key)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
              const SizedBox(height: 8),
              Text(controller.descriptionFor(key), style: Theme.of(context).textTheme.bodySmall),
              if (controller.rangeText(key).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(controller.rangeText(key), style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (different) _smallBadge(context, 'Abweichung', Icons.compare_arrows, Colors.orange.shade800),
                  if (sessionSupported) _smallBadge(context, 'Session-fähig', Icons.flash_on_outlined, Colors.green.shade700),
                  if (restartRequired) _smallBadge(context, 'Neustart nötig', Icons.restart_alt, Colors.orange.shade800),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _valueChip(context, label: 'Aktiv', value: _withUnit(controller.activeText(key), unit), emphasis: dirty || different),
                  if (controller.hasPersistentValue(key))
                    _valueChip(context, label: 'Gespeichert', value: _withUnit(controller.persistentText(key), unit), emphasis: false),
                ],
              ),
            ],
          );
          final field = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: ValueKey('ll_board_${key}_${controller.editorRevision.value}'),
                initialValue: controller.draftText(key),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.\-]'))],
                onChanged: (value) => controller.updateDraftText(key, value),
                decoration: InputDecoration(
                  labelText: 'Entwurf',
                  suffixText: unit.isEmpty ? null : unit,
                  border: const OutlineInputBorder(),
                  helperText: 'Wird vor dem Senden als JSON-number geprüft.',
                ),
              ),
              if (settingsController.expertModeEnabled.value) ...[
                const SizedBox(height: 10),
                _buildMetadataEditor(context, key),
              ],
            ],
          );
          if (isMobile) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [meta, const SizedBox(height: 12), field]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: meta), const SizedBox(width: 16), Expanded(flex: 2, child: field)]);
        },
      ),
    );
  }

  Widget _buildMetadataEditor(BuildContext context, String key) {
    final groupDirty = controller.dirtyGroupKeys.contains(key);
    final expertDirty = controller.dirtyExpertKeys.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('ll-board-group-$key-${controller.editorRevision.value}'),
          initialValue: controller.groupDraftText(key),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'JSON-Feld „group“',
            helperText: groupDirty
                ? 'Wird erst beim dauerhaften Speichern als group gesendet'
                : 'String, nicht leer, maximal 80 Zeichen, keine Steuerzeichen',
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          onChanged: (value) => controller.updateDraftGroup(key, value),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: ValueKey('ll-board-expert-$key-${controller.editorRevision.value}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('JSON-Feld „expert“'),
          subtitle: Text(
            expertDirty
                ? 'Wird erst beim dauerhaften Speichern als Boolean gesendet'
                : 'true blendet den Wert im Normalmodus aus',
          ),
          value: controller.expertDraftBool(key),
          onChanged: (value) => controller.updateDraftExpert(key, value),
        ),
      ],
    );
  }

  Widget _buildGroupActions(BuildContext context, String group, {required int dirty, required int liveDirty}) {
    final waiting = controller.waitingForResponse.value;
    final isMobile = MediaQuery.of(context).size.width < 720;
    final resetButton = OutlinedButton.icon(
      onPressed: dirty == 0 || waiting
          ? null
          : () => controller.resetGroupDrafts(
                group,
                expertModeEnabled: settingsController.expertModeEnabled.value,
              ),
      icon: const Icon(Icons.undo),
      label: const Text('Entwürfe zurücksetzen'),
    );
    final liveButton = ElevatedButton.icon(
      onPressed: liveDirty == 0 || waiting
          ? null
          : () => controller.applySessionForGroup(
                group,
                expertModeEnabled: settingsController.expertModeEnabled.value,
              ),
      icon: const Icon(Icons.flash_on_outlined),
      label: Text(liveDirty > 0 ? 'Jetzt anwenden ($liveDirty)' : 'Jetzt anwenden'),
    );
    final persistentButton = ElevatedButton.icon(
      onPressed: dirty == 0 || waiting
          ? null
          : () => controller.savePersistentForGroup(
                group,
                expertModeEnabled: settingsController.expertModeEnabled.value,
              ),
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

  Widget _buildJsonSection(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('LL-Board JSON-Status'),
        subtitle: const Text('Rohdaten aus settings/ll_board/json'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              controller.rawStatusJson,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final statusOk = controller.lastStatusOk.value;
    final color = statusOk == false ? Colors.red : statusOk == true ? Colors.green : Theme.of(context).primaryColor;
    final status = controller.lastStatus.value.isEmpty ? 'Noch keine Low-Level-Board-Rückmeldung.' : controller.lastStatus.value;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusOk == false ? Icons.error_outline : statusOk == true ? Icons.check_circle_outline : Icons.info_outline, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          if (controller.lastTopic.value.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Topic: ${controller.lastTopic.value}', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (controller.lastRemarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final remark in controller.lastRemarks) Text('• $remark', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _overviewMetric(BuildContext context, {required String label, required String value, required IconData icon}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
        ],
      ),
    );
  }

  Widget _valueChip(BuildContext context, {required String label, required String value, required bool emphasis}) {
    final color = emphasis ? Theme.of(context).primaryColor : Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _smallBadge(BuildContext context, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(text, style: Theme.of(context).textTheme.bodySmall)],
      ),
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = active ? Theme.of(context).primaryColor : Theme.of(context).disabledColor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  String _withUnit(String value, String unit) => unit.isEmpty ? value : '$value $unit';
}
