import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/remote_controller.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

const List<String> _kSkipPathActions = [
  'mower_logic:mowing/skip_path',
  'mower_logic:mowing/skip_current_path',
  'mower_logic:mowing/skip_segment',
  'mower_logic:mowing/skip_current_segment',
];

String? _firstAvailableAction(RobotStateController controller, List<String> actions) {
  for (final action in actions) {
    if (controller.hasAction(action)) {
      return action;
    }
  }
  return null;
}

class AdvancedOptions extends GetView<RobotStateController> {
  AdvancedOptions({super.key});

  final RemoteController remoteControl = Get.find<RemoteController>();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOverviewSection(context),
              const SizedBox(height: 16),
              _buildManualMowingSection(context),
            ],
          ),
        ),
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
    return Obx(() {
      final currentArea = controller.robotState.value.currentArea;
      final currentPath = controller.robotState.value.currentPathIndex;
      final skipAreaAvailable = controller.hasAction('mower_logic:mowing/skip_area');
      final skipPathAction = _firstAvailableAction(controller, _kSkipPathActions);
      final skipPathAvailable = skipPathAction != null;

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
                      _headerIcon(context, Icons.settings_applications_outlined, active: skipAreaAvailable || skipPathAvailable),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced Options',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Erweiterte Aktionen für Mählogik und manuelle Flächensteuerung',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final skipAreaButton = OutlinedButton.icon(
                    onPressed: skipAreaAvailable
                        ? () => remoteControl.callAction('mower_logic:mowing/skip_area')
                        : null,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Aktuelle Fläche überspringen'),
                  );
                  final skipPathButton = OutlinedButton.icon(
                    onPressed: skipPathAction == null
                        ? null
                        : () => remoteControl.callAction(skipPathAction),
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Aktuellen Pfad überspringen'),
                  );
                  final actionButtons = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      skipAreaButton,
                      const SizedBox(height: 8),
                      skipPathButton,
                    ],
                  );
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, const SizedBox(height: 12), actionButtons],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: header),
                      const SizedBox(width: 16),
                      SizedBox(width: 280, child: actionButtons),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statusChip(
                    context,
                    icon: Icons.grass,
                    label: 'Aktuelle Fläche',
                    value: currentArea >= 0 ? currentArea.toString() : '-',
                  ),
                  _statusChip(
                    context,
                    icon: skipAreaAvailable ? Icons.check_circle_outline : Icons.block,
                    label: 'Fläche skippen',
                    value: skipAreaAvailable ? 'Verfügbar' : 'Nicht verfügbar',
                  ),
                  _statusChip(
                    context,
                    icon: Icons.route_outlined,
                    label: 'Aktueller Pfad',
                    value: currentPath >= 0 ? currentPath.toString() : '-',
                  ),
                  _statusChip(
                    context,
                    icon: skipPathAvailable ? Icons.check_circle_outline : Icons.block,
                    label: 'Pfad skippen',
                    value: skipPathAvailable ? 'Verfügbar' : 'Nicht verfügbar',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildManualMowingSection(BuildContext context) {
    return Obx(() {
      final stopAvailable = controller.hasAction('mower_logic:area_recording/stop_manual_mowing');
      final startAvailable = controller.hasAction('mower_logic:area_recording/start_manual_mowing');

      return Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerIcon(context, Icons.route_outlined, active: startAvailable || stopAvailable),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual Mowing',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manuelles Mähen starten oder eine laufende manuelle Aufzeichnung stoppen',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: stopAvailable
                    ? ElevatedButton.icon(
                        onPressed: () => remoteControl.callAction('mower_logic:area_recording/stop_manual_mowing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Manual Mowing stoppen'),
                      )
                    : ElevatedButton.icon(
                        onPressed: startAvailable
                            ? () => remoteControl.callAction('mower_logic:area_recording/start_manual_mowing')
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Manual Mowing starten'),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statusChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final color = Theme.of(context).primaryColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: active ? color : color.withValues(alpha: 0.55), size: 28),
    );
  }
}
