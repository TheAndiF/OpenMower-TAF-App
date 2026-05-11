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
          final areas = controller.areas;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(
                  context,
                  icon: Icons.grass,
                  title: 'Mähzeiten',
                  subtitle: 'MQTT-Flächen aus map/bson anzeigen',
                  child: _buildAreasSection(context, areas),
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

  Widget _buildAreasSection(BuildContext context, List<Map<String, dynamic>> areas) {
    if (!controller.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Noch keine MQTT-Flächen empfangen. Sobald ein map/bson Payload eintrifft, erscheinen die Flächen hier.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (areas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Der letzte MQTT-Payload enthält keine areas- oder working_areas-Liste.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: areas.map((area) => _areaCard(context, area)).toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Typ')),
              DataColumn(label: Text('Aktiv')),
              DataColumn(label: Text('Reihenfolge')),
              DataColumn(label: Text('Punkte')),
            ],
            rows: areas.map((area) {
              final props = controller.propertiesFor(area);
              return DataRow(
                cells: [
                  DataCell(Text(_areaName(area, props))),
                  DataCell(Text(_shortId((area['id'] ?? props['id'] ?? '').toString()))),
                  DataCell(Text((props['type'] ?? area['type'] ?? '-').toString())),
                  DataCell(Icon(_mowingEnabled(props) ? Icons.check_circle_outline : Icons.radio_button_unchecked)),
                  DataCell(Text((props['mowing_order'] ?? '-').toString())),
                  DataCell(Text(controller.pointCountFor(area).toString())),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _areaCard(BuildContext context, Map<String, dynamic> area) {
    final props = controller.propertiesFor(area);
    final color = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grass, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _areaName(area, props),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailLine(context, 'ID', (area['id'] ?? props['id'] ?? '-').toString()),
          _detailLine(context, 'Typ', (props['type'] ?? area['type'] ?? '-').toString()),
          _detailLine(context, 'Aktiv', _mowingEnabled(props) ? 'Ja' : 'Nein'),
          _detailLine(context, 'Reihenfolge', (props['mowing_order'] ?? '-').toString()),
          _detailLine(context, 'Punkte', controller.pointCountFor(area).toString()),
        ],
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
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

  String _areaName(Map<String, dynamic> area, Map<String, dynamic> props) {
    final name = (props['name'] ?? area['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }
    return _shortId((area['id'] ?? props['id'] ?? 'Unbenannte Fläche').toString());
  }

  String _shortId(String value) {
    if (value.length <= 12) return value.isEmpty ? '-' : value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 4)}';
  }

  bool _mowingEnabled(Map<String, dynamic> props) {
    final value = props['mowing_enabled'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().toLowerCase() == 'true';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
