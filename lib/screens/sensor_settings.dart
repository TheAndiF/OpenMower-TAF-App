import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/sensors_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
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
          if (!settingsController.expertModeEnabled.value) {
            return _buildExpertOnly(context);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewSection(context),
                const SizedBox(height: 16),
                _buildExpertHintSection(context),
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

  Widget _buildExpertOnly(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 76, 16, 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Theme.of(context).hintColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sensor-Einstellungen sind nur im Expertenmodus sichtbar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
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
                            'Sensor-Metadaten bearbeiten und dauerhaft über sensors/settings/set/persistent/json speichern.',
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

  Widget _buildExpertHintSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            border: Border.all(color: color.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Diese Unterseite ist nur im Expertenmodus verfügbar. Bearbeitet werden ausschließlich Sensor-Metadaten wie Label, Beschreibung, Gruppe, Reihenfolge, Sichtbarkeit und Experten-Markierung. Livewerte bleiben unverändert unter sensors/<sensor_id>/data.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySettingsCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Keine Sensor-Metadaten empfangen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Bitte sensors/settings/json prüfen oder den Status neu laden.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(BuildContext context, String group) {
    final entries = controller.settingsForGroup(group, expertModeEnabled: true);
    final dirty = controller.dirtyCountForGroup(group, expertModeEnabled: true);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(controller.groupIcon(group)),
        title: Text(controller.groupLabel(group)),
        subtitle: Text('${entries.length} Sensoren${dirty > 0 ? ' - $dirty geändert' : ''}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  _buildSensorEditor(context, entries[i].key, entries[i].value),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => controller.resetGroupDrafts(group, expertModeEnabled: true),
                      icon: const Icon(Icons.undo),
                      label: const Text('Änderungen verwerfen'),
                    ),
                    ElevatedButton.icon(
                      onPressed: controller.actionInProgress.value ? null : () => controller.savePersistentForGroup(group, expertModeEnabled: true),
                      icon: controller.actionInProgress.value
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Dauerhaft speichern'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorEditor(BuildContext context, String key, Map<String, dynamic> setting) {
    final revision = controller.editorRevision.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.labelDraftText(key, setting), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            if (controller.dirtyKeys.contains(key))
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.edit, size: 16),
                label: const Text('Entwurf'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 720;
            final fields = [
              _textField(
                key: ValueKey('label-$key-$revision'),
                label: 'Anzeigename',
                initialValue: controller.labelDraftText(key, setting),
                onChanged: (value) => controller.updateDraftLabel(key, setting, value),
              ),
              _textField(
                key: ValueKey('group-$key-$revision'),
                label: 'Gruppe',
                initialValue: controller.groupDraftText(key, setting),
                onChanged: (value) => controller.updateDraftGroup(key, setting, value),
              ),
              _textField(
                key: ValueKey('order-$key-$revision'),
                label: 'Reihenfolge',
                initialValue: controller.orderDraftInt(key, setting).toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) => controller.updateDraftOrder(key, setting, value),
              ),
            ];
            if (!twoColumns) {
              return Column(children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 10), child: field)).toList());
            }
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: fields.map((field) => SizedBox(width: (constraints.maxWidth - 24) / 3, child: field)).toList(),
            );
          },
        ),
        const SizedBox(height: 10),
        _textField(
          key: ValueKey('description-$key-$revision'),
          label: 'Beschreibung',
          initialValue: controller.descriptionDraftText(key, setting),
          minLines: 2,
          maxLines: 4,
          onChanged: (value) => controller.updateDraftDescription(key, setting, value),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            SizedBox(
              width: 220,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sichtbar'),
                value: controller.visibleDraftBool(key, setting),
                onChanged: (value) => controller.updateDraftVisible(key, setting, value),
              ),
            ),
            SizedBox(
              width: 260,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nur Expertenmodus'),
                value: controller.expertDraftBool(key, setting),
                onChanged: (value) => controller.updateDraftExpert(key, setting, value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _infoChip(context, 'Typ', setting['type']?.toString() ?? setting['value_type']?.toString() ?? '-'),
            _infoChip(context, 'Einheit', setting['unit']?.toString() ?? '-'),
            _infoChip(context, 'ROS-Name', setting['sensor_name']?.toString() ?? '-'),
            _infoChip(context, 'Topic', setting['value_topic']?.toString() ?? 'sensors/$key/data'),
          ],
        ),
      ],
    );
  }

  Widget _textField({
    required Key key,
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      initialValue: initialValue,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
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
        border: Border.all(color: color.withOpacity(0.35)),
        color: color.withOpacity(0.06),
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
            Text('Topic: ${controller.lastTopic.value}', style: Theme.of(context).textTheme.bodySmall),
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
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: _jsonExpanded,
        onExpansionChanged: (value) => setState(() => _jsonExpanded = value),
        leading: const Icon(Icons.data_object),
        title: const Text('JSON / Diagnose'),
        subtitle: const Text('Rohdaten aus sensors/settings/json'),
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(controller.rawSettingsJson, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = active ? Theme.of(context).primaryColor : Theme.of(context).hintColor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
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

  Widget _infoChip(BuildContext context, String label, String value) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $value', overflow: TextOverflow.ellipsis),
    );
  }
}
