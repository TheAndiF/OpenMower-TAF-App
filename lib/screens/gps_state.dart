import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/gps_state_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class GpsStateScreen extends StatefulWidget {
  const GpsStateScreen({super.key});

  @override
  State<GpsStateScreen> createState() => _GpsStateScreenState();
}

class _GpsStateScreenState extends State<GpsStateScreen> {
  final GpsStateController controller = Get.find<GpsStateController>();
  bool _renewSent = false;
  bool _rawJsonExpanded = false;

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
        Obx(() => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 72, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverviewHeader(context),
                  const SizedBox(height: 12),
                  _buildState1Section(context),
                  const SizedBox(height: 10),
                  _buildState2Section(context),
                  const SizedBox(height: 10),
                  _buildState3Section(context),
                  const SizedBox(height: 10),
                  _buildState4Section(context),
                  const SizedBox(height: 10),
                  _buildSettingsSection(context),
                  const SizedBox(height: 10),
                  _buildRawJsonSection(context),
                  const SizedBox(height: 10),
                  Text(
                    'Hinweis: State4 ist standardmäßig deaktiviert, um MQTT-Datenmenge und Ressourcen zu schonen.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            )),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RobotStateWidget(),
        ),
      ],
    );
  }

  Widget _buildOverviewHeader(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = controller.waitingForResponse.value;
    final statusColor = controller.lastStatusOk.value == false
        ? Colors.orange.shade700
        : controller.hasState
            ? Colors.green.shade700
            : theme.hintColor;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;
            final title = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerIcon(context, Icons.satellite_alt_outlined, active: controller.hasState),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS-State',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live-Daten der GPS-Satelliten und Empfangsqualität aus gps_state/#.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                      ),
                      if (controller.lastStatus.value.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                controller.lastStatus.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
            final refresh = OutlinedButton.icon(
              onPressed: waiting ? null : controller.requestStatus,
              icon: waiting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: const Text('Status neu laden'),
            );
            if (isMobile) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 10), refresh]);
            }
            return Row(children: [Expanded(child: title), const SizedBox(width: 16), refresh]);
          },
        ),
      ),
    );
  }

  Widget _buildState1Section(BuildContext context) {
    final state = controller.state1;
    return _sectionCard(
      context,
      icon: Icons.gps_fixed_outlined,
      title: 'Übersicht (State1)',
      subtitle: state.isEmpty ? 'Noch keine Daten empfangen' : null,
      active: _bool(state['available']),
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricTile(context, 'Verfügbar', _bool(state['available']) ? 'Ja' : 'Nein', accent: _bool(state['available'])),
              _metricTile(context, 'Qualität', _text(state['quality'], fallback: '-'), accent: _qualityGood(state['quality'])),
              _metricTile(context, 'Sichtbar', _fmt(state['visible'])),
              _metricTile(context, 'Verwendet', _fmt(state['used'])),
              _metricTile(context, 'Ø C/N0', '${_fmt(state['avg_cn0'])} dB-Hz', accent: _double(state['avg_cn0']) >= 30),
              _metricTile(context, 'Aktualisiert', _updatedAtText(state['updated_at'])),
            ],
          ),
          const SizedBox(height: 10),
          _freshnessHint(context, state['updated_at']),
        ],
      ),
    );
  }

  Widget _buildState2Section(BuildContext context) {
    final state = controller.state2;
    final systems = state['systems'];
    return _sectionCard(
      context,
      icon: Icons.signal_cellular_alt,
      title: 'Signalqualität (State2)',
      subtitle: state.isEmpty ? 'Noch keine erweiterten Qualitätsdaten empfangen' : null,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricTile(context, 'Min C/N0', '${_fmt(state['min_cn0'])} dB-Hz'),
              _metricTile(context, 'Max C/N0', '${_fmt(state['max_cn0'])} dB-Hz'),
              _metricTile(context, 'Schwach', _fmt(state['weak_count']), warning: _int(state['weak_count']) > 0),
              _metricTile(context, 'Gut', _fmt(state['good_count']), accent: _int(state['good_count']) > 0),
            ],
          ),
          const SizedBox(height: 12),
          Text('Systemverteilung', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (systems is Map && systems.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: systems.entries.map((entry) => Chip(label: Text('${entry.key} ${entry.value}'))).toList(growable: false),
            )
          else
            Text('Keine Systemverteilung empfangen.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(
            'Schwellen: schwach < ${controller.settingDouble('weak_cn0_threshold', fallback: 20).toStringAsFixed(1)} dB-Hz, gut ≥ ${controller.settingDouble('good_cn0_threshold', fallback: 30).toStringAsFixed(1)} dB-Hz',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildState3Section(BuildContext context) {
    final satellites = controller.satellitesForState(3);
    return _sectionCard(
      context,
      icon: Icons.hub_outlined,
      title: 'Verwendete Satelliten (State3)',
      subtitle: satellites.isEmpty ? 'Noch keine verwendeten Satelliten empfangen' : 'Gesamt verwendet: ${satellites.length}',
      initiallyExpanded: true,
      child: _satelliteTable(context, satellites, showUsed: false),
    );
  }

  Widget _buildState4Section(BuildContext context) {
    final satellites = controller.satellitesForState(4);
    final active = controller.state4Active;
    return _sectionCard(
      context,
      icon: Icons.satellite_outlined,
      title: 'Alle Satelliten (State4)',
      subtitle: active ? 'Aktiv - vollständige Satellitenliste' : 'Deaktiviert - nur bei Diagnose aktivieren',
      active: active,
      initiallyExpanded: active,
      trailing: active
          ? TextButton.icon(
              onPressed: () => controller.setState4Enabled(false),
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Deaktivieren'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (active ? Colors.green : Colors.orange).withOpacity(0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(active ? Icons.info_outline : Icons.warning_amber_outlined, color: active ? Colors.green.shade700 : Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(active
                      ? 'State4 ist aktiv. Es werden alle sichtbaren Satelliten übertragen.'
                      : 'State4 erzeugt mehr MQTT-Daten und sollte nur zur Diagnose aktiviert werden.'),
                ),
                const SizedBox(width: 8),
                if (!active)
                  OutlinedButton(
                    onPressed: () => controller.setState4Enabled(true),
                    child: const Text('State4 temporär aktivieren'),
                  ),
              ],
            ),
          ),
          if (satellites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Gesamt sichtbar: ${satellites.length}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _satelliteTable(context, satellites, showUsed: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.settings_outlined,
      title: 'GPS-State-Einstellungen',
      subtitle: controller.hasSettings ? '${GpsStateController.settingKeys.length} bekannte Settings' : 'Noch keine Settings empfangen',
      initiallyExpanded: controller.dirtyKeys.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...GpsStateController.settingKeys.map((key) => _settingRow(context, key)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: controller.dirtyKeys.isEmpty ? null : controller.applySession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Jetzt anwenden (Session)'),
              ),
              ElevatedButton.icon(
                onPressed: controller.dirtyKeys.isEmpty ? null : controller.applyPersistent,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Dauerhaft speichern'),
              ),
              OutlinedButton.icon(
                onPressed: controller.requestStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Status neu laden'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRawJsonSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: _rawJsonExpanded,
        onExpansionChanged: (expanded) => setState(() => _rawJsonExpanded = expanded),
        leading: const Icon(Icons.code),
        title: const Text('Raw JSON / Debug'),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF7F7F7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(ClipboardData(text: controller.rawJson)),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Kopieren'),
                    ),
                  ],
                ),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(jsonDecode(controller.rawJson)),
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(BuildContext context, String key) {
    final value = controller.settingValue(key);
    final unit = controller.unitFor(key);
    final description = controller.descriptionFor(key);
    final isBool = key == 'enabled' || key.startsWith('publish_state');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.labelFor(key), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (description.isNotEmpty)
                  Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isBool)
            Switch(
              value: controller.settingBool(key),
              onChanged: (newValue) => controller.setDraftValue(key, newValue),
            )
          else
            SizedBox(
              width: 135,
              child: TextFormField(
                key: ValueKey('${key}_${controller.editorRevision.value}_${controller.draftValues[key] ?? value}'),
                initialValue: _fmt(value),
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: unit.isEmpty ? null : unit,
                ),
                onChanged: (text) {
                  final normalized = text.replaceAll(',', '.');
                  final parsed = double.tryParse(normalized);
                  if (parsed != null) {
                    controller.setDraftValue(key, parsed);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    String? subtitle,
    bool active = false,
    bool initiallyExpanded = false,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final color = active ? Colors.green.shade700 : theme.primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF7F7F7),
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: color),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        children: [
          Container(
            width: double.infinity,
            color: theme.cardColor,
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _metricTile(BuildContext context, String label, String value, {bool accent = false, bool warning = false}) {
    final theme = Theme.of(context);
    final color = warning
        ? Colors.orange.shade700
        : accent
            ? Colors.green.shade700
            : theme.textTheme.titleMedium?.color;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _satelliteTable(BuildContext context, List<Map<String, dynamic>> satellites, {required bool showUsed}) {
    if (satellites.isEmpty) {
      return Text('Keine Satellitenliste empfangen.', style: Theme.of(context).textTheme.bodyMedium);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 42,
        columns: [
          const DataColumn(label: Text('System')),
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('C/N0 (dB-Hz)'), numeric: true),
          const DataColumn(label: Text('Elevation (°)'), numeric: true),
          const DataColumn(label: Text('Azimuth (°)'), numeric: true),
          if (showUsed) const DataColumn(label: Text('Used')),
        ],
        rows: satellites.map((satellite) {
          return DataRow(
            cells: [
              DataCell(Text(_satText(satellite, const ['system', 'gnss', 'constellation']))),
              DataCell(Text(_satText(satellite, const ['id', 'svid', 'satellite_id', 'prn']))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['cn0', 'cno', 'c_n0'])))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['elevation', 'elev'])))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['azimuth', 'az'])))),
              if (showUsed) DataCell(_usedIcon(_satBool(satellite, const ['used', 'in_fix', 'fix_used']))),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _usedIcon(bool used) {
    if (used) {
      return Icon(Icons.check, color: Colors.green.shade700, size: 18);
    }
    return const Text('–');
  }

  Widget _freshnessHint(BuildContext context, dynamic updatedAt) {
    final age = _updatedAge(updatedAt);
    final isOld = age == null || age.inSeconds > 5;
    final color = isOld ? Colors.orange.shade700 : Colors.green.shade700;
    final message = isOld
        ? 'GPS-State veraltet oder noch nicht zeitlich bewertbar.'
        : 'Daten sind aktuell.';
    return Row(
      children: [
        Icon(isOld ? Icons.warning_amber_outlined : Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
      ],
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
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _satText(Map<String, dynamic> satellite, List<String> keys) {
    for (final key in keys) {
      final value = satellite[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '-';
  }

  double? _satDouble(Map<String, dynamic> satellite, List<String> keys) {
    for (final key in keys) {
      final value = satellite[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _satBool(Map<String, dynamic> satellite, List<String> keys) {
    for (final key in keys) {
      if (satellite.containsKey(key)) return _bool(satellite[key]);
    }
    return false;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.trim().isEmpty ? fallback : text;
  }

  String _fmt(dynamic value) {
    if (value == null) return '-';
    if (value is int) return value.toString();
    if (value is double) return value.toStringAsFixed(value.abs() >= 10 ? 1 : 2);
    if (value is num) return value.toDouble().toStringAsFixed(value.abs() >= 10 ? 1 : 2);
    final parsed = double.tryParse(value.toString());
    if (parsed != null) return parsed.toStringAsFixed(parsed.abs() >= 10 ? 1 : 2);
    return value.toString();
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }

  bool _qualityGood(dynamic quality) {
    final text = quality?.toString().toLowerCase() ?? '';
    return text.contains('good') || text.contains('fix') || text.contains('ok');
  }

  String _updatedAtText(dynamic value) {
    if (value == null) return '-';
    final age = _updatedAge(value);
    if (age != null) {
      if (age.inSeconds < 60) return 'vor ${age.inSeconds} s';
      if (age.inMinutes < 60) return 'vor ${age.inMinutes} min';
    }
    return value.toString();
  }

  Duration? _updatedAge(dynamic value) {
    if (value == null) return null;
    DateTime? parsed;
    if (value is num) {
      final raw = value.toDouble();
      parsed = DateTime.fromMillisecondsSinceEpoch(raw > 100000000000 ? raw.toInt() : (raw * 1000).toInt());
    } else {
      parsed = DateTime.tryParse(value.toString());
    }
    if (parsed == null) return null;
    final now = DateTime.now();
    if (parsed.isUtc) parsed = parsed.toLocal();
    final age = now.difference(parsed);
    if (age.isNegative) return Duration.zero;
    return age;
  }
}
