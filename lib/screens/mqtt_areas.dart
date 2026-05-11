import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class MqttAreasScreen extends StatefulWidget {
  const MqttAreasScreen({super.key});

  @override
  State<MqttAreasScreen> createState() => _MqttAreasScreenState();
}

class _MqttAreasScreenState extends State<MqttAreasScreen> {
  final MqttAreasController controller = Get.find<MqttAreasController>();
  bool _jsonExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final mowAreas = controller.mowAreas;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(
                  context,
                  icon: Icons.grass,
                  title: 'Mähzeiten',
                  subtitle: 'Nur MQTT-Flächen vom Typ mow, sortiert nach Mähreihenfolge',
                  child: _buildMowAreasSection(context, mowAreas),
                ),
                const SizedBox(height: 16),
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

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final color = Theme.of(context).primaryColor;
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
          leading: Icon(icon, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMowAreasSection(BuildContext context, List<Map<String, dynamic>> mowAreas) {
    if (!controller.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Noch keine MQTT-Flächen empfangen. Sobald ein map/bson Payload eintrifft, erscheinen die Mähflächen hier.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (mowAreas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Der letzte MQTT-Payload enthält keine Fläche mit properties.type = mow.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        for (final area in mowAreas) _mowAreaTimeBox(context, area),
      ],
    );
  }

  Widget _mowAreaTimeBox(BuildContext context, Map<String, dynamic> area) {
    final color = Theme.of(context).primaryColor;
    final enabled = controller.mowingEnabledFor(area);
    final order = controller.mowingOrderFor(area);
    final name = controller.areaNameFor(area);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final content = <Widget>[
            _readOnlyField(
              context,
              label: 'Name',
              value: name,
              flex: isCompact ? 1 : 4,
              icon: Icons.grass,
            ),
            _readOnlyField(
              context,
              label: 'Mähreihenfolge',
              value: order?.toString() ?? '-',
              flex: isCompact ? 1 : 1,
              icon: Icons.format_list_numbered,
            ),
            _enabledSwitchBox(context, enabled),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content[0],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: content[1]),
                    const SizedBox(width: 16),
                    content[2],
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 4, child: content[0]),
              const SizedBox(width: 16),
              SizedBox(width: 170, child: content[1]),
              const SizedBox(width: 20),
              content[2],
              const Spacer(),
              Icon(Icons.drag_indicator, color: color.withOpacity(0.45)),
            ],
          );
        },
      ),
    );
  }

  Widget _readOnlyField(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    int flex = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).hintColor),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _enabledSwitchBox(BuildContext context, bool enabled) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aktiv', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
            const SizedBox(height: 2),
            Text(enabled ? 'aktiviert' : 'nicht aktiviert', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(width: 10),
        IgnorePointer(
          child: Switch(
            value: enabled,
            onChanged: (_) {},
          ),
        ),
      ],
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
                  child: Row(
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
                            Text('Rohdaten des letzten MQTT-Flächen-Payloads', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.hasData ? () => _copyJsonToClipboard(context) : null,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Kopieren'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: _jsonExpanded ? 'JSON-Ansicht einklappen' : 'JSON-Ansicht ausklappen',
                        onPressed: () => setState(() => _jsonExpanded = !_jsonExpanded),
                        icon: Icon(_jsonExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: color),
                      ),
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
                        TextField(
                          controller: controller.rawJsonController,
                          readOnly: true,
                          minLines: 10,
                          maxLines: 22,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'map.json',
                            alignLabelWithHint: true,
                            helperText: 'Anzeige des zuletzt empfangenen map/bson Payloads als JSON-String.',
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

  Widget _buildStatusCard(BuildContext context) {
    final ok = controller.lastStatusOk.value;
    final topic = controller.lastTopic.value;
    final updated = controller.lastUpdated.value;

    final Color accent;
    final Color background;
    final IconData icon;
    final String headline;
    if (ok == true) {
      accent = Colors.green.shade700;
      background = Colors.green.shade50;
      icon = Icons.check_circle_outline;
      headline = controller.lastStatus.value;
    } else if (ok == false) {
      accent = Colors.red.shade700;
      background = Colors.red.shade50;
      icon = Icons.error_outline;
      headline = controller.lastStatus.value;
    } else {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.04);
      icon = Icons.info_outline;
      headline = 'Noch keine MQTT-Flächen empfangen.';
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _copyJsonToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: controller.rawJsonController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON wurde in die Zwischenablage kopiert.')),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
