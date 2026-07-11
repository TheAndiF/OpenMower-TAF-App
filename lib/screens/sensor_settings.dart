import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/sensors_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/models/sensor_state.dart';
import 'package:open_mower_app/services/platform_text_file.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class SensorSettingsScreen extends StatefulWidget {
  const SensorSettingsScreen({super.key});

  @override
  State<SensorSettingsScreen> createState() => _SensorSettingsScreenState();
}

class _SensorSettingsScreenState extends State<SensorSettingsScreen> {
  final SensorsController controller = Get.find<SensorsController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  bool _renewSent = false;
  bool _jsonExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestSensorSettings();
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
                _buildExpertModeSection(context),
                const SizedBox(height: 16),
                if (!expertMode)
                  _buildExpertOnly(context)
                else ...[
                  _buildOverviewSection(context),
                  const SizedBox(height: 16),
                  if (!controller.hasSensorSettings)
                    _buildEmptySettingsCard(context)
                  else
                    ...controller.settingGroupsForMode(expertModeEnabled: true).expand((group) sync* {
                      yield _buildGroupSection(context, group);
                      yield const SizedBox(height: 16);
                    }),
                  _buildJsonSection(context),
                ],
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
              'Blendet die Sensor-Einstellungen ein und zeigt editierbare JSON-Metadaten wie „group“, „order“, „visible“ und „expert“. Die Sensorwerte selbst bleiben readonly.',
            ),
            value: settingsController.expertModeEnabled.value,
            onChanged: settingsController.setExpertModeEnabled,
          )),
    );
  }

  Widget _buildExpertOnly(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_outline, size: 44, color: Theme.of(context).primaryColor),
            const SizedBox(height: 10),
            Text(
              'Sensor-Einstellungen sind nur im Expertenmodus sichtbar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Aktiviere den Expertenmodus, um Sensor-Metadaten ähnlich wie die Softwareeinstellungen zu gruppieren, zu sortieren und dauerhaft über MQTT zu speichern.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection(BuildContext context) {
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
                    _headerIcon(context, Icons.sensors_outlined, active: controller.hasSensorSettings),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sensor-Einstellungen',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dynamische Sensor-Metadaten aus sensors/settings/json bearbeiten. Aufbau und Bedienung folgen den Softwareeinstellungen.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final refreshButton = OutlinedButton.icon(
                  onPressed: waiting ? null : controller.requestSensorSettings,
                  icon: waiting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Status neu laden'),
                );
                if (isMobile) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 12), refreshButton]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: header), const SizedBox(width: 16), refreshButton]);
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
                    _overviewMetric(context, label: 'Metadaten', value: controller.sensorSettings.length.toString(), icon: Icons.list_alt),
                    _overviewMetric(context, label: 'Entwürfe', value: controller.dirtyCount.toString(), icon: Icons.edit_note),
                    _overviewMetric(context, label: 'Ausgeblendet', value: controller.hiddenSensorCount.toString(), icon: Icons.visibility_off_outlined),
                    _overviewMetric(context, label: 'Expert', value: controller.expertSensorCount.toString(), icon: Icons.admin_panel_settings_outlined),
                    _overviewMetric(context, label: 'Ohne Livewert', value: controller.missingLiveValueCount.toString(), icon: Icons.warning_amber_outlined),
                  ],
                ),
                const SizedBox(height: 14),
                _buildStatusCard(context),
              ],
            ),
          ),
        ],
      ),
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
              'Noch keine Sensor-Settings-Daten empfangen',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Sobald das Backend auf sensors/settings/json publiziert, werden Gruppen und Sensor-Metadaten hier automatisch aufgebaut.',
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
    final groupEntries = controller.settingsForGroup(group, expertModeEnabled: true);
    final dirty = controller.dirtyCountForGroup(group, expertModeEnabled: true);
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group == 'general' || group == 'host_system' || group == 'system',
          backgroundColor: color.withValues(alpha: 0.08),
          collapsedBackgroundColor: color.withValues(alpha: 0.08),
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
              Text('${groupEntries.length} Sensoren', style: Theme.of(context).textTheme.bodyMedium),
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
                  _buildGroupMetadataCard(context, group),
                  const SizedBox(height: 12),
                  for (var i = 0; i < groupEntries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildSensorSettingCard(context, groupEntries[i].key, groupEntries[i].value),
                  ],
                  const SizedBox(height: 14),
                  _buildGroupActions(context, group, dirty: dirty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMetadataCard(BuildContext context, String group) {
    final color = Theme.of(context).primaryColor;
    final dirty = controller.dirtyGroupKeys.contains(group);
    final revision = controller.editorRevision.value;
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
          final meta = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      controller.groupLabelDraftText(group),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (dirty) _smallBadge(context, 'Gruppe geändert', Icons.edit_outlined, color),
                ],
              ),
              const SizedBox(height: 2),
              Text('group key: $group', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 4),
              Text(
                'JSON groups.$group.label/order · order: ${controller.groupOrderDraftInt(group)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 10),
              _smallBadge(context, 'Gruppenobjekt', Icons.account_tree_outlined, Theme.of(context).hintColor),
            ],
          );

          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: ValueKey('sensor-group-label-$group-$revision'),
                initialValue: controller.groupLabelDraftText(group),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'JSON-Feld „groups.label“',
                  helperText: 'Anzeigename der Gruppe',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onChanged: (value) => controller.updateGroupDraftLabel(group, value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('sensor-group-order-$group-$revision'),
                initialValue: controller.groupOrderDraftInt(group).toString(),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'JSON-Feld „groups.order“',
                  helperText: 'Kleinere Zahl zeigt die Gruppe weiter oben an',
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                onChanged: (value) => controller.updateGroupDraftOrder(group, value),
              ),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [meta, const SizedBox(height: 12), editor],
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

  Widget _buildSensorSettingCard(BuildContext context, String key, Map<String, dynamic> setting) {
    final color = Theme.of(context).primaryColor;
    final dirty = controller.dirtyKeys.contains(key);
    final visible = controller.visibleDraftBool(key, setting);
    final expert = controller.expertDraftBool(key, setting);
    final sensor = controller.sensorStates[key];
    final hasLiveValue = sensor != null;
    final unit = setting['unit']?.toString() ?? sensor?.unit ?? '';
    final liveValue = _liveValueText(sensor, unit);
    final description = controller.descriptionDraftText(key, setting).trim();

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
          final meta = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      controller.labelDraftText(key, setting),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (dirty) _smallBadge(context, 'Metadaten geändert', Icons.edit_outlined, color),
                ],
              ),
              const SizedBox(height: 2),
              Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 4),
              Text(
                'JSON group: ${controller.groupDraftText(key, setting)} · order: ${controller.orderDraftInt(key, setting)} · expert: $expert',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _valueChip(context, label: 'Livewert', value: hasLiveValue ? liveValue : 'kein Wert', emphasis: !hasLiveValue),
                  if (unit.isNotEmpty) _valueChip(context, label: 'Einheit', value: unit),
                  _smallBadge(context, visible ? 'Sichtbar' : 'Ausgeblendet', visible ? Icons.visibility_outlined : Icons.visibility_off_outlined, visible ? Colors.green.shade700 : Colors.orange.shade800),
                  if (expert) _smallBadge(context, 'Nur Expertenmodus', Icons.admin_panel_settings_outlined, Theme.of(context).hintColor),
                  _smallBadge(context, 'Readonly', Icons.lock_outline, Theme.of(context).hintColor),
                ],
              ),
              const SizedBox(height: 8),
              Text('Topic: ${setting['value_topic']?.toString() ?? 'sensors/$key/data'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
            ],
          );

          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMetadataEditors(context, key, setting),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [meta, const SizedBox(height: 12), editor],
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
    final dirty = controller.dirtyKeys.contains(key);
    final revision = controller.editorRevision.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('sensor-setting-label-$key-$revision'),
          initialValue: controller.labelDraftText(key, setting),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'JSON-Feld „label“',
            helperText: dirty ? 'Wird erst beim dauerhaften Speichern gesendet' : 'Anzeigename der Sensorkarte',
            prefixIcon: const Icon(Icons.label_outline),
          ),
          onChanged: (value) => controller.updateDraftLabel(key, setting, value),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('sensor-setting-description-$key-$revision'),
          initialValue: controller.descriptionDraftText(key, setting),
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'JSON-Feld „description“',
            helperText: 'Beschreibung für die Sensor-Einstellung',
            prefixIcon: Icon(Icons.notes_outlined),
            alignLabelWithHint: true,
          ),
          onChanged: (value) => controller.updateDraftDescription(key, setting, value),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('sensor-setting-group-$key-$revision'),
          initialValue: controller.groupDraftText(key, setting),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'JSON-Feld „group“',
            helperText: 'String, nicht leer, maximal 80 Zeichen, keine Steuerzeichen',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          onChanged: (value) => controller.updateDraftGroup(key, setting, value),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('sensor-setting-order-$key-$revision'),
          initialValue: controller.orderDraftInt(key, setting).toString(),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'JSON-Feld „order“',
            helperText: 'Ganzzahl für die Sortierung innerhalb der Gruppe',
            prefixIcon: Icon(Icons.format_list_numbered),
          ),
          onChanged: (value) => controller.updateDraftOrder(key, setting, value),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: ValueKey('sensor-setting-visible-$key-$revision'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.visibility_outlined),
          title: const Text('JSON-Feld „visible“'),
          subtitle: const Text('false blendet den Sensor in der normalen Sensoransicht aus'),
          value: controller.visibleDraftBool(key, setting),
          onChanged: (value) => controller.updateDraftVisible(key, setting, value),
        ),
        SwitchListTile(
          key: ValueKey('sensor-setting-expert-$key-$revision'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('JSON-Feld „expert“'),
          subtitle: const Text('true blendet den Sensor im Normalmodus aus'),
          value: controller.expertDraftBool(key, setting),
          onChanged: (value) => controller.updateDraftExpert(key, setting, value),
        ),
      ],
    );
  }

  Widget _buildGroupActions(BuildContext context, String group, {required int dirty}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        TextButton.icon(
          onPressed: dirty > 0 ? () => controller.resetGroupDrafts(group, expertModeEnabled: true) : null,
          icon: const Icon(Icons.undo),
          label: const Text('Entwurf zurücksetzen'),
        ),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.flash_on_outlined),
          label: const Text('Jetzt anwenden'),
        ),
        ElevatedButton.icon(
          onPressed: controller.actionInProgress.value || dirty == 0 ? null : () => controller.savePersistentForGroup(group, expertModeEnabled: true),
          icon: controller.actionInProgress.value
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Dauerhaft speichern'),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status = controller.lastStatus.value;
    final ok = controller.lastStatusOk.value;
    final color = ok == false
        ? Theme.of(context).colorScheme.error
        : ok == true
            ? Colors.green.shade700
            : Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(ok == false ? Icons.error_outline : ok == true ? Icons.check_circle_outline : Icons.info_outline, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(status.isEmpty ? 'Noch keine Sensor-Settings-Antwort empfangen.' : status)),
            ],
          ),
          if (controller.lastTopic.value.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Topic: ${controller.lastTopic.value}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ],
          if (controller.lastRemarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...controller.lastRemarks.map((remark) => Text('• $remark', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ],
      ),
    );
  }

  Widget _buildJsonSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                                Text('Rohstatus aus sensors/settings/json anzeigen und exportieren', style: Theme.of(context).textTheme.bodyMedium),
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
                          key: ValueKey('sensor-settings-json-${controller.lastUpdated.value?.millisecondsSinceEpoch ?? 0}'),
                          initialValue: controller.rawSettingsJson,
                          readOnly: true,
                          minLines: 10,
                          maxLines: 24,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'sensors/settings/json',
                            alignLabelWithHint: true,
                          ),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _jsonActionButtons(BuildContext context, {required bool isMobile}) {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: controller.hasSensorSettings ? _downloadJsonFile : null,
        icon: const Icon(Icons.download),
        label: Text(isMobile ? 'Herunterladen' : 'Download'),
      ),
      OutlinedButton.icon(
        onPressed: () => _uploadJsonFile(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      OutlinedButton.icon(
        onPressed: controller.hasSensorSettings ? () => _copyJsonToClipboard(context) : null,
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

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = active ? Theme.of(context).primaryColor : Theme.of(context).hintColor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color),
    );
  }

  Widget _overviewMetric(BuildContext context, {required String label, required String value, required IconData icon}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueChip(BuildContext context, {required String label, required String value, bool emphasis = false}) {
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: emphasis ? Theme.of(context).primaryColor.withValues(alpha: 0.10) : null,
      side: BorderSide(color: emphasis ? Theme.of(context).primaryColor.withValues(alpha: 0.35) : Theme.of(context).dividerColor),
      label: Text('$label: $value', overflow: TextOverflow.ellipsis),
    );
  }

  Widget _smallBadge(BuildContext context, String text, IconData icon, Color color) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }

  String _liveValueText(SensorState? sensor, String unit) {
    if (sensor == null) return '-';
    if (sensor is DoubleSensorState) {
      final text = sensor.value.toStringAsFixed(sensor.value.truncateToDouble() == sensor.value ? 0 : 2);
      return unit.isEmpty ? text : '$text $unit';
    }
    if (sensor is StringSensorState) {
      final value = sensor.value.trim();
      if (value.isEmpty) return '-';
      return unit.isEmpty ? value : '$value $unit';
    }
    return '-';
  }

  Future<void> _uploadJsonFile(BuildContext context) async {
    try {
      final file = await pickTextFile(allowedExtensions: const <String>['json']);
      if (file == null) {
        return;
      }
      final imported = controller.importBackupJson(file.content, filename: file.name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(imported
              ? 'Sensor-Settings-JSON wurde lokal geladen. Bitte dauerhaft speichern, um es ans Backend zu übertragen.'
              : controller.lastStatus.value),
        ),
      );
    } catch (e) {
      controller.setError('JSON-Datei konnte nicht geladen werden: $e', topic: 'local/upload');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.lastStatus.value)));
    }
  }

  void _copyJsonToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: controller.rawSettingsJson));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sensor-Settings-JSON wurde in die Zwischenablage kopiert.')));
  }

  Future<void> _downloadJsonFile() async {
    final now = DateTime.now();
    final filename = 'openmower_sensor_settings_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    await saveTextFile(
      fileName: filename,
      content: controller.rawSettingsJson,
      mimeType: 'application/json',
    );
  }
}
