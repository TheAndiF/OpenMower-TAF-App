import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/gps_state_controller.dart';
import 'package:open_mower_app/services/platform_text_file.dart';
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
  bool _snapshotDownloadInProgress = false;

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
                  _buildState0Section(context),
                  const SizedBox(height: 10),
                  _buildState1Section(context),
                  const SizedBox(height: 10),
                  _buildState2Section(context),
                  const SizedBox(height: 10),
                  _buildState3Section(context),
                  const SizedBox(height: 10),
                  _buildState4Section(context),
                  const SizedBox(height: 10),
                  _buildRestartSection(context),
                  const SizedBox(height: 10),
                  _buildSettingsSection(context),
                  const SizedBox(height: 10),
                  _buildRawJsonSection(context),
                  const SizedBox(height: 10),
                  Text(
                    'Hinweis: State1 ist die kompakte Bedieneranzeige. State0 und State4 sind Experten-/Debugdaten und sollten nur bei Bedarf aktiv sein.',
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
        : controller.hasState || controller.hasRestartStatus
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
                        'Auswertung von gps_state.v3: getrennte Definitionen und Statusdaten, zentrale Aktualisierung und Diagnoseexport.',
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
            final snapshot = FilledButton.icon(
              onPressed: _snapshotDownloadInProgress ? null : () => _downloadGpsSnapshot(context),
              icon: _snapshotDownloadInProgress
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
              label: const Text('JSON-Snapshot'),
            );
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [refresh, snapshot],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                refresh,
                const SizedBox(width: 8),
                snapshot,
              ],
            );
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
      title: 'Bedienerstatus (State1)',
      subtitle: state.isEmpty ? 'Noch keine kompakten Bedienerdaten empfangen' : 'Fahrfreigabe, Grund, RTK, Genauigkeit und Pose-Alter',
      active: _bool(state['gps_drive_ready']),
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDriveReadinessCard(context, state),
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
      title: 'Technische GNSS-/Pose-Zusammenfassung (State2)',
      subtitle: state.isEmpty ? 'Noch keine technischen Qualitätsdaten empfangen' : 'Aggregierte GNSS-Werte, Systemverteilung und technische Diagnosen',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricTile(context, 'Verfügbar', _boolText(state['available']), accent: _boolNullable(state['available']) == true, warning: _boolNullable(state['available']) == false),
              _metricTile(context, 'Quality Class', _text(state['quality_class'], fallback: '-'), accent: _qualityGood(state['quality_class'])),
              _metricTile(context, 'Sichtbar', _fmt(state['visible_count'] ?? state['visible'])),
              _metricTile(context, 'Verwendet', _fmt(state['used_count'] ?? state['used']), accent: _int(state['used_count'] ?? state['used']) > 0),
              _metricTile(context, 'Ø C/N0', '${_fmt(state['avg_cn0'])} dB-Hz', accent: _double(state['avg_cn0']) >= 30),
              _metricTile(context, 'Min C/N0', '${_fmt(state['min_cn0'])} dB-Hz'),
              _metricTile(context, 'Max C/N0', '${_fmt(state['max_cn0'])} dB-Hz'),
              _metricTile(context, 'Schwach', _fmt(state['weak_count']), warning: _int(state['weak_count']) > 0),
              _metricTile(context, 'Gut', _fmt(state['good_count']), accent: _int(state['good_count']) > 0),
              _metricTile(context, 'RTK', _text(state['rtk_state'], fallback: '-'), accent: _text(state['rtk_state']).toLowerCase() == 'fixed'),
              _metricTile(context, 'LL GPS Genauigkeit', _metersText(state['ll_gps_accuracy_m'] ?? state['ll_gps_position_accuracy_m'])),
              _metricTile(context, 'XB Pose Genauigkeit', _metersText(state['xb_pose_accuracy_m'])),
              _metricTile(context, 'Orientierung', _boolText(state['orientation_valid']), accent: _boolNullable(state['orientation_valid']) == true, warning: _boolNullable(state['orientation_valid']) == false),
              _metricTile(context, 'Pose aktuell', _boolText(state['recent_absolute_pose']), accent: _boolNullable(state['recent_absolute_pose']) == true, warning: _boolNullable(state['recent_absolute_pose']) == false),
              _metricTile(context, 'GPS Timeout', _boolText(state['gps_timeout']), accent: _boolNullable(state['gps_timeout']) == false, warning: _boolNullable(state['gps_timeout']) == true),
              _metricTile(
                context,
                'Quelldaten-Alter',
                _millisecondsText(state['age_ms']),
                warning: _boolNullable(state['stale']) == true,
                accent: _boolNullable(state['stale']) == false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Systemverteilung', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (systems is Map && systems.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: systems.entries.map<Widget>((entry) => Chip(label: Text(_systemChipText(entry.key.toString(), entry.value)))).toList(growable: false),
            )
          else
            Text('Keine Systemverteilung empfangen.', style: Theme.of(context).textTheme.bodySmall),
          _buildDiagnosticSummary(context, state),
          _buildDriveDiagnosticsSection(context, state),
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
    final state = controller.state3;
    final satellites = controller.satellitesForState(3);
    final usedCount = state['used_count'] ?? satellites.length;
    return _sectionCard(
      context,
      icon: Icons.hub_outlined,
      title: 'Aktiv verwendete Satelliten (State3)',
      subtitle: satellites.isEmpty ? 'Noch keine verwendeten Satelliten empfangen' : 'Verwendet laut Payload: ${_fmt(usedCount)}',
      initiallyExpanded: true,
      child: _satelliteTable(context, satellites, showUsed: false),
    );
  }

  Widget _buildState4Section(BuildContext context) {
    final state = controller.state4;
    final satellites = controller.satellitesForState(4);
    final active = controller.state4Active;
    return _sectionCard(
      context,
      icon: Icons.satellite_outlined,
      title: 'Expertenliste aller sichtbaren Satelliten (State4)',
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
              color: active ? Colors.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (active ? Colors.green : Colors.orange).withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(active ? Icons.info_outline : Icons.warning_amber_outlined, color: active ? Colors.green.shade700 : Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(active
                      ? 'State4 ist aktiv. Es werden alle sichtbaren Satelliten inklusive used=true/false übertragen.'
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
          if (state.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricTile(context, 'Sichtbar', _fmt(state['visible_count'] ?? satellites.length)),
                _metricTile(context, 'Verwendet', _fmt(state['used_count']), accent: _int(state['used_count']) > 0),
                _metricTile(context, 'Ø C/N0', '${_fmt(state['avg_cn0'])} dB-Hz'),
                _metricTile(context, 'Min C/N0', '${_fmt(state['min_cn0'])} dB-Hz'),
                _metricTile(context, 'Max C/N0', '${_fmt(state['max_cn0'])} dB-Hz'),
                _metricTile(context, 'Sensor-Zeit', _text(state['sensor_stamp'], fallback: '-')),
              ],
            ),
          ],
          if (satellites.isNotEmpty) ...[
            const SizedBox(height: 12),
            _satelliteTable(context, satellites, showUsed: true),
          ],
        ],
      ),
    );
  }

  Widget _buildState0Section(BuildContext context) {
    final definition = controller.state0Definition;
    final status = controller.state0Status;
    final rows = _state0DecisionRows(definition, status);
    final summarySource = status;
    final definitionVersion = _text(
      status['definition_version'] ?? definition['definition_version'],
      fallback: '-',
    );
    final waiting = controller.state0WaitingForUpdate.value;
    final snapshotCurrent = controller.state0SnapshotIsCurrent;

    return _sectionCard(
      context,
      icon: Icons.fact_check_outlined,
      title: 'Fahrfähigkeits-Entscheidungskette (State0)',
      subtitle: rows.isEmpty
          ? 'Noch keine State0-Diagnose empfangen'
          : 'Definition v$definitionVersion, ${rows.length} Entscheidungsknoten',
      active: controller.state0Active,
      initiallyExpanded: false,
      onExpansionChanged: (expanded) {
        if (expanded && !controller.state0WaitingForUpdate.value) {
          controller.requestState0Update(automatic: true);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _state0UpdateControls(context, waiting: waiting, snapshotCurrent: snapshotCurrent),
          const SizedBox(height: 10),
          if (waiting || !snapshotCurrent)
            _state0RefreshBanner(context, waiting: waiting)
          else if (summarySource.isNotEmpty)
            _state0ReadinessBanner(context, summarySource, rows),
          if (definition.isEmpty && status.isNotEmpty) ...[
            const SizedBox(height: 10),
            _messageBox(
              context,
              'Hinweis',
              'Live-Status wurde empfangen, aber die statische Definition fehlt noch. Topic gps_state/state0/definition prüfen.',
            ),
          ],
          if (definition.isNotEmpty && status.isEmpty) ...[
            const SizedBox(height: 10),
            _messageBox(
              context,
              'Hinweis',
              'Definition wurde empfangen, aber der Live-Status fehlt noch. Mit „State0 aktualisieren“ einen neuen Stand anfordern.',
            ),
          ],
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text('Keine auswertbare Entscheidungskette empfangen.', style: Theme.of(context).textTheme.bodyMedium)
          else ...[
            _state0DecisionHeader(context),
            const SizedBox(height: 4),
            _state0DecisionList(
              context,
              rows,
              snapshotCurrent: snapshotCurrent,
              waiting: waiting,
            ),
          ],
        ],
      ),
    );
  }

  Widget _state0UpdateControls(
    BuildContext context, {
    required bool waiting,
    required bool snapshotCurrent,
  }) {
    final theme = Theme.of(context);
    final received = controller.state0StatusReceivedAt.value;
    final statusText = waiting
        ? 'Aktueller Snapshot wird angefordert.'
        : snapshotCurrent && received != null
            ? 'Aktueller Snapshot empfangen: ${_clockText(received)}'
            : controller.state0UpdateMessage.value.isNotEmpty
                ? controller.state0UpdateMessage.value
                : 'Beim Öffnen wird automatisch ein aktueller State0-Snapshot angefordert.';
    final color = waiting
        ? Colors.orange.shade700
        : snapshotCurrent
            ? Colors.green.shade700
            : theme.hintColor;

    return Row(
      children: [
        Icon(
          waiting ? Icons.sync : snapshotCurrent ? Icons.check_circle_outline : Icons.schedule,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: waiting ? null : () => controller.requestState0Update(),
          icon: waiting
              ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh, size: 18),
          label: const Text('State0 aktualisieren'),
        ),
      ],
    );
  }

  Widget _state0RefreshBanner(BuildContext context, {required bool waiting}) {
    final theme = Theme.of(context);
    final color = Colors.orange.shade700;
    final message = waiting
        ? 'Die angezeigten Prüfpunkte werden bis zum Eingang einer neuen State0-Statusmeldung nicht als aktuell gewertet.'
        : controller.state0UpdateMessage.value.isNotEmpty
            ? controller.state0UpdateMessage.value
            : 'Für diese Ansicht liegt noch kein seit dem Öffnen angeforderter State0-Snapshot vor.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Icon(waiting ? Icons.sync : Icons.warning_amber_outlined, color: color, size: 21),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: color))),
        ],
      ),
    );
  }

  Widget _state0ReadinessBanner(BuildContext context, Map<String, dynamic> status, List<_DecisionRow> rows) {
    final theme = Theme.of(context);
    final ready = _boolNullable(status['drive_ready'] ?? status['gps_drive_ready']);
    final severity = _int(status['severity']);
    final blockingStage = status['blocking_stage'];
    final blockingKey = _text(status['blocking_key']);
    final blockingTitle = _text(status['blocking_title']);
    final summary = _text(status['summary'], fallback: ready == true ? 'Alle Bedingungen erfüllt' : 'Keine Zusammenfassung empfangen');
    final blockingRow = _state0BlockingRow(rows, blockingStage: blockingStage, blockingKey: blockingKey);
    final rowStates = rows.map(_decisionConditionState).toList(growable: false);
    final hasUnknown = rowStates.any((item) => item == _DecisionConditionState.unknown);
    final hasFailed = rowStates.any((item) => item == _DecisionConditionState.failed);
    final readyIsConsistent = ready == true && !hasUnknown && !hasFailed;
    final reportedReadyButIncomplete = ready == true && !readyIsConsistent;
    final state = readyIsConsistent && severity == 0 && blockingStage == null
        ? _DecisionConditionState.passed
        : reportedReadyButIncomplete
            ? _DecisionConditionState.warning
            : ready == false || severity > 0 || blockingStage != null
                ? _DecisionConditionState.failed
                : _DecisionConditionState.warning;
    final color = _decisionStateColor(state);
    final title = reportedReadyButIncomplete
        ? 'Fahrfreigabe gemeldet, Prüfkette aber nicht vollständig aktuell'
        : state == _DecisionConditionState.passed
            ? 'Fahrfreigabe erteilt'
            : blockingRow != null
                ? 'Fahrfreigabe hängt bei Stufe ${blockingRow.number}: ${blockingRow.label}'
                : blockingTitle.isNotEmpty
                    ? 'Fahrfreigabe hängt bei: $blockingTitle'
                    : 'Fahrfreigabe noch nicht eindeutig';
    final details = <String>[];
    if (summary.isNotEmpty) details.add(summary);
    if (reportedReadyButIncomplete) details.add('Ein grüner Gesamtstatus wird erst angezeigt, wenn die Einzelprüfungen vollständig vorliegen.');
    if (blockingKey.isNotEmpty) details.add('Blockierender Schlüssel: $blockingKey');
    final llAge = _millisecondsText(status['ll_gps_age_ms']);
    final xbAge = _millisecondsText(status['xb_pose_age_ms']);
    if (llAge != '-') details.add('LL GPS Alter: $llAge');
    if (xbAge != '-') details.add('XB Pose Alter: $xbAge');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_decisionStateIcon(state), color: color, size: 23),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(details.join(' · '), style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _DecisionRow? _state0BlockingRow(List<_DecisionRow> rows, {dynamic blockingStage, String blockingKey = ''}) {
    final stageText = _text(blockingStage);
    for (final row in rows) {
      if (row.isBlocking) return row;
      if (stageText.isNotEmpty && row.number == stageText) return row;
      if (blockingKey.isNotEmpty && (row.key == blockingKey || row.source == blockingKey)) return row;
    }
    return null;
  }

  Widget _buildRestartSection(BuildContext context) {
    final status = controller.restartStatusPayload;
    final validation = controller.restartValidationPayload;
    final waiting = controller.waitingForResponse.value;
    return _sectionCard(
      context,
      icon: Icons.restart_alt,
      title: 'F9P-Neustart unter gps_state',
      subtitle: status.isEmpty ? 'MQTT-Befehl an gps_state/restart/set/json' : 'Letzter Status: ${_text(status['status'], fallback: '-')}',
      initiallyExpanded: status.isNotEmpty || validation.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Der Neustart wird als JSON-Befehl gesendet. Standard ist reset_mode=controlled_software; ein späterer GNSS-Fix wird nicht durch ein ACK bestätigt.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('restart-reset-${controller.restartResetMode.value}'),
                  initialValue: controller.restartResetMode.value,
                  decoration: const InputDecoration(
                    labelText: 'Reset-Mode',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: GpsStateController.restartResetModes
                      .map((mode) => DropdownMenuItem<String>(value: mode, child: Text(_restartResetModeLabel(mode))))
                      .toList(growable: false),
                  onChanged: waiting ? null : (value) {
                    if (value != null) controller.restartResetMode.value = value;
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: waiting ? null : () => controller.restartF9p('hot_start', resetMode: controller.restartResetMode.value),
                icon: const Icon(Icons.flash_on),
                label: const Text('Hot Start'),
              ),
              ElevatedButton.icon(
                onPressed: waiting ? null : () => controller.restartF9p('warm_start', resetMode: controller.restartResetMode.value),
                icon: const Icon(Icons.thermostat),
                label: const Text('Warm Start'),
              ),
              OutlinedButton.icon(
                onPressed: waiting ? null : () => controller.restartF9p('cold_start', resetMode: controller.restartResetMode.value),
                icon: const Icon(Icons.ac_unit),
                label: const Text('Cold Start'),
              ),
              OutlinedButton.icon(
                onPressed: waiting ? null : controller.requestRestartStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart-Status neu laden'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (status.isNotEmpty) ...[
            Text('Letzter Neustartstatus', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _compactStatusChip(context, 'Status', _text(status['status'], fallback: '-'), accent: _restartStatusOk(status), warning: _restartStatusRejected(status)),
                _compactStatusChip(context, 'Akzeptiert', _boolText(status['accepted']), accent: _boolNullable(status['accepted']) == true, warning: _boolNullable(status['accepted']) == false),
                _compactStatusChip(context, 'Mode', _text(status['mode'], fallback: '-')),
                _compactStatusChip(context, 'Reset', _text(status['reset_mode'], fallback: '-')),
                _compactStatusChip(context, 'navBbrMask', _fmt(status['nav_bbr_mask'])),
                _compactStatusChip(context, 'resetMode', _fmt(status['reset_mode_value'])),
                _compactStatusChip(context, 'Quelle', _text(status['source'], fallback: '-')),
              ],
            ),
            if (_text(status['reason']).isNotEmpty) ...[
              const SizedBox(height: 8),
              _messageBox(context, 'Grund', _text(status['reason'])),
            ],
          ],
          if (validation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Letzte Validierung', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _compactStatusChip(context, 'Gültig', _boolText(validation['valid'] ?? validation['accepted']), accent: _boolNullable(validation['valid'] ?? validation['accepted']) == true, warning: _boolNullable(validation['valid'] ?? validation['accepted']) == false),
                _compactStatusChip(context, 'Mode', _text(validation['mode'], fallback: '-')),
                _compactStatusChip(context, 'Reset', _text(validation['reset_mode'], fallback: '-')),
              ],
            ),
            if (_text(validation['reason'] ?? validation['error'] ?? validation['message']).isNotEmpty) ...[
              const SizedBox(height: 8),
              _messageBox(context, 'Validierungsantwort', _text(validation['reason'] ?? validation['error'] ?? validation['message'])),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDriveReadinessCard(BuildContext context, Map<String, dynamic> state) {
    final theme = Theme.of(context);
    final hasDriveFields = _containsAny(state, const [
      'gps_drive_ready',
      'gps_drive_state',
      'gps_drive_label',
      'gps_drive_reason',
      'gps_drive_block_reason',
    ]);
    final ready = _boolNullable(state['gps_drive_ready']);
    final effectiveReady = ready ?? false;
    final label = _text(
      state['gps_drive_label'],
      fallback: hasDriveFields
          ? (effectiveReady ? 'GPS reicht zum Fahren aus' : 'GPS reicht nicht zum Fahren aus')
          : 'Fahrfreigabe noch nicht vom Backend geliefert',
    );
    final reason = _text(
      state['gps_drive_reason'],
      fallback: hasDriveFields
          ? 'Kein Detailgrund angegeben.'
          : 'Erwartet werden die State1-Felder gps_drive_ready, gps_drive_label und gps_drive_reason.',
    );
    final blockReason = _text(state['gps_drive_block_reason']);
    final color = hasDriveFields
        ? (effectiveReady ? Colors.green.shade700 : Colors.orange.shade700)
        : theme.hintColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(effectiveReady ? Icons.check_circle_outline : Icons.block_outlined, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 3),
                    Text(reason, style: theme.textTheme.bodyMedium),
                    if (blockReason.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text('Blockiergrund: $blockReason', style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactStatusChip(context, 'Status', _text(state['gps_drive_state'], fallback: hasDriveFields ? (effectiveReady ? 'ready' : 'blocked') : '-'), accent: effectiveReady),
              _compactStatusChip(context, 'RTK', _text(state['rtk_state'], fallback: '-'), accent: _text(state['rtk_state']).toLowerCase() == 'fixed'),
              _compactStatusChip(context, 'Genauigkeit', _metersText(state['position_accuracy_m']), accent: _accuracyOk(state['position_accuracy_m'], state['max_position_accuracy_m'])),
              _compactStatusChip(context, 'Grenzwert', _metersText(state['max_position_accuracy_m'])),
              _compactStatusChip(context, 'Pose-Alter', _millisecondsText(state['pose_age_ms'])),
              _compactStatusChip(context, 'Quality', _text(state['quality_class'], fallback: '-'), accent: _qualityGood(state['quality_class'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticSummary(BuildContext context, Map<String, dynamic> state) {
    final raw = state['diagnostic_summary'];
    if (raw == null || raw.toString().trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _messageBox(context, 'Diagnose-Zusammenfassung', raw is Map || raw is Iterable ? const JsonEncoder.withIndent('  ').convert(raw) : raw.toString()),
      ],
    );
  }

  Widget _buildDriveDiagnosticsSection(BuildContext context, Map<String, dynamic> state) {
    final rawDiagnostics = state['drive_diagnostics'];
    if (rawDiagnostics is! Map || rawDiagnostics.isEmpty) {
      return const SizedBox.shrink();
    }
    final diagnostics = Map<String, dynamic>.from(rawDiagnostics);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('Technische Drive-Diagnose', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _compactStatusChip(context, 'Entscheidung', _text(diagnostics['decision_source'], fallback: '-')),
            _compactStatusChip(context, 'RTK-Quelle', _text(diagnostics['rtk_source'], fallback: '-')),
            _compactStatusChip(context, 'LL RTK fixed', _boolText(diagnostics['ll_gps_rtk_fixed']), accent: _boolNullable(diagnostics['ll_gps_rtk_fixed']) == true, warning: _boolNullable(diagnostics['ll_gps_rtk_fixed']) == false),
            _compactStatusChip(context, 'LL Genauigkeit', _metersText(diagnostics['ll_gps_position_accuracy_m'] ?? diagnostics['ll_gps_accuracy_m'])),
            _compactStatusChip(context, 'XB Genauigkeit OK', _boolText(diagnostics['xb_pose_accuracy_ok_for_mower_logic']), accent: _boolNullable(diagnostics['xb_pose_accuracy_ok_for_mower_logic']) == true, warning: _boolNullable(diagnostics['xb_pose_accuracy_ok_for_mower_logic']) == false),
            _compactStatusChip(context, 'XB Pose-Alter', _millisecondsText(diagnostics['xb_pose_age_ms'])),
            _compactStatusChip(context, 'Letzte Freigabe', _millisecondsText(diagnostics['last_drive_ready_age_ms'])),
            _compactStatusChip(context, 'Timeout', _secondsText(diagnostics['mower_logic_gps_timeout_s'])),
            _compactStatusChip(context, 'Grace', _secondsText(diagnostics['mower_logic_gps_grace_remaining_s'])),
          ],
        ),
      ],
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
    final jsonText = controller.exportJsonString();
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: _rawJsonExpanded,
        onExpansionChanged: (expanded) => setState(() => _rawJsonExpanded = expanded),
        leading: const Icon(Icons.code),
        title: const Text('JSON-Ansicht / GPS-Diagnose'),
        subtitle: const Text('Settings sowie Definition und Status aller States als read-only Snapshot'),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _snapshotDownloadInProgress ? null : () => _downloadGpsSnapshot(context),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Snapshot'),
            ),
            Icon(_rawJsonExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
          ],
        ),
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
                    Expanded(
                      child: Text(
                        'Der JSON-Snapshot enthält alle aktuell in der App vorhandenen GPS-State-Daten: Settings, Definitionen und Status von State0 bis State4, MQTT-Topics, Empfangszeiten, Validierungen, Neustartstatus und noch nicht gespeicherte Einstellungsentwürfe. Er löst keine neue MQTT-Aktualisierung aus.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GPS-Diagnose-JSON wurde kopiert.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Kopieren'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  jsonText,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadGpsSnapshot(BuildContext context) async {
    if (_snapshotDownloadInProgress) return;
    setState(() => _snapshotDownloadInProgress = true);

    final now = DateTime.now();
    final fileName = 'openmower-gps-state-snapshot-'
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}.json';
    try {
      // Build the JSON only when the button is pressed so generated_at and all
      // exported values represent the exact local app state at that moment.
      final jsonText = controller.exportJsonString();
      await saveTextFile(
        fileName: fileName,
        content: jsonText,
        mimeType: 'application/json',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS-State-Snapshot wurde als $fileName bereitgestellt.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS-State-Snapshot konnte nicht gespeichert werden: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _snapshotDownloadInProgress = false);
      }
    }
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
    ValueChanged<bool>? onExpansionChanged,
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
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.55)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
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
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 190),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
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

  Widget _compactStatusChip(BuildContext context, String label, String value, {bool accent = false, bool warning = false}) {
    final theme = Theme.of(context);
    final color = warning
        ? Colors.orange.shade700
        : accent
            ? Colors.green.shade700
            : theme.textTheme.bodySmall?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _messageBox(BuildContext context, String title, String message) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(message, style: theme.textTheme.bodySmall),
        ],
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
          const DataColumn(label: Text('GNSS-ID'), numeric: true),
          const DataColumn(label: Text('SV'), numeric: true),
          const DataColumn(label: Text('C/N0 (dB-Hz)'), numeric: true),
          const DataColumn(label: Text('Elevation (°)'), numeric: true),
          const DataColumn(label: Text('Azimuth (°)'), numeric: true),
          const DataColumn(label: Text('PRRes'), numeric: true),
          const DataColumn(label: Text('Qual'), numeric: true),
          if (showUsed) const DataColumn(label: Text('Used')),
        ],
        rows: satellites.map((satellite) {
          return DataRow(
            cells: [
              DataCell(Text(_satText(satellite, const ['gnss', 'system', 'constellation']))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['gnss_id', 'gnssId'])))),
              DataCell(Text(_satText(satellite, const ['sv', 'svid', 'id', 'satellite_id', 'prn']))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['cn0', 'cno', 'c_n0'])))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['elev', 'elevation'])))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['azim', 'azimuth', 'az'])))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['prres', 'pr_res'])))),
              DataCell(Text(_fmt(_satDouble(satellite, const ['qual', 'quality'])))),
              if (showUsed) DataCell(_usedIcon(_satBool(satellite, const ['used', 'in_fix', 'fix_used']))),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _state0DecisionHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).hintColor,
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 920),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 52),
              SizedBox(width: 360, child: Text('Entscheidungsknoten', style: style)),
              SizedBox(width: 200, child: Text('Aktueller Wert', style: style)),
              SizedBox(width: 170, child: Text('Bedingung', style: style)),
              SizedBox(width: 130, child: Text('Ergebnis', style: style)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _state0DecisionList(
    BuildContext context,
    List<_DecisionRow> rows, {
    required bool snapshotCurrent,
    required bool waiting,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _state0DecisionRow(
              context,
              row,
              snapshotCurrent: snapshotCurrent,
              waiting: waiting,
            ),
          )).toList(growable: false),
    );
  }

  Widget _state0DecisionRow(
    BuildContext context,
    _DecisionRow row, {
    required bool snapshotCurrent,
    required bool waiting,
  }) {
    final theme = Theme.of(context);
    final effectiveState = snapshotCurrent ? _decisionConditionState(row) : _DecisionConditionState.unknown;
    final color = _decisionStateColor(effectiveState);
    final stateLabel = waiting
        ? 'Aktualisierung'
        : snapshotCurrent
            ? _decisionStateLabel(effectiveState)
            : 'Nicht aktuell';

    final line = Container(
      constraints: const BoxConstraints(minWidth: 920, minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: row.isBlocking && snapshotCurrent ? 0.065 : 0.025),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: color, width: row.isBlocking && snapshotCurrent ? 4 : 3),
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Row(
              children: [
                Icon(_decisionStateIcon(effectiveState), color: color, size: 18),
                const SizedBox(width: 5),
                Text(row.number, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          SizedBox(
            width: 360,
            child: Tooltip(
              message: row.description.isEmpty ? row.label : '${row.label}\n${row.description}',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (row.isBlocking && snapshotCurrent) ...[
                    const SizedBox(width: 6),
                    _state0SmallPill(context, 'BLOCKIERT ZUERST', Colors.red.shade700),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              snapshotCurrent ? row.value : 'Warte auf aktuellen Wert',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 170,
            child: Text(
              row.threshold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 130,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.42)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_decisionStateIcon(effectiveState), size: 14, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        stateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: line);
  }

  Widget _state0SmallPill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
    );
  }

  _DecisionConditionState _decisionConditionState(_DecisionRow row) {
    final ok = _boolNullable(row.ok);
    final text = row.status.toLowerCase();
    if (row.isBlocking) return _DecisionConditionState.failed;
    if (ok == true) return _DecisionConditionState.passed;
    if (ok == false) {
      if (row.severity == 1 || text.contains('warn') || text.contains('toleranz') || text.contains('grace')) {
        return _DecisionConditionState.warning;
      }
      return _DecisionConditionState.failed;
    }
    if (row.severity >= 2 || text.contains('fail') || text.contains('fehler') || text.contains('blocked') || text.contains('blockiert')) {
      return _DecisionConditionState.failed;
    }
    if (row.severity == 1 || text.contains('warn') || text.contains('prüfen') || text.contains('pruefen') || text.contains('missing') || text.contains('fehlt')) {
      return _DecisionConditionState.warning;
    }
    return _DecisionConditionState.unknown;
  }

  Color _decisionStateColor(_DecisionConditionState state) {
    switch (state) {
      case _DecisionConditionState.passed:
        return Colors.green.shade700;
      case _DecisionConditionState.warning:
        return Colors.orange.shade700;
      case _DecisionConditionState.failed:
        return Colors.red.shade700;
      case _DecisionConditionState.unknown:
        return Colors.amber.shade800;
    }
  }

  IconData _decisionStateIcon(_DecisionConditionState state) {
    switch (state) {
      case _DecisionConditionState.passed:
        return Icons.check_circle_outline;
      case _DecisionConditionState.warning:
        return Icons.report_problem_outlined;
      case _DecisionConditionState.failed:
        return Icons.cancel_outlined;
      case _DecisionConditionState.unknown:
        return Icons.help_outline;
    }
  }

  String _decisionStateLabel(_DecisionConditionState state) {
    switch (state) {
      case _DecisionConditionState.passed:
        return 'Erfüllt';
      case _DecisionConditionState.warning:
        return 'Prüfen';
      case _DecisionConditionState.failed:
        return 'Blockiert';
      case _DecisionConditionState.unknown:
        return 'Nicht bewertet';
    }
  }

  Widget _usedIcon(bool used) {
    if (used) {
      return Icon(Icons.check, color: Colors.green.shade700, size: 18);
    }
    return const Text('–');
  }

  Widget _headerIcon(BuildContext context, IconData icon, {required bool active}) {
    final color = active ? Theme.of(context).primaryColor : Theme.of(context).hintColor;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  List<_DecisionRow> _state0DecisionRows(
    Map<String, dynamic> definition,
    Map<String, dynamic> status,
  ) {
    final definitionChecks = _state0ChecksMap(definition);
    final statusChecks = _state0ChecksMap(status);
    final rootStatus = status;
    final blockingStage = rootStatus['blocking_stage'];
    final blockingKey = _text(rootStatus['blocking_key']);

    // New State0 consists of two retained MQTT messages: a static definition
    // and a live status. Merge both sides by the stable check id so the list
    // can show definition data and live result in one clearly marked row.
    if (definitionChecks.isNotEmpty || statusChecks.isNotEmpty) {
      final orderedKeys = <String>[];
      final allKeys = <String>{...definitionChecks.keys, ...statusChecks.keys};
      final sorted = allKeys.toList(growable: false)
        ..sort((a, b) {
          final aStage = _int(statusChecks[a]?['stage'] ?? definitionChecks[a]?['stage']);
          final bStage = _int(statusChecks[b]?['stage'] ?? definitionChecks[b]?['stage']);
          if (aStage != bStage) return aStage.compareTo(bStage);
          return a.compareTo(b);
        });
      orderedKeys.addAll(sorted);

      var index = 1;
      return orderedKeys.map<_DecisionRow>((key) {
        final row = _buildState0DecisionRowData(
          key,
          definitionChecks[key],
          statusChecks[key],
          index,
          blockingStage: blockingStage,
          blockingKey: blockingKey,
        );
        index++;
        return row;
      }).toList(growable: false);
    }

    if (definition.isNotEmpty) {
      return _decisionRowsFromPayload(definition);
    }
    return const <_DecisionRow>[];
  }

  Map<String, Map<String, dynamic>> _state0ChecksMap(Map<String, dynamic> payload) {
    final raw = payload['checks'];
    if (raw is! Map) return const <String, Map<String, dynamic>>{};
    final result = <String, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        result[entry.key.toString()] = map;
      }
    }
    return result;
  }

  _DecisionRow _buildState0DecisionRowData(
    String checkId,
    Map<String, dynamic>? definition,
    Map<String, dynamic>? status,
    int fallbackIndex, {
    dynamic blockingStage,
    String blockingKey = '',
  }) {
    final stage = _text(status?['stage'] ?? definition?['stage'], fallback: fallbackIndex.toString());
    final label = _text(
      definition?['title'] ?? status?['title'] ?? definition?['name'] ?? status?['name'],
      fallback: checkId,
    );
    final description = _text(definition?['description'] ?? status?['description']);
    final value = _state0ValueText(status, definition);
    final threshold = _state0ThresholdText(status, definition);
    final statusText = _text(status?['status'] ?? status?['result'] ?? status?['state'], fallback: definition == null ? 'Definition fehlt' : 'Status fehlt');
    final source = _text(definition?['source'] ?? status?['source'], fallback: _text(status?['key'] ?? definition?['key'], fallback: checkId));
    final key = _text(status?['key'] ?? definition?['key'], fallback: checkId);

    return _DecisionRow(
      number: stage,
      label: label,
      description: description,
      value: value,
      threshold: threshold,
      status: statusText,
      ok: _state0StatusOk(status),
      source: source,
      key: key,
      severity: _int(status?['severity']),
      isBlocking: _state0CheckIsBlocking(stage, checkId, key, blockingStage: blockingStage, blockingKey: blockingKey),
    );
  }

  bool _state0CheckIsBlocking(
    String stage,
    String checkId,
    String key, {
    dynamic blockingStage,
    String blockingKey = '',
  }) {
    final blockingStageText = _text(blockingStage);
    if (blockingStageText.isNotEmpty && stage == blockingStageText) return true;
    if (blockingKey.isEmpty) return false;
    return checkId == blockingKey || key == blockingKey;
  }

  String _state0ValueText(Map<String, dynamic>? status, Map<String, dynamic>? definition) {
    if (status == null) {
      final expected = definition?['expected'];
      if (expected != null) return 'Soll: ${_formatValue(expected)}';
      return '-';
    }
    final display = _text(status['display']);
    if (display.isNotEmpty) return display;
    if (status.containsKey('value')) return _formatValue(status['value']);
    return '-';
  }

  String _state0ThresholdText(Map<String, dynamic>? status, Map<String, dynamic>? definition) {
    final operator = _text(definition?['operator'] ?? status?['operator']);
    final unit = _text(definition?['unit'] ?? status?['unit']);
    final expected = definition?['expected'] ?? status?['expected'];
    if (expected != null) return '${operator.isEmpty ? 'Soll' : operator} ${_formatValue(expected)}';
    final threshold = status?['threshold'] ?? definition?['threshold'] ?? definition?['default_threshold'];
    if (threshold == null) return '-';
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (operator == '>') return '> ${_formatValue(threshold)}$suffix';
    if (operator == '<') return '< ${_formatValue(threshold)}$suffix';
    if (operator == '>=') return '>= ${_formatValue(threshold)}$suffix';
    if (operator == '<=') return '<= ${_formatValue(threshold)}$suffix';
    return '${operator.isEmpty ? 'Grenze' : operator} ${_formatValue(threshold)}$suffix';
  }

  bool? _state0StatusOk(Map<String, dynamic>? status) {
    if (status == null) return null;
    final explicit = _firstValue(status, const ['ok', 'valid', 'passed', 'ready', 'success']);
    final explicitBool = _boolNullable(explicit);
    if (explicitBool != null) return explicitBool;
    final text = _text(status['status'] ?? status['result'] ?? status['state']).toLowerCase();
    if (text == 'ok' || text == 'passed' || text == 'ready' || text == 'true') return true;
    if (text == 'fail' || text == 'failed' || text == 'error' || text == 'blocked' || text == 'false') return false;
    if (_int(status['severity']) > 0) return false;
    return null;
  }

  List<_DecisionRow> _decisionRowsFromPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) return const <_DecisionRow>[];
    final rawList = _firstValue(payload, const [
      'steps',
      'checks',
      'decision_steps',
      'decision_chain',
      'diagnostics',
      'stages',
      'tests',
      'items',
      'nodes',
      'decisions',
    ]);
    final rows = <_DecisionRow>[];
    if (rawList is Iterable) {
      var index = 1;
      for (final item in rawList) {
        rows.add(_decisionRowFromItem(item, index));
        index++;
      }
      return rows;
    }
    if (rawList is Map) {
      var index = 1;
      for (final entry in rawList.entries) {
        rows.add(_decisionRowFromItem(entry.value, index, fallbackLabel: entry.key.toString()));
        index++;
      }
      return rows;
    }
    var index = 1;
    for (final entry in payload.entries) {
      if (const {'schema', 'state', 'updated_at', 'updatedAt', 'timestamp'}.contains(entry.key)) continue;
      final value = entry.value;
      if (value is Map || value is Iterable) {
        rows.add(_decisionRowFromItem(value, index, fallbackLabel: entry.key));
      } else {
        rows.add(_DecisionRow(
          number: index.toString(),
          label: entry.key,
          value: _formatValue(value),
          threshold: '-',
          status: '-',
          ok: null,
          key: entry.key,
        ));
      }
      index++;
    }
    return rows;
  }

  _DecisionRow _decisionRowFromItem(dynamic item, int fallbackIndex, {String? fallbackLabel}) {
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      final number = _text(_firstValue(map, const ['stage', 'index', 'step', 'number', 'id']), fallback: fallbackIndex.toString());
      final label = _text(
        _firstValue(map, const ['label', 'title', 'name', 'node', 'check', 'description']),
        fallback: fallbackLabel ?? 'Prüfschritt $fallbackIndex',
      );
      final description = _text(map['description']);
      final value = _text(map['display']).isNotEmpty
          ? _text(map['display'])
          : _formatValue(_firstValue(map, const ['value', 'actual', 'measured', 'current', 'observed', 'status_value']));
      final threshold = _formatValue(_firstValue(map, const ['threshold', 'limit', 'required', 'expected', 'max', 'min', 'range']));
      final statusValue = _firstValue(map, const ['status', 'result', 'state', 'reason']);
      final ok = _firstValue(map, const ['ok', 'valid', 'passed', 'ready', 'success']) ?? _state0StatusOk(map);
      final status = statusValue == null
          ? (_boolNullable(ok) == null ? '-' : (_boolNullable(ok)! ? 'OK' : 'Fehler'))
          : _formatValue(statusValue);
      return _DecisionRow(
        number: number,
        label: label,
        description: description,
        value: value,
        threshold: threshold,
        status: status,
        ok: ok,
        source: _text(map['source'] ?? map['key'], fallback: fallbackLabel ?? '-'),
        key: _text(map['key'], fallback: fallbackLabel ?? ''),
        severity: _int(map['severity']),
      );
    }
    return _DecisionRow(
      number: fallbackIndex.toString(),
      label: fallbackLabel ?? 'Prüfschritt $fallbackIndex',
      value: _formatValue(item),
      threshold: '-',
      status: '-',
      ok: null,
      key: fallbackLabel ?? '',
    );
  }

  dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) return map[key];
    }
    return null;
  }

  bool _containsAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) return true;
    }
    return false;
  }

  String _systemChipText(String key, dynamic value) {
    if (value is Map) {
      final visible = value['visible'] ?? value['visible_count'];
      final used = value['used'] ?? value['used_count'];
      final parts = <String>[];
      if (visible != null) parts.add('sichtbar ${_fmt(visible)}');
      if (used != null) parts.add('used ${_fmt(used)}');
      if (parts.isNotEmpty) return '$key ${parts.join(' / ')}';
    }
    return '$key ${_formatValue(value)}';
  }

  String _restartResetModeLabel(String mode) {
    switch (mode) {
      case 'controlled_software':
        return 'controlled_software (Standard)';
      case 'gnss_only':
        return 'gnss_only';
      case 'hardware_watchdog':
        return 'hardware_watchdog';
    }
    return mode;
  }

  bool _restartStatusOk(Map<String, dynamic> status) {
    final text = _text(status['status']).toLowerCase();
    return text == 'sent' || text == 'requested' || text == 'ok' || text == 'accepted';
  }

  bool _restartStatusRejected(Map<String, dynamic> status) {
    final text = _text(status['status']).toLowerCase();
    return text == 'rejected' || text == 'send_failed' || text == 'failed' || text == 'error';
  }

  String _metersText(dynamic value) {
    if (value == null || value.toString().trim().isEmpty || value.toString().trim().toLowerCase() == 'null') return '-';
    return '${_fmt(value)} m';
  }

  String _millisecondsText(dynamic value) {
    if (value == null || value.toString().trim().isEmpty || value.toString().trim().toLowerCase() == 'null') return '-';
    final numeric = _double(value);
    if (numeric >= 1000) return '${(numeric / 1000).toStringAsFixed(1)} s';
    return '${_fmt(value)} ms';
  }

  String _secondsText(dynamic value) {
    if (value == null || value.toString().trim().isEmpty || value.toString().trim().toLowerCase() == 'null') return '-';
    return '${_fmt(value)} s';
  }

  String _boolText(dynamic value) {
    final parsed = _boolNullable(value);
    if (parsed == null) return '-';
    return parsed ? 'Ja' : 'Nein';
  }

  bool? _boolNullable(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'null' || text == '-') return null;
    if (text == 'true' || text == '1' || text == 'yes' || text == 'on' || text == 'ja' || text == 'ok' || text == 'passed' || text == 'ready' || text == 'sent' || text == 'requested') return true;
    if (text == 'false' || text == '0' || text == 'no' || text == 'off' || text == 'nein' || text == 'failed' || text == 'error' || text == 'rejected' || text == 'blocked') return false;
    return null;
  }

  bool _accuracyOk(dynamic accuracy, dynamic limit) {
    if (accuracy == null || limit == null) return false;
    return _double(accuracy) >= 0 && _double(accuracy) <= _double(limit);
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

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is Map || value is Iterable) return const JsonEncoder.withIndent('  ').convert(value);
    if (value is bool) return value ? 'Ja' : 'Nein';
    return _fmt(value);
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
    return text == 'true' || text == '1' || text == 'yes' || text == 'on' || text == 'ja' || text == 'ok' || text == 'ready';
  }

  bool _qualityGood(dynamic quality) {
    final text = quality?.toString().toLowerCase() ?? '';
    return text.contains('good') || text.contains('fix') || text.contains('fixed') || text.contains('ok');
  }

  String _clockText(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.${three(local.millisecond)}';
  }

}

enum _DecisionConditionState { passed, warning, failed, unknown }

class _DecisionRow {
  const _DecisionRow({
    required this.number,
    required this.label,
    this.description = '',
    required this.value,
    required this.threshold,
    required this.status,
    required this.ok,
    this.source = '',
    this.key = '',
    this.severity = 0,
    this.isBlocking = false,
  });

  final String number;
  final String label;
  final String description;
  final String value;
  final String threshold;
  final String status;
  final dynamic ok;
  final String source;
  final String key;
  final int severity;
  final bool isBlocking;
}
