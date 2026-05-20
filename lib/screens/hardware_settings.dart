import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/low_level_power_settings_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class HardwareSettingsScreen extends StatefulWidget {
  const HardwareSettingsScreen({super.key});

  @override
  State<HardwareSettingsScreen> createState() => _HardwareSettingsScreenState();
}

class _HardwareSettingsScreenState extends State<HardwareSettingsScreen> {
  final LowLevelPowerSettingsController controller = Get.find<LowLevelPowerSettingsController>();
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
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverview(context),
                const SizedBox(height: 16),
                _buildHardwareSettings(context),
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

  Widget _buildOverview(BuildContext context) {
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
                            'Grenzwerte und Schutzparameter des Low-Level-Boards verwalten',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final refresh = OutlinedButton.icon(
                  onPressed: waiting ? null : controller.requestStatus,
                  icon: waiting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Status neu laden'),
                );
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, const SizedBox(height: 12), refresh],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: header), const SizedBox(width: 16), refresh],
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
                    _overviewMetric(context, label: 'Parameter', value: LowLevelPowerSettingsController.orderedKeys.length.toString(), icon: Icons.list_alt),
                    _overviewMetric(context, label: 'Entwürfe', value: controller.dirtyCount.toString(), icon: Icons.edit_note),
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
                    '„Jetzt anwenden“ verändert nur die laufende Session. „Dauerhaft speichern“ setzt persistent und active und schreibt die persistente Settings-Datei.',
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

  Widget _buildHardwareSettings(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final waiting = controller.waitingForResponse.value;
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
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
              const Text('settings/ll_board'),
              if (controller.dirtyCount > 0) Text('${controller.dirtyCount} lokale Änderung(en)'),
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
                      'Die Hardwarewerte werden über settings/ll_board/set/session/json live getestet oder über settings/ll_board/set/persistent/json dauerhaft gespeichert.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!controller.hasData)
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
                      _buildValueCard(context, LowLevelPowerSettingsController.orderedKeys[i]),
                    ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 720;
                      final actions = <Widget>[
                        OutlinedButton.icon(
                          onPressed: waiting ? null : controller.requestStatus,
                          icon: waiting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: const Text('LL-Board neu laden'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.dirtyCount == 0 || waiting ? null : controller.resetDrafts,
                          icon: const Icon(Icons.undo),
                          label: const Text('Änderungen verwerfen'),
                        ),
                        ElevatedButton.icon(
                          onPressed: controller.dirtyCount == 0 || waiting ? null : controller.applySessionChanges,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Jetzt anwenden'),
                        ),
                        ElevatedButton.icon(
                          onPressed: controller.dirtyCount == 0 || waiting ? null : controller.savePersistentChanges,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Dauerhaft speichern'),
                        ),
                      ];
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: actions.expand((button) => <Widget>[button, const SizedBox(height: 10)]).toList()..removeLast(),
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
                          controller.rawStatusJson,
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

  Widget _buildValueCard(BuildContext context, String key) {
    final color = Theme.of(context).primaryColor;
    final dirty = controller.dirtyKeys.contains(key);
    final unit = controller.unitFor(key);
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
                      controller.labelFor(key),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (dirty) _smallBadge(context, 'Geändert', Icons.edit_outlined, color),
                ],
              ),
              const SizedBox(height: 2),
              Text(key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 8),
              Text(controller.descriptionFor(key), style: Theme.of(context).textTheme.bodySmall),
              if (controller.rangeText(key).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(controller.rangeText(key), style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              _valueChip(context, label: 'Aktiv', value: _withUnit(controller.activeText(key), unit), emphasis: dirty),
            ],
          );
          final field = TextFormField(
            key: ValueKey('ll_board_${key}_${controller.editorRevision.value}'),
            initialValue: controller.draftText(key),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.\-]'))],
            onChanged: (value) => controller.updateDraftText(key, value),
            decoration: InputDecoration(
              labelText: 'Neuer Wert',
              suffixText: unit.isEmpty ? null : unit,
              border: const OutlineInputBorder(),
              helperText: 'Wird als JSON-number gesendet.',
            ),
          );
          if (isMobile) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [meta, const SizedBox(height: 12), field]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: meta), const SizedBox(width: 16), Expanded(flex: 2, child: field)]);
        },
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
