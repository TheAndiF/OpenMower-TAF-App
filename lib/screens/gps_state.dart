import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_mower_app/controllers/gps_state_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class GpsStateScreen extends GetView<GpsStateController> {
  const GpsStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return n.Stack(
      [
        Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(12, 72, 12, 12),
            children: [
              _buildOverviewCard(context),
              const SizedBox(height: 12),
              _buildState1Card(context),
              const SizedBox(height: 12),
              _buildState2Card(context),
              const SizedBox(height: 12),
              _buildState3Card(context),
              const SizedBox(height: 12),
              _buildState4Card(context),
              const SizedBox(height: 12),
              _buildSettingsCard(context),
              const SizedBox(height: 12),
              _buildRawCard(context),
            ],
          ),
        ),
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
          final metricWidth = (constraints.maxWidth * 0.52).clamp(180.0, 620.0).toDouble();
          final showDescription = constraints.maxWidth >= 760;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _headerIcon(context, Icons.gps_fixed, active: controller.hasState1 || controller.hasState2),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'GPS-State',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (showDescription) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Satellitenlage aus gps_state/state1 bis gps_state/state4.',
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
                        _overviewMetric(context, label: 'Sichtbar', value: controller.visible.toString(), icon: Icons.settings_input_antenna),
                        const SizedBox(width: 6),
                        _overviewMetric(context, label: 'Verwendet', value: controller.used.toString(), icon: Icons.gps_fixed),
                        const SizedBox(width: 6),
                        _overviewMetric(context, label: 'Ø C/N0', value: _fmt(controller.avgCn0), icon: Icons.signal_cellular_alt),
                        const SizedBox(width: 6),
                        _overviewMetric(context, label: 'State4', value: controller.hasState4 ? 'Aktiv' : 'Aus', icon: Icons.list_alt),
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

  Widget _buildState1Card(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Übersicht (State1)',
      subtitle: 'Kompakter GPS-Zustand',
      icon: Icons.gps_fixed,
      initiallyExpanded: true,
      children: [
        _metricGrid(
          context,
          [
            _Metric('Verfügbar', controller.available ? 'Ja' : 'Nein', controller.available ? Icons.check_circle_outline : Icons.highlight_off_outlined),
            _Metric('Qualität', controller.quality.isEmpty ? '-' : controller.quality, Icons.verified_outlined),
            _Metric('Sichtbar', controller.visible.toString(), Icons.settings_input_antenna),
            _Metric('Verwendet', controller.used.toString(), Icons.gps_fixed),
            _Metric('Ø C/N0', '${_fmt(controller.avgCn0)} dB-Hz', Icons.signal_cellular_alt),
            _Metric('Aktualisiert', _updatedText(), Icons.schedule),
          ],
        ),
        const SizedBox(height: 10),
        _statusLine(
          context,
          controller.hasState1
              ? (controller.dataLooksStale ? 'GPS-State-Daten sind älter als 5 Sekunden.' : 'GPS-State-Daten sind aktuell.')
              : 'Noch kein gps_state/state1 empfangen.',
          controller.hasState1 && !controller.dataLooksStale,
        ),
      ],
    );
  }

  Widget _buildState2Card(BuildContext context) {
    final systems = controller.systems;
    return _sectionCard(
      context,
      title: 'Signalqualität (State2)',
      subtitle: 'Min/Max C/N0, schwache und gute Satelliten',
      icon: Icons.signal_cellular_alt,
      initiallyExpanded: true,
      children: [
        _metricGrid(
          context,
          [
            _Metric('Min C/N0', '${_fmt(controller.minCn0)} dB-Hz', Icons.trending_down),
            _Metric('Max C/N0', '${_fmt(controller.maxCn0)} dB-Hz', Icons.trending_up),
            _Metric('Schwach', controller.weakCount.toString(), Icons.warning_amber_outlined),
            _Metric('Gut', controller.goodCount.toString(), Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: systems.isEmpty
                ? [
                    Chip(
                      avatar: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Keine Systemverteilung empfangen'),
                      visualDensity: VisualDensity.compact,
                    )
                  ]
                : systems.entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildState3Card(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Verwendete Satelliten (State3)',
      subtitle: 'Nur Satelliten, die für den Fix verwendet werden',
      icon: Icons.settings_input_antenna,
      initiallyExpanded: true,
      children: [
        _satelliteList(context, controller.usedSatellites, emptyText: 'Noch kein gps_state/state3 mit verwendeten Satelliten empfangen.'),
      ],
    );
  }

  Widget _buildState4Card(BuildContext context) {
    final enabled = controller.publishState4Enabled || controller.hasState4;
    return _sectionCard(
      context,
      title: 'Alle Satelliten (State4)',
      subtitle: 'Vollständige Satellitenliste für Diagnose',
      icon: Icons.list_alt,
      initiallyExpanded: false,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: enabled ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          enabled ? 'Aktiv' : 'Deaktiviert',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: enabled ? Colors.green.shade800 : Colors.orange.shade900,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      children: [
        _statusLine(
          context,
          'State4 erzeugt mehr MQTT-Daten und sollte nur zur Diagnose aktiviert werden.',
          false,
          icon: Icons.warning_amber_outlined,
        ),
        const SizedBox(height: 10),
        _satelliteList(context, controller.allSatellites, emptyText: 'State4 ist leer oder nicht aktiviert.'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(enabled ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                label: Text(enabled ? 'State4 deaktivieren' : 'State4 temporär aktivieren'),
                onPressed: () {
                  controller.updateDraft('publish_state4', !enabled);
                  controller.publishSession();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Einstellungen',
      subtitle: 'Session- und persistente GPS-State-Werte',
      icon: Icons.tune,
      initiallyExpanded: false,
      children: [
        _switchSetting(context, 'enabled', 'Enabled'),
        _numberSetting(context, 'publish_rate_hz', 'Publish-Rate (Hz)', min: 0.1, max: 5.0, step: 0.1),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 720;
            final children = [
              _switchSetting(context, 'publish_state1', 'Publish State1'),
              _switchSetting(context, 'publish_state2', 'Publish State2'),
              _switchSetting(context, 'publish_state3', 'Publish State3'),
              _switchSetting(context, 'publish_state4', 'Publish State4'),
            ];
            if (!twoColumns) return Column(children: children);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: children.take(2).toList())),
                const SizedBox(width: 12),
                Expanded(child: Column(children: children.skip(2).toList())),
              ],
            );
          },
        ),
        _numberSetting(context, 'weak_cn0_threshold', 'Weak C/N0 Threshold (dB-Hz)', min: 0, max: 60, step: 1),
        _numberSetting(context, 'good_cn0_threshold', 'Good C/N0 Threshold (dB-Hz)', min: 0, max: 60, step: 1),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final buttons = [
              ElevatedButton.icon(
                onPressed: controller.dirtyKeys.isEmpty ? null : controller.publishSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Jetzt anwenden (Session)'),
              ),
              ElevatedButton.icon(
                onPressed: controller.dirtyKeys.isEmpty ? null : controller.publishPersistent,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Dauerhaft speichern'),
              ),
              OutlinedButton.icon(
                onPressed: controller.requestRenew,
                icon: const Icon(Icons.refresh),
                label: const Text('Status neu laden'),
              ),
            ];
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: buttons.map((button) => Padding(padding: const EdgeInsets.only(bottom: 8), child: button)).toList(),
              );
            }
            return Row(
              children: buttons
                  .map((button) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: button)))
                  .toList(growable: false),
            );
          },
        ),
        if (controller.lastStatus.isNotEmpty) ...[
          const SizedBox(height: 8),
          _statusLine(context, controller.lastStatus.value, !controller.lastStatus.value.toLowerCase().contains('keine')),
        ],
      ],
    );
  }

  Widget _buildRawCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Raw JSON / Debug',
      subtitle: 'Aktuelle Rohdaten der GPS-State-Topics',
      icon: Icons.code,
      initiallyExpanded: false,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: SelectableText(
            controller.rawJson,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool initiallyExpanded,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    const textColor = Colors.black54;
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
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        iconColor: textColor,
        collapsedIconColor: textColor,
        textColor: textColor,
        collapsedTextColor: textColor,
        backgroundColor: const Color(0xFFF3F3F3),
        collapsedBackgroundColor: const Color(0xFFF3F3F3),
        leading: Icon(icon, color: textColor, size: 22),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            color: theme.cardColor,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(BuildContext context, List<_Metric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            childAspectRatio: 2.15,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) => _metricTile(context, metrics[index]),
        );
      },
    );
  }

  Widget _metricTile(BuildContext context, _Metric metric) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(metric.icon, size: 18, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 2),
                Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _satelliteList(BuildContext context, List<Map<String, dynamic>> satellites, {required String emptyText}) {
    final theme = Theme.of(context);
    if (satellites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(emptyText, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: satellites.map((satellite) => _satelliteCompactTile(context, satellite)).toList(growable: false),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 38,
            columns: const [
              DataColumn(label: Text('System')),
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('C/N0')),
              DataColumn(label: Text('Elevation')),
              DataColumn(label: Text('Azimuth')),
              DataColumn(label: Text('Used')),
            ],
            rows: satellites
                .map(
                  (satellite) => DataRow(
                    cells: [
                      DataCell(Text(_satText(satellite, ['system', 'gnss', 'constellation']))),
                      DataCell(Text(_satText(satellite, ['id', 'sv_id', 'svid', 'prn']))),
                      DataCell(Text(_fmt(_satDouble(satellite, ['cn0', 'cno', 'c_n0']))),
                      DataCell(Text(_fmt(_satDouble(satellite, ['elevation', 'elev']))),
                      DataCell(Text(_fmt(_satDouble(satellite, ['azimuth', 'az']))),
                      DataCell(Text(_satBool(satellite, ['used', 'used_in_fix']) ? 'Ja' : 'Nein')),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _satelliteCompactTile(BuildContext context, Map<String, dynamic> satellite) {
    final theme = Theme.of(context);
    final system = _satText(satellite, ['system', 'gnss', 'constellation']);
    final id = _satText(satellite, ['id', 'sv_id', 'svid', 'prn']);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$system $id', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'C/N0: ${_fmt(_satDouble(satellite, ['cn0', 'cno', 'c_n0']))} dB-Hz · Elevation: ${_fmt(_satDouble(satellite, ['elevation', 'elev']))}° · Azimuth: ${_fmt(_satDouble(satellite, ['azimuth', 'az']))}°',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _switchSetting(BuildContext context, String key, String label) {
    final value = _bool(controller.settingDraftValue(key, fallback: key == 'publish_state4' ? false : true));
    final dirty = controller.dirtyKeys.contains(key);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)))),
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: dirty ? const Text('geändert, noch nicht gespeichert') : null,
        value: value,
        onChanged: (next) => controller.updateDraft(key, next),
      ),
    );
  }

  Widget _numberSetting(BuildContext context, String key, String label, {required double min, required double max, required double step}) {
    final raw = controller.settingDraftValue(key, fallback: key == 'publish_rate_hz' ? 1.0 : (key.startsWith('weak') ? 20.0 : 30.0));
    final current = _double(raw).clamp(min, max).toDouble();
    final dirty = controller.dirtyKeys.contains(key);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (dirty) Text('geändert, noch nicht gespeichert', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).primaryColor)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Verringern',
            icon: const Icon(Icons.remove),
            onPressed: () => controller.updateDraft(key, (current - step).clamp(min, max)),
          ),
          SizedBox(
            width: 64,
            child: Text(_fmt(current), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Erhöhen',
            icon: const Icon(Icons.add),
            onPressed: () => controller.updateDraft(key, (current + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(BuildContext context, String text, bool ok, {IconData? icon}) {
    final color = ok ? Colors.green.shade700 : Colors.orange.shade800;
    return Row(
      children: [
        Icon(icon ?? (ok ? Icons.info_outline : Icons.warning_amber_outlined), size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = active ? Theme.of(context).primaryColor : Theme.of(context).hintColor;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _overviewMetric(BuildContext context, {required String label, required String value, required IconData icon}) {
    return Container(
      width: 122,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(7)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 7),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  String _updatedText() {
    final age = controller.dataAge;
    if (age == null) return '-';
    if (age.inSeconds < 60) return 'vor ${age.inSeconds} s';
    if (age.inMinutes < 60) return 'vor ${age.inMinutes} min';
    return 'vor ${age.inHours} h';
  }

  String _satText(Map<String, dynamic> satellite, List<String> keys) {
    for (final key in keys) {
      final value = satellite[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return '-';
  }

  double _satDouble(Map<String, dynamic> satellite, List<String> keys) {
    for (final key in keys) {
      final value = satellite[key];
      final parsed = _double(value);
      if (value != null || parsed != 0) return parsed;
    }
    return 0.0;
  }

  bool _satBool(Map<String, dynamic> satellite, List<String> keys) {
    for (final key in keys) {
      if (satellite.containsKey(key)) return _bool(satellite[key]);
    }
    return false;
  }

  String _fmt(num value) {
    if (value.isNaN || value.isInfinite) return '-';
    if ((value - value.round()).abs() < 0.05) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on' || normalized == 'enabled';
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}
