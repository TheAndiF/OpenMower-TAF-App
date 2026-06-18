import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_mower_app/controllers/sensors_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/views/load_factor_status_widget.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';
import 'package:open_mower_app/views/sensor_widget.dart';

class SensorValues extends GetView<SensorsController> {
  const SensorValues({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    return n.Stack(
      [
        Obx(() {
          final groups = controller.groupsForMode(
            expertModeEnabled: settingsController.expertModeEnabled.value,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 72, 12, 12),
            children: [
              _buildOverviewCard(context),
              const SizedBox(height: 12),
              const LoadFactorStatusWidget(),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                _buildEmptyCard(context)
              else
                ...groups.expand((group) sync* {
                  yield _buildGroupCard(
                    context,
                    group,
                    expertModeEnabled: settingsController.expertModeEnabled.value,
                  );
                  yield const SizedBox(height: 12);
                }),
            ],
          );
        }),
        const RobotStateWidget(),
      ],
    )..fullSize;
  }

  Widget _buildOverviewCard(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerIcon(context, Icons.sensors_outlined, active: controller.sensorStates.isNotEmpty),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensoren',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Livewerte bleiben reine Anzeige. Gruppierung, Reihenfolge und Sichtbarkeit kommen aus sensors/settings/json.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _overviewMetric(context, label: 'Sensoren', value: controller.sensorStates.length.toString(), icon: Icons.line_axis),
                _overviewMetric(context, label: 'Gruppen', value: controller.groupsForMode(expertModeEnabled: true).length.toString(), icon: Icons.folder_outlined),
                _overviewMetric(context, label: 'Ausgeblendet', value: controller.hiddenSensorCount.toString(), icon: Icons.visibility_off_outlined),
                _overviewMetric(context, label: 'Expertenwerte', value: controller.expertSensorCount.toString(), icon: Icons.admin_panel_settings_outlined),
              ],
            ),
            if (!controller.hasSensorSettings) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  border: Border.all(color: color.withOpacity(0.18)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Noch keine Sensor-Metadaten empfangen. Bis sensors/settings/json verfügbar ist, nutzt die App eine lokale Fallback-Gruppierung.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, String group, {required bool expertModeEnabled}) {
    final sensors = controller.visibleSensorsForGroup(group, expertModeEnabled: expertModeEnabled);
    if (sensors.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(controller.groupIcon(group)),
        title: Text(controller.groupLabel(group)),
        subtitle: Text('${sensors.length} Sensoren'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 170).floor().clamp(1, 8);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: sensors.length,
                  itemBuilder: (context, index) => SensorWidget(sensor: sensors[index].value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Noch keine Sensorwerte empfangen.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = active ? Theme.of(context).primaryColor : Theme.of(context).hintColor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _overviewMetric(BuildContext context, {required String label, required String value, required IconData icon}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
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
}
