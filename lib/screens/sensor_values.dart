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
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metricWidth = (constraints.maxWidth * 0.52).clamp(180.0, 520.0).toDouble();
          final showDescription = constraints.maxWidth >= 760;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _headerIcon(context, Icons.sensors_outlined, active: controller.sensorStates.isNotEmpty),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Sensoren',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (showDescription) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            controller.hasSensorSettings
                                ? 'Livewerte als Anzeige - Metadaten aus sensors/settings/json.'
                                : 'Livewerte als Anzeige - Fallback-Gruppierung bis sensors/settings/json verfügbar ist.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: metricWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _overviewMetric(context, label: 'Sensoren', value: controller.sensorStates.length.toString(), icon: Icons.line_axis),
                        const SizedBox(width: 6),
                        _overviewMetric(context, label: 'Gruppen', value: controller.groupsForMode(expertModeEnabled: true).length.toString(), icon: Icons.folder_outlined),
                        const SizedBox(width: 6),
                        _overviewMetric(context, label: 'Ausgeblendet', value: controller.hiddenSensorCount.toString(), icon: Icons.visibility_off_outlined),
                        const SizedBox(width: 6),
                        _overviewMetric(context, label: 'Experten', value: controller.expertSensorCount.toString(), icon: Icons.admin_panel_settings_outlined),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, String group, {required bool expertModeEnabled}) {
    final sensors = controller.visibleSensorsForGroup(group, expertModeEnabled: expertModeEnabled);
    final includeLoadFactorTile = _shouldShowLoadFactorInGroup(group, expertModeEnabled: expertModeEnabled);
    if (sensors.isEmpty && !includeLoadFactorTile) return const SizedBox.shrink();
    final theme = Theme.of(context);
    const sensorTextColor = Colors.black54;
    final tileCount = sensors.length + (includeLoadFactorTile ? 1 : 0);

    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF3F3F3),
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        iconColor: sensorTextColor,
        collapsedIconColor: sensorTextColor,
        textColor: sensorTextColor,
        collapsedTextColor: sensorTextColor,
        backgroundColor: const Color(0xFFF3F3F3),
        collapsedBackgroundColor: const Color(0xFFF3F3F3),
        leading: Icon(controller.groupIcon(group), color: sensorTextColor, size: 22),
        title: Row(
          children: [
            Flexible(
              child: Text(
                controller.groupLabel(group),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: sensorTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '· $tileCount Sensoren',
              style: theme.textTheme.bodySmall?.copyWith(color: sensorTextColor),
            ),
          ],
        ),
        children: [
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 1.0,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: tileCount,
              itemBuilder: (context, index) {
                if (includeLoadFactorTile && index == 0) {
                  return const LoadFactorStatusWidget();
                }
                final sensorIndex = index - (includeLoadFactorTile ? 1 : 0);
                return SensorWidget(sensor: sensors[sensorIndex].value);
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowLoadFactorInGroup(String group, {required bool expertModeEnabled}) {
    final allSensors = controller.visibleSensorsForMode(expertModeEnabled: expertModeEnabled);
    final hasDedicatedLoadFactor = allSensors.any(
      (entry) => entry.key == 'mow_load_factor' || entry.key == 'om_mow_load_factor',
    );
    if (hasDedicatedLoadFactor || allSensors.isEmpty) {
      return false;
    }

    final groups = controller.groupsForMode(expertModeEnabled: expertModeEnabled);
    const preferredGroups = ['openmower', 'mowing_motor', 'general'];
    for (final preferred in preferredGroups) {
      if (groups.contains(preferred)) {
        return group == preferred;
      }
    }
    return groups.isNotEmpty && group == groups.first;
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
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _overviewMetric(BuildContext context, {required String label, required String value, required IconData icon}) {
    return Container(
      width: 122,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 7),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
