import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_mower_app/services/platform_text_file.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/mower_logic_settings_controller.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/controllers/low_level_power_settings_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class MowerLogicSettingsScreen extends StatefulWidget {
  const MowerLogicSettingsScreen({super.key});

  @override
  State<MowerLogicSettingsScreen> createState() => _MowerLogicSettingsScreenState();
}

class _MowerLogicSettingsScreenState extends State<MowerLogicSettingsScreen> {
  final MowerLogicSettingsController controller = Get.find<MowerLogicSettingsController>();
  final RobotStateController robotStateController = Get.find<RobotStateController>();
  final LowLevelPowerSettingsController lowLevelPowerController = Get.find<LowLevelPowerSettingsController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  bool _renewSent = false;
  bool _jsonExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestSettings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
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
                  ...controller.groupsForMode(expertModeEnabled: settingsController.expertModeEnabled.value).expand((group) sync* {
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
    final waiting = controller.statusRefreshInProgress.value;
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
                    _headerIcon(context, Icons.tune, active: controller.hasData),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Einstellungen Software',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Softwareparameter live testen oder dauerhaft in settings_persistent.json speichern',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final refreshButton = OutlinedButton.icon(
                  onPressed: waiting ? null : controller.requestSettings,
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
                    '„Jetzt anwenden“ verändert die laufende Session. „Dauerhaft speichern“ setzt persistent und active und schreibt die persistente Settings-Datei.',
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
              'Blendet Advanced Options ein und zeigt in den Mäher-Logik-Karten editierbare JSON-Metadaten wie „group“. Die Gruppierung wird erst nach Speichern und Backend-Rückmeldung neu aufgebaut.',
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
              'Noch keine Settings-Daten empfangen',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Sobald das Backend auf settings/mower_logic/json publiziert, werden die Gruppen und Einstellfelder hier automatisch aufgebaut.',
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
    final groupEntries = controller.settingsForGroup(group, expertModeEnabled: expertMode);
    final dirty = controller.dirtyCountForGroup(group, expertModeEnabled: expertMode);
    final differences = controller.differenceCountForGroup(group, expertModeEnabled: expertMode);
    final liveDirty = controller.sessionSupportedDirtyCountForGroup(group, expertModeEnabled: expertMode);
    final metadataDirty = controller.metadataDirtyCountForGroup(group, expertModeEnabled: expertMode);
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group == 'general' || group == 'temperature_protection',
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
              Text('${groupEntries.length} Werte', style: Theme.of(context).textTheme.bodyMedium),
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
                  for (var i = 0; i < groupEntries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildSettingCard(context, groupEntries[i].key, groupEntries[i].value),
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

  Widget _buildSettingCard(BuildContext context, String key, Map<String, dynamic> setting) {
    final color = Theme.of(context).primaryColor;
    final different = _bool(setting['different']);
    final valueDirty = controller.dirtyKeys.contains(key);
    final groupDirty = controller.dirtyGroupKeys.contains(key);
    final expertDirty = controller.dirtyExpertKeys.contains(key);
    final dirty = valueDirty || groupDirty || expertDirty;
    final sessionSupported = _bool(setting['session_apply_supported']);
    final restartRequired = _bool(setting['restart_required']);
    final description = controller.descriptionFor(setting);
    final range = controller.rangeText(setting);
    final unit = controller.unitFor(setting);

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
                      controller.labelFor(key, setting),
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
                  'JSON group: ${controller.groupOriginalText(setting)} · expert: ${controller.expertOriginalBool(setting)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _valueChip(context, label: 'Aktiv', value: _withUnit(controller.activeText(setting), unit), emphasis: different),
                  _valueChip(context, label: 'Gespeichert', value: _withUnit(controller.persistentText(setting), unit), emphasis: different),
                  if (sessionSupported) _smallBadge(context, 'Session-fähig', Icons.flash_on_outlined, Colors.green.shade700),
                  if (restartRequired) _smallBadge(context, 'Neustart nötig', Icons.restart_alt, Colors.orange.shade800),
                ],
              ),
              if (range.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(range, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ],
          );

          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEditor(context, key, setting, unit: unit),
              if (settingsController.expertModeEnabled.value) ...[
                const SizedBox(height: 10),
                _buildMetadataEditors(context, key, setting),
              ],
            ],
          );
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                meta,
                const SizedBox(height: 12),
                editor,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: meta),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: editor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetadataEditors(BuildContext context, String key, Map<String, dynamic> setting) {
    final groupDirty = controller.dirtyGroupKeys.contains(key);
    final expertDirty = controller.dirtyExpertKeys.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('mower-setting-group-$key-${controller.editorRevision.value}'),
          initialValue: controller.groupDraftText(key, setting),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'JSON-Feld „group“',
            helperText: groupDirty
                ? 'Wird erst beim dauerhaften Speichern als group gesendet'
                : 'String, nicht leer, maximal 80 Zeichen, keine Steuerzeichen',
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          onChanged: (value) => controller.updateDraftGroup(key, setting, value),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: ValueKey('mower-setting-expert-$key-${controller.editorRevision.value}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('JSON-Feld „expert“'),
          subtitle: Text(
            expertDirty
                ? 'Wird erst beim dauerhaften Speichern als Boolean gesendet'
                : 'true blendet den Wert im Normalmodus aus',
          ),
          value: controller.expertDraftBool(key, setting),
          onChanged: (value) => controller.updateDraftExpert(key, setting, value),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context, String key, Map<String, dynamic> setting, {required String unit}) {
    if (key == 'mow_motor_direction_mode') {
      final draft = int.tryParse(controller.draftText(key, setting));
      return DropdownButtonFormField<int>(
        key: ValueKey('mower-direction-$key-${controller.editorRevision.value}'),
        value: draft == -1 || draft == 0 || draft == 1 ? draft : null,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Richtungsmodus',
        ),
        items: const [
          DropdownMenuItem<int>(value: -1, child: Text('-1 – feste Richtung reverse/left')),
          DropdownMenuItem<int>(value: 0, child: Text('0 – bei echtem Motorstart wechseln')),
          DropdownMenuItem<int>(value: 1, child: Text('1 – feste Richtung forward/right')),
        ],
        onChanged: (value) {
          if (value != null) {
            controller.updateDraftText(key, setting, value.toString());
          }
        },
      );
    }

    if (controller.isBool(setting)) {
      return SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Entwurf'),
        subtitle: const Text('An oder Aus'),
        value: controller.draftBool(key, setting),
        onChanged: (value) => controller.updateDraftBool(key, setting, value),
      );
    }

