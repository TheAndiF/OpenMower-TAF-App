import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/status_transition_log_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class StatusTransitionLogScreen extends StatefulWidget {
  const StatusTransitionLogScreen({super.key});

  @override
  State<StatusTransitionLogScreen> createState() => _StatusTransitionLogScreenState();
}

class _StatusTransitionLogScreenState extends State<StatusTransitionLogScreen> {
  final StatusTransitionLogController controller = Get.find<StatusTransitionLogController>();
  bool _renewSent = false;
  bool _jsonExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestLog();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final entries = controller.entries;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummarySection(context),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Protokolldaten',
                  subtitle: 'Historie der per MQTT gemeldeten Statuswechsel',
                  child: _buildEntries(context, entries),
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

  Widget _buildSummarySection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final current = controller.currentEntry;
    final statusColor = controller.lastStatusOk.value == false
        ? Colors.red
        : controller.lastStatusOk.value == true
            ? Colors.green
            : color;
    final statusIcon = controller.lastStatusOk.value == false
        ? Icons.error_outline
        : controller.waitingForResponse.value
            ? Icons.hourglass_top
            : Icons.check_circle_outline;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                _summaryHeaderIcon(color: color, active: current != null),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Protokoll anzeigen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Statuswechsel abrufen und den aktuellen Übergangsverlauf auswerten',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _infoChip(
                      context,
                      icon: Icons.list_alt,
                      label: 'Geliefert',
                      value: '${controller.returnedEntries}',
                    ),
                    _infoChip(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Gesamt',
                      value: '${controller.totalEntries}',
                    ),
                    _infoChip(
                      context,
                      icon: Icons.filter_alt_outlined,
                      label: 'Limit',
                      value: '${controller.effectiveLimit}',
                    ),
                    if (current != null)
                      _infoChip(
                        context,
                        icon: controller.isCurrent(current) ? Icons.play_circle_outline : Icons.flag_outlined,
                        label: controller.isCurrent(current) ? 'Aktiv' : 'Letzter Status',
                        value: controller.stateText(current),
                      ),
                    const SizedBox(width: 10),
                    ..._buildRequestControlItems(context),
                  ],
                ),
                if (controller.lastStatus.value.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.45)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusText(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryHeaderIcon({required Color color, required bool active}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.65), width: 2),
      ),
      child: Icon(active ? Icons.history : Icons.receipt_long, color: color, size: 24),
    );
  }

  String _statusText() {
    final topic = controller.lastTopic.value.trim();
    final updated = controller.lastUpdated.value;
    final extras = <String>[];
    if (topic.isNotEmpty) {
      extras.add('Topic: $topic');
    }
    if (updated != null) {
      final date = '${updated.day.toString().padLeft(2, '0')}.${updated.month.toString().padLeft(2, '0')}.${updated.year.toString().padLeft(4, '0')}';
      final time = '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}:${updated.second.toString().padLeft(2, '0')}';
      extras.add('Aktualisiert: $date $time');
    }
    final suffix = extras.isEmpty ? '' : ' · ${extras.join(' · ')}';
    return '${controller.lastStatus.value}$suffix';
  }

  List<Widget> _buildRequestControlItems(BuildContext context) {
    final input = SizedBox(
      width: 220,
      child: TextField(
        controller: controller.limitController,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Anzahl Einträge',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onSubmitted: (_) => controller.requestLog(),
      ),
    );

    final hint = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '1 bis 300',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
      ),
    );

    final button = ElevatedButton.icon(
      onPressed: controller.waitingForResponse.value ? null : controller.requestLog,
      icon: const Icon(Icons.refresh, size: 20),
      label: const Text('Protokoll erneuern'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(210, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return [input, hint, button];
  }

  Widget _infoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final color = Theme.of(context).primaryColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
        color: color.withOpacity(0.06),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
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

  Widget _buildEntries(BuildContext context, List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          controller.waitingForResponse.value
              ? 'Das Protokoll wird angefordert.'
              : 'Noch keine Statuswechsel-Protokolle empfangen.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: entries
            .map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildEntryCard(context, entry),
                ))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, Map<String, dynamic> entry) {
    final color = Theme.of(context).primaryColor;
    final current = controller.isCurrent(entry);
    final emergency = controller.isEmergency(entry);
    final charging = controller.isCharging(entry);
    final borderColor = emergency
        ? Colors.red
        : current
            ? Colors.green
            : color.withOpacity(0.30);

    return Card(
      elevation: current ? 3 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor.withOpacity(0.75), width: current || emergency ? 1.8 : 1.0),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: current,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: borderColor.withOpacity(0.14),
            child: Icon(
              emergency
                  ? Icons.warning_amber_rounded
                  : current
                      ? Icons.play_arrow
                      : Icons.swap_horiz,
              color: borderColor,
            ),
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                controller.transitionText(entry),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (current) _badge(context, 'Aktiv', Colors.green),
              if (emergency) _badge(context, 'Emergency', Colors.red),
              if (charging) _badge(context, 'Lädt', Colors.blue),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _inlineMeta(context, Icons.schedule, controller.timestampText(entry)),
                _inlineMeta(context, Icons.timelapse, controller.durationText(entry)),
                _inlineMeta(context, Icons.battery_full, controller.percentageText(entry['battery_percentage'])),
                _inlineMeta(context, Icons.gps_fixed, controller.percentageText(entry['gps_percentage'])),
              ],
            ),
          ),
          children: [
            _buildDetails(context, entry),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.40)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _inlineMeta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildDetails(BuildContext context, Map<String, dynamic> entry) {
    final position = controller.positionFor(entry);
    final temperatures = controller.temperaturesFor(entry);
    final subState = controller.subStateText(entry);
    final previousSubState = controller.previousSubStateText(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _detailBlock(
              context,
              title: 'Statuswechsel',
              rows: [
                _detailRow('Vorher', controller.previousStateText(entry)),
                _detailRow('Neu', controller.stateText(entry)),
                if (previousSubState.isNotEmpty) _detailRow('Vorheriger Unterstatus', previousSubState),
                if (subState.isNotEmpty) _detailRow('Unterstatus', subState),
              ],
            ),
            _detailBlock(
              context,
              title: 'Kontext',
              rows: [
                _detailRow('Akkustand', controller.percentageText(entry['battery_percentage'])),
                _detailRow('GPS', controller.percentageText(entry['gps_percentage'])),
                _detailRow('Ladezustand', controller.boolText(entry['is_charging'], yes: 'lädt', no: 'lädt nicht')),
                _detailRow('Emergency', controller.boolText(entry['emergency'], yes: 'aktiv', no: 'inaktiv')),
              ],
            ),
            if (position.isNotEmpty)
              _detailBlock(
                context,
                title: 'Position',
                rows: [
                  _detailRow('X', controller.compactNumber(position['x'])),
                  _detailRow('Y', controller.compactNumber(position['y'])),
                  _detailRow('Heading', controller.compactNumber(position['heading'], decimals: 3)),
                  _detailRow('Positionsgenauigkeit', controller.compactNumber(position['pos_accuracy'])),
                  _detailRow('Heading gültig', controller.boolText(position['heading_valid'], yes: 'ja', no: 'nein')),
                ],
              ),
            if (temperatures.isNotEmpty)
              _detailBlock(
                context,
                title: 'Temperaturen',
                rows: temperatures.entries
                    .map((item) => _detailRow(_temperatureLabel(item.key), _temperatureValue(item.value)))
                    .toList(growable: false),
              ),
          ],
        ),
      ],
    );
  }

  String _temperatureLabel(String key) {
    switch (key) {
      case 'om_left_esc_temp':
        return 'ESC links';
      case 'om_right_esc_temp':
        return 'ESC rechts';
      case 'om_mow_esc_temp':
        return 'Mäh-ESC';
      case 'om_mow_motor_temp':
        return 'Mähmotor';
      default:
        return key;
    }
  }

  String _temperatureValue(dynamic value) {
    final numeric = double.tryParse(value?.toString() ?? '');
    if (numeric == null) {
      return '-';
    }
    return '${numeric.toStringAsFixed(1)} °C';
  }

  MapEntry<String, String> _detailRow(String label, String value) => MapEntry(label, value);

  Widget _detailBlock(
    BuildContext context, {
    required String title,
    required List<MapEntry<String, String>> rows,
  }) {
    final color = Theme.of(context).primaryColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 245, maxWidth: 360),
      decoration: BoxDecoration(
        color: color.withOpacity(0.045),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
        ],
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
                                Text('Protokoll-Rohdaten anzeigen und herunterladen', style: Theme.of(context).textTheme.bodyMedium),
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
                        _buildJsonStatusCard(context),
                        const SizedBox(height: 12),
                        _buildJsonEditorCard(context, isMobile: isMobile),
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

  Widget _jsonActionButtons(BuildContext context, {required bool isMobile}) {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: controller.hasData ? _downloadJsonFile : null,
        icon: const Icon(Icons.download),
        label: Text(isMobile ? 'Herunterladen' : 'Download'),
      ),
      ElevatedButton.icon(
        onPressed: controller.waitingForResponse.value ? null : controller.requestLog,
        icon: const Icon(Icons.refresh),
        label: const Text('Erneuern'),
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

  Widget _buildJsonStatusCard(BuildContext context) {
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
      headline = controller.lastStatus.value.isEmpty ? 'Protokoll vom Server empfangen.' : controller.lastStatus.value;
    } else if (ok == false) {
      accent = Colors.red.shade700;
      background = Colors.red.shade50;
      icon = Icons.error_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Aktion fehlgeschlagen.' : controller.lastStatus.value;
    } else if (controller.waitingForResponse.value) {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.06);
      icon = Icons.sync;
      headline = controller.lastStatus.value.isEmpty ? 'Warte auf Serverantwort ...' : controller.lastStatus.value;
    } else {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.04);
      icon = Icons.info_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Noch kein Protokoll empfangen.' : controller.lastStatus.value;
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

  Widget _buildJsonEditorCard(BuildContext context, {required bool isMobile}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _jsonEditorTitle(context),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copyJsonToClipboard(context),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Kopieren'),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _jsonEditorTitle(context)),
                    OutlinedButton.icon(
                      onPressed: () => _copyJsonToClipboard(context),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Kopieren'),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.rawJsonController,
            readOnly: true,
            minLines: 10,
            maxLines: 22,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'statustransition_log.json',
              alignLabelWithHint: true,
              helperText: 'Rohdaten aus statustransition_log/json. Der Inhalt ist in dieser Ansicht nur lesbar.',
              helperStyle: TextStyle(color: color.withOpacity(0.9)),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _jsonEditorTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JSON-Inhalt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          'Empfangene Protokolldaten. Download speichert den aktuellen lokalen Snapshot.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _copyJsonToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: controller.rawJsonController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON wurde in die Zwischenablage kopiert.')),
    );
  }

  void _downloadJsonFile() {
    final jsonText = controller.exportJsonString();
    final bytes = utf8.encode(jsonText);
    final blob = html.Blob(<Object>[bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final now = DateTime.now();
    final filename = 'openmower_statustransition_log_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

}