    return TextFormField(
      key: ValueKey('mower-setting-$key-${controller.editorRevision.value}'),
      initialValue: controller.draftText(key, setting),
      keyboardType: controller.isNumeric(setting)
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      inputFormatters: controller.isInt(setting)
          ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$'))]
          : controller.isDouble(setting)
              ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[\.,]?\d*$'))]
              : null,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'Entwurf',
        suffixText: unit.isEmpty ? null : unit,
        helperText: controller.isNumeric(setting) ? 'Wert vor dem Senden lokal prüfen' : null,
      ),
      onChanged: (value) => controller.updateDraftText(key, setting, value),
    );
  }

  Widget _buildGroupActions(BuildContext context, String group, {required int dirty, required int liveDirty}) {
    final waiting = controller.actionInProgress.value;
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

  Widget _buildLowLevelPowerSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final waiting = lowLevelPowerController.waitingForResponse.value;
    final hasData = lowLevelPowerController.hasData;
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          backgroundColor: color.withOpacity(0.08),
          collapsedBackgroundColor: color.withOpacity(0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(Icons.battery_charging_full_outlined, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text('Low-Level Board', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              const Text('Laufzeitwerte für /ll/services/power'),
              if (lowLevelPowerController.dirtyCount > 0)
                Text('${lowLevelPowerController.dirtyCount} lokale Änderung(en)'),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      border: Border.all(color: color.withOpacity(0.18)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Diese Werte werden über settings/ll_board/set/session/json live getestet oder über settings/ll_board/set/persistent/json dauerhaft gespeichert.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLowLevelPowerStatusCard(context),
                  const SizedBox(height: 12),
                  if (!hasData)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Noch keine settings/ll_board/json-Daten empfangen.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (var i = 0; i < LowLevelPowerSettingsController.orderedKeys.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildLowLevelPowerValueCard(context, LowLevelPowerSettingsController.orderedKeys[i]),
                    ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 720;
                      final actions = [
                        OutlinedButton.icon(
                          onPressed: waiting ? null : lowLevelPowerController.requestStatus,
                          icon: waiting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: const Text('LL-Board neu laden'),
                        ),
                        OutlinedButton.icon(
                          onPressed: lowLevelPowerController.dirtyCount == 0 || waiting
                              ? null
                              : lowLevelPowerController.resetDrafts,
                          icon: const Icon(Icons.undo),
                          label: const Text('Änderungen verwerfen'),
                        ),
                        ElevatedButton.icon(
                          onPressed: lowLevelPowerController.dirtyCount == 0 || waiting
                              ? null
                              : lowLevelPowerController.applySessionChanges,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Jetzt anwenden'),
                        ),
                        ElevatedButton.icon(
                          onPressed: lowLevelPowerController.dirtyCount == 0 || waiting
                              ? null
                              : lowLevelPowerController.savePersistentChanges,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Dauerhaft speichern'),
                        ),
                      ];
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: actions
                              .expand((button) => <Widget>[button, const SizedBox(height: 10)])
                              .toList()
                            ..removeLast(),
                        );
                      }
                      return Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: actions);
                    },
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('LL-Board JSON-Status'),
                    subtitle: const Text('Rohdaten aus settings/ll_board/json'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(
                          lowLevelPowerController.rawStatusJson,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowLevelPowerStatusCard(BuildContext context) {
    final statusOk = lowLevelPowerController.lastStatusOk.value;
    final color = statusOk == false ? Colors.red : statusOk == true ? Colors.green : Theme.of(context).primaryColor;
    final status = lowLevelPowerController.lastStatus.value.isEmpty
        ? 'Noch keine Low-Level-Board-Rückmeldung.'
        : lowLevelPowerController.lastStatus.value;
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
          if (lowLevelPowerController.lastTopic.value.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Topic: ${lowLevelPowerController.lastTopic.value}', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (lowLevelPowerController.lastRemarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final remark in lowLevelPowerController.lastRemarks)
              Text('• $remark', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildLowLevelPowerValueCard(BuildContext context, String key) {
    final color = Theme.of(context).primaryColor;
    final valueDirty = lowLevelPowerController.dirtyKeys.contains(key);
    final groupDirty = lowLevelPowerController.dirtyGroupKeys.contains(key);
    final dirty = valueDirty || groupDirty;
    final unit = lowLevelPowerController.unitFor(key);
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
                children: [
                  Expanded(
                    child: Text(
                      lowLevelPowerController.labelFor(key),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (valueDirty) _smallBadge(context, 'Wert geändert', Icons.edit_outlined, color),
                  if (groupDirty) ...[
                    const SizedBox(width: 6),
                    _smallBadge(context, 'Gruppe geändert', Icons.category_outlined, color),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              if (settingsController.expertModeEnabled.value) ...[
                const SizedBox(height: 4),
                Text(
                  'JSON group: ${lowLevelPowerController.groupOriginalText(key)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
              const SizedBox(height: 8),
              Text(lowLevelPowerController.descriptionFor(key), style: Theme.of(context).textTheme.bodySmall),
              if (lowLevelPowerController.rangeText(key).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(lowLevelPowerController.rangeText(key), style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              _valueChip(
                context,
                label: 'Aktiv',
                value: _withUnit(lowLevelPowerController.activeText(key), unit),
                emphasis: dirty,
              ),
            ],
          );
          final field = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: ValueKey('ll_board_${key}_${lowLevelPowerController.editorRevision.value}'),
                initialValue: lowLevelPowerController.draftText(key),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.\-]'))],
                onChanged: (value) => lowLevelPowerController.updateDraftText(key, value),
                decoration: InputDecoration(
                  labelText: 'Neuer Wert',
                  suffixText: unit.isEmpty ? null : unit,
                  border: const OutlineInputBorder(),
                  helperText: 'Wird als JSON-number gesendet.',
                ),
              ),
              if (settingsController.expertModeEnabled.value) ...[
                const SizedBox(height: 10),
                _buildLowLevelPowerGroupMetadataEditor(context, key),
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


  Widget _buildLowLevelPowerGroupMetadataEditor(BuildContext context, String key) {
    final groupDirty = lowLevelPowerController.dirtyGroupKeys.contains(key);
    return TextFormField(
      key: ValueKey('ll-board-group-$key-${lowLevelPowerController.editorRevision.value}'),
      initialValue: lowLevelPowerController.groupDraftText(key),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'JSON-Feld „group“',
        helperText: groupDirty
            ? 'Wird erst beim dauerhaften Speichern ans Backend gesendet'
            : 'Expertenmodus: keine lokale Neusortierung während der Eingabe',
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      onChanged: (value) => lowLevelPowerController.updateDraftGroup(key, value),
    );
  }

  Widget _buildJsonSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        return Card(
          margin: EdgeInsets.zero,
          child: Container(
            color: color.withOpacity(0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 12, isMobile ? 8 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.code, color: color, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('JSON-Ansicht', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
                                const SizedBox(height: 2),
                                Text('Rohstatus aus settings/mower_logic/json anzeigen und exportieren', style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          if (!isMobile) _jsonActionButtons(context, isMobile: false),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: _jsonExpanded ? 'JSON-Ansicht einklappen' : 'JSON-Ansicht ausklappen',
                            onPressed: () => setState(() => _jsonExpanded = !_jsonExpanded),
                            icon: Icon(_jsonExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: color),
                          ),
                        ],
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 12),
                        _jsonActionButtons(context, isMobile: true),
                      ],
                    ],
                  ),
                ),
                if (_jsonExpanded)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusCard(context),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('mower-logic-settings-json-${controller.lastUpdated.value?.millisecondsSinceEpoch ?? 0}'),
                          initialValue: controller.rawStatusJson,
                          readOnly: true,
                          minLines: 10,
                          maxLines: 24,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'settings/mower_logic/json',
                            alignLabelWithHint: true,
                          ),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _jsonActionButtons(BuildContext context, {required bool isMobile}) {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: controller.hasData ? _downloadJsonFile : null,
        icon: const Icon(Icons.download),
        label: Text(isMobile ? 'Herunterladen' : 'Download'),
      ),
      OutlinedButton.icon(
        onPressed: () => _uploadJsonFile(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      OutlinedButton.icon(
        onPressed: controller.hasData ? () => _copyJsonToClipboard(context) : null,
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Kopieren'),
      ),
    ];
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: buttons[i]),
          ],
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final ok = controller.lastStatusOk.value;
    final topic = controller.lastTopic.value;
    final updated = controller.lastUpdated.value;
    final remarks = controller.lastRemarks;
    final waiting = controller.waitingForResponse.value;

    final Color accent;
    final Color background;
    final IconData icon;
    final String headline;
    if (ok == true) {
      accent = Colors.green.shade700;
      background = Colors.green.shade50;
      icon = Icons.check_circle_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Settings-Status empfangen.' : controller.lastStatus.value;
    } else if (ok == false) {
      accent = Colors.red.shade700;
      background = Colors.red.shade50;
      icon = Icons.error_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Aktion fehlgeschlagen.' : controller.lastStatus.value;
    } else if (waiting) {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.06);
      icon = Icons.sync;
      headline = controller.lastStatus.value.isEmpty ? 'Warte auf Backend-Antwort ...' : controller.lastStatus.value;
    } else {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.04);
      icon = Icons.info_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Noch keine Rückmeldung.' : controller.lastStatus.value;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: accent.withOpacity(0.28)),
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
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Backend-Hinweise', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  ...remarks.map((remark) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('• $remark', style: Theme.of(context).textTheme.bodySmall),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewMetric(BuildContext context, {required String label, required String value, required IconData icon}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.18)),
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
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueChip(BuildContext context, {required String label, required String value, required bool emphasis}) {
    final color = emphasis ? Colors.orange.shade800 : Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _smallBadge(BuildContext context, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
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
        border: Border.all(color: color.withOpacity(0.65), width: 2),
      ),
      child: Icon(active ? icon : Icons.info_outline, color: color, size: 24),
    );
  }

  String _withUnit(String value, String unit) {
    if (value == '-' || unit.isEmpty) {
      return value;
    }
    return '$value $unit';
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on';
  }

  void _copyJsonToClipboard(BuildContext context) {
    _copyTextToClipboard(controller.rawStatusJson);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings-JSON wurde in die Zwischenablage kopiert.')));
  }



  Future<void> _uploadJsonFile(BuildContext context) async {
    try {
      final file = await pickTextFile(allowedExtensions: const <String>['json']);
      if (file == null) {
        return;
      }
      final imported = controller.importBackupJson(file.content, filename: file.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(imported
              ? 'Settings-JSON wurde lokal geladen. Bitte dauerhaft speichern, um es ans Backend zu übertragen.'
              : controller.lastStatus.value),
        ),
      );
    } catch (e) {
      controller.setError('JSON-Datei konnte nicht geladen werden: $e', topic: 'local/upload');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.lastStatus.value)));
    }
  }

  void _copyTextToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _downloadJsonFile() async {
    final jsonText = controller.rawStatusJson;
    final now = DateTime.now();
    final filename = 'openmower_mower_logic_settings_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    await saveTextFile(
      fileName: filename,
      content: jsonText,
      mimeType: 'application/json',
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
