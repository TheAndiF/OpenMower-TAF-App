import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/gps_state_controller.dart';
import 'package:open_mower_app/controllers/satellite_logging_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/services/platform_text_file.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class GpsStateScreen extends StatefulWidget {
  const GpsStateScreen({super.key});

  @override
  State<GpsStateScreen> createState() => _GpsStateScreenState();
}

class _GpsStateScreenState extends State<GpsStateScreen> {
  final GpsStateController controller = Get.find<GpsStateController>();
  final SatelliteLoggingController loggingController = Get.find<SatelliteLoggingController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  bool _renewSent = false;
  bool _rawJsonExpanded = false;
  bool _snapshotDownloadInProgress = false;
  String _selectedRestartMode = 'hot_start';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestSettings();
        controller.requestState0Update(automatic: true);
        controller.requestRestartStatus();
        loggingController.requestStatus();
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
                  _buildRestartSection(context),
                  const SizedBox(height: 10),
                  _buildGpsLoggingSection(context),
                  const SizedBox(height: 10),
                  _buildSettingsSection(context),
                  const SizedBox(height: 10),
                  _buildRawJsonSection(context),
                  const SizedBox(height: 10),
                  Text(
                    'Hinweis: Fahrfähigkeit fasst Bedienstatus und Entscheidungskette zusammen. Die vollständige Liste sichtbarer Satelliten wird nur bei Bedarf zugeschaltet.',
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
                        'Auswertung von gps_state.v3: getrennte Definitionen und Statusdaten, kanonische State1-State4-Topics, Lease-Aktivierung und Diagnoseexport.',
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: refresh),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                refresh,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildState1Section(BuildContext context) {
    final state = controller.state1;
    final ready = _boolNullable(state['drive_ready'] ?? state['gps_drive_ready']);
    return _sectionCard(
      context,
      icon: ready == true
          ? Icons.check_circle
          : ready == false
              ? Icons.cancel
              : Icons.help_outline,
      iconColor: ready == true
          ? Colors.green.shade700
          : ready == false
              ? Colors.red.shade700
              : Theme.of(context).hintColor,
      title: 'Fahrfähigkeit (State1)',
      subtitle: state.isEmpty
          ? 'Noch keine Fahrfähigkeitsdaten empfangen'
          : 'Bedienstatus, erster Blockierer und vollständige Entscheidungskette',
      active: ready == true,
      initiallyExpanded: true,
      child: _buildState0Section(context),
    );
  }


  Widget _state2Group(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 7),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  Widget _buildState2Section(BuildContext context) {
    final state = controller.state2;
    final systems = state['systems'];
    final stale = _statePayloadIsStale(state);
    return _sectionCard(
      context,
      icon: Icons.signal_cellular_alt,
      title: 'GNSS, Pose und Satelliten (State2)',
      subtitle: state.isEmpty
          ? 'Noch keine technischen Qualitätsdaten empfangen'
          : stale
              ? 'Daten veraltet - neue GNSS-/Pose-Daten werden erwartet'
              : 'Empfang, RTK, Pose, Diagnose und bedarfsgesteuerte Satellitenliste',
      initiallyExpanded: false,
      onExpansionChanged: (open) {
        controller.setDetailStateActive(2, open, satelliteMode: 'used');
        controller.setDetailStateActive(3, open);
        if (!open && controller.state4Active) controller.setDetailStateActive(4, false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale) ...[
            _staleDataNotice(context, state, stateName: 'State2'),
            const SizedBox(height: 12),
          ],
          Opacity(
            opacity: stale ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 1080
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth >= 700
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _state2Group(
                            context,
                            title: 'Empfang',
                            icon: Icons.satellite_alt_outlined,
                            children: [
                              _compactStatusChip(context, 'Verfügbar', _boolText(state['available']), accent: !stale && _boolNullable(state['available']) == true, warning: _boolNullable(state['available']) == false),
                              _compactStatusChip(context, 'Sichtbar', _fmt(state['visible_count'] ?? state['visible'])),
                              _compactStatusChip(context, 'Verwendet', _fmt(state['used_count'] ?? state['used']), accent: !stale && _int(state['used_count'] ?? state['used']) > 0),
                              _compactStatusChip(context, 'Ø C/N0', '${_fmt(state['avg_cn0'])} dB-Hz', accent: !stale && _double(state['avg_cn0']) >= 30),
                              _compactStatusChip(context, 'Min C/N0', '${_fmt(state['min_cn0'])} dB-Hz'),
                              _compactStatusChip(context, 'Max C/N0', '${_fmt(state['max_cn0'])} dB-Hz'),
                              _compactStatusChip(context, 'Gut', _fmt(state['good_count']), accent: !stale && _int(state['good_count']) > 0),
                              _compactStatusChip(context, 'Schwach', _fmt(state['weak_count']), warning: !stale && _int(state['weak_count']) > 0),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _state2Group(
                            context,
                            title: 'RTK und Genauigkeit',
                            icon: Icons.gps_fixed,
                            children: [
                              _compactStatusChip(context, 'RTK', _text(state['rtk_state'], fallback: '-'), accent: !stale && _text(state['rtk_state']).toLowerCase() == 'fixed'),
                              _compactStatusChip(context, 'Quality', _text(state['quality_class'], fallback: '-'), accent: !stale && _qualityGood(state['quality_class'])),
                              _compactStatusChip(context, 'LL Genauigkeit', _metersText(state['ll_gps_accuracy_m'] ?? state['ll_gps_position_accuracy_m'])),
                              _compactStatusChip(context, 'XB Genauigkeit', _metersText(state['xb_pose_accuracy_m']), warning: !stale && _double(state['xb_pose_accuracy_m']) > 1),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _state2Group(
                            context,
                            title: 'Pose und Aktualität',
                            icon: Icons.navigation_outlined,
                            children: [
                              _compactStatusChip(context, 'Pose aktuell', _boolText(state['recent_absolute_pose']), accent: !stale && _boolNullable(state['recent_absolute_pose']) == true, warning: !stale && _boolNullable(state['recent_absolute_pose']) == false),
                              _compactStatusChip(context, 'Orientierung', _boolText(state['orientation_valid']), accent: !stale && _boolNullable(state['orientation_valid']) == true, warning: !stale && _boolNullable(state['orientation_valid']) == false),
                              _compactStatusChip(context, 'Quelldaten-Alter', _millisecondsText(state['age_ms']), warning: stale || _boolNullable(state['stale']) == true),
                              _compactStatusChip(context, 'GPS Timeout', _boolText(state['gps_timeout']), accent: !stale && _boolNullable(state['gps_timeout']) == false, warning: !stale && _boolNullable(state['gps_timeout']) == true),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
                const SizedBox(height: 16),
                _buildCombinedSatellitePanel(context),
                const SizedBox(height: 10),
                Text(
                  'Schwellen: schwach < ${controller.settingDouble('weak_cn0_threshold', fallback: 20).toStringAsFixed(1)} dB-Hz, gut ≥ ${controller.settingDouble('good_cn0_threshold', fallback: 30).toStringAsFixed(1)} dB-Hz',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCombinedSatellitePanel(BuildContext context) {
    final showAll = controller.state4Active;
    final state = showAll ? controller.state4 : controller.state3;
    final satellites = controller.satellitesForState(showAll ? 4 : 3);
    final stale = _statePayloadIsStale(state);
    final visible = controller.state4['visible_count'] ?? controller.state2['visible_count'] ?? satellites.length;
    final used = controller.state3['used_count'] ?? controller.state2['used_count'] ?? controller.state2['used'] ?? satellites.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Satelliten', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    showAll
                        ? '${_fmt(visible)} sichtbar · ${_fmt(used)} verwendet'
                        : '${_fmt(used)} verwendete Satelliten',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ],
              );
              final toggle = SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Alle sichtbaren Satelliten anzeigen'),
                subtitle: const Text('Erhöht den MQTT-Traffic nur während der Diagnose.'),
                value: showAll,
                onChanged: (value) => controller.setState4Enabled(value),
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 6), toggle],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  SizedBox(width: 390, child: toggle),
                ],
              );
            },
          ),
          if (stale) ...[
            const SizedBox(height: 8),
            _staleDataNotice(context, state, stateName: showAll ? 'sichtbare Satelliten' : 'verwendete Satelliten'),
          ],
          const SizedBox(height: 10),
          Opacity(
            opacity: stale ? 0.55 : 1,
            child: _satelliteTable(
              context,
              satellites,
              showUsed: showAll,
              viewportHeight: showAll ? 440 : 320,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildState3Section(BuildContext context) {
    final state = controller.state3;
    final satellites = controller.satellitesForState(3);
    final usedCount = state['used_count'] ?? satellites.length;
    final stale = _statePayloadIsStale(state);
    return _sectionCard(
      context,
      icon: Icons.hub_outlined,
      title: 'Aktiv verwendete Satelliten (State3)',
      subtitle: satellites.isEmpty
          ? 'Noch keine verwendeten Satelliten empfangen'
          : stale
              ? 'Satellitendaten veraltet - neue NAV-SAT-Daten werden erwartet'
              : 'Verwendet laut Payload: ${_fmt(usedCount)}',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale) ...[
            _staleDataNotice(context, state, stateName: 'State3'),
            const SizedBox(height: 12),
          ],
          Opacity(
            opacity: stale ? 0.55 : 1,
            child: _satelliteTable(
              context,
              satellites,
              showUsed: false,
              viewportHeight: 320,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildState4Section(BuildContext context) {
    final state = controller.state4;
    final satellites = controller.satellitesForState(4);
    final active = controller.state4Active;
    final stale = _statePayloadIsStale(state);
    return _sectionCard(
      context,
      icon: Icons.satellite_outlined,
      title: 'Expertenliste aller sichtbaren Satelliten (State4)',
      subtitle: stale
          ? 'Daten veraltet - neue NAV-SAT-Daten werden erwartet'
          : active
              ? 'Aktiv - vollständige Satellitenliste'
              : 'Deaktiviert - nur bei Diagnose aktivieren',
      active: active && !stale,
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
          if (stale) ...[
            const SizedBox(height: 12),
            _staleDataNotice(context, state, stateName: 'State4'),
          ],
          Opacity(
            opacity: stale ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricTile(context, 'Sichtbar', _fmt(state['visible_count'] ?? satellites.length)),
                      _metricTile(context, 'Verwendet', _fmt(state['used_count']), accent: !stale && _int(state['used_count']) > 0),
                      _metricTile(context, 'Ø C/N0', '${_fmt(state['avg_cn0'])} dB-Hz'),
                      _metricTile(context, 'Min C/N0', '${_fmt(state['min_cn0'])} dB-Hz'),
                      _metricTile(context, 'Max C/N0', '${_fmt(state['max_cn0'])} dB-Hz'),
                      _metricTile(context, 'Sensor-Zeit', _text(state['sensor_stamp'], fallback: '-')),
                    ],
                  ),
                ],
                if (active) ...[
                  const SizedBox(height: 12),
                  _satelliteTable(
                    context,
                    satellites,
                    showUsed: true,
                    viewportHeight: 440,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildState0Section(BuildContext context) {
    final definition = controller.state0Definition;
    final status = controller.state0Status;
    final rows = _state0DecisionRows(definition, status);
    final waiting = controller.state0WaitingForUpdate.value;
    final snapshotCurrent = controller.state0SnapshotIsCurrent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (waiting || !snapshotCurrent)
          _state0RefreshBanner(context, waiting: waiting)
        else if (status.isNotEmpty)
          _state0ReadinessBanner(context, status, rows),
        const SizedBox(height: 10),
        _state0UpdateControls(
          context,
          waiting: waiting,
          snapshotCurrent: snapshotCurrent,
        ),

        if (definition.isEmpty && status.isNotEmpty) ...[
          const SizedBox(height: 10),
          _messageBox(
            context,
            'Hinweis',
            'Live-Status wurde empfangen, aber die statische Definition fehlt noch. Topic gps_state/state1/definition prüfen.',
          ),
        ],
        if (definition.isNotEmpty && status.isEmpty) ...[
          const SizedBox(height: 10),
          _messageBox(
            context,
            'Hinweis',
            'Definition wurde empfangen, aber der Live-Status fehlt noch. Mit „Fahrfähigkeit aktualisieren“ einen neuen Stand anfordern.',
          ),
        ],
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Text(
            'Keine auswertbare Entscheidungskette empfangen.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
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
                : 'Beim Öffnen wird automatisch ein aktueller State1-Snapshot angefordert.';
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
          label: const Text('Fahrfähigkeit aktualisieren'),
        ),
      ],
    );
  }

  Widget _state0RefreshBanner(BuildContext context, {required bool waiting}) {
    final theme = Theme.of(context);
    final color = Colors.orange.shade700;
    final message = waiting
        ? 'Die angezeigten Prüfpunkte werden bis zum Eingang einer neuen State1-Statusmeldung nicht als aktuell gewertet.'
        : controller.state0UpdateMessage.value.isNotEmpty
            ? controller.state0UpdateMessage.value
            : 'Für diese Ansicht liegt noch kein seit dem Öffnen angeforderter State1-Snapshot vor.';
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
    final last = controller.restartLastPayload;
    final validation = controller.restartValidationPayload;
    final controlsDisabled = controller.restartControlsDisabled;
    final waiting = controller.waitingForResponse.value;
    return _sectionCard(
      context,
      icon: Icons.restart_alt,
      title: 'F9P-Neustart und Recovery',
      subtitle: status.isEmpty
          ? 'Reset-Modus und Starttyp wählen'
          : 'Aktueller Zustand: ${_restartStatusLabel(_text(status['status']))}',
      active: _text(status['status']).toLowerCase() == 'success',
      initiallyExpanded: status.isNotEmpty || last.isNotEmpty || validation.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ein Neustart gilt erst als erfolgreich, wenn nach UBX-CFG-RST sowohl neue NAV-PVT- als auch neue NAV-SAT-Daten empfangen und die Empfängerausgaben bestätigt wurden.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 14),
          Text('1. Reset-Modus auswählen', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              key: ValueKey('restart-reset-${controller.restartResetMode.value}'),
              initialValue: controller.restartResetMode.value,
              decoration: const InputDecoration(
                labelText: 'Reset-Modus',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: GpsStateController.restartResetModes
                  .map((mode) => DropdownMenuItem<String>(value: mode, child: Text(_restartResetModeLabel(mode))))
                  .toList(growable: false),
              onChanged: controlsDisabled ? null : (value) {
                if (value != null) controller.restartResetMode.value = value;
              },
            ),
          ),
          const SizedBox(height: 14),
          Text('2. Starttyp auswählen', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                selected: _selectedRestartMode == 'hot_start',
                avatar: const Icon(Icons.flash_on, size: 18),
                label: const Text('Hot Start'),
                onSelected: controlsDisabled ? null : (_) => setState(() => _selectedRestartMode = 'hot_start'),
              ),
              ChoiceChip(
                selected: _selectedRestartMode == 'warm_start',
                avatar: const Icon(Icons.thermostat, size: 18),
                label: const Text('Warm Start'),
                onSelected: controlsDisabled ? null : (_) => setState(() => _selectedRestartMode = 'warm_start'),
              ),
              ChoiceChip(
                selected: _selectedRestartMode == 'cold_start',
                avatar: const Icon(Icons.ac_unit, size: 18),
                label: const Text('Cold Start'),
                onSelected: controlsDisabled ? null : (_) => setState(() => _selectedRestartMode = 'cold_start'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedRestartMode == 'hot_start'
                ? 'Schneller Neustart unter weitgehender Beibehaltung vorhandener Empfängerdaten.'
                : _selectedRestartMode == 'warm_start'
                    ? 'Teilweiser Neuaufbau der Navigationsdaten.'
                    : 'Vollständiger Neuaufbau; längste Wiederanlaufzeit.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 14),
          Text('3. Neustart ausführen', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: controlsDisabled
                    ? null
                    : () => controller.restartF9p(
                          _selectedRestartMode,
                          resetMode: controller.restartResetMode.value,
                        ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Neustart ausführen'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: waiting ? null : controller.requestRestartStatus,
                icon: waiting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('Status aktualisieren'),
              ),
            ],
          ),
          if (controller.restartInProgress) ...[
            const SizedBox(height: 8),
            Text(
              'Während der Recovery sind weitere Neustarts gesperrt.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
            ),
          ],
          const SizedBox(height: 16),
          _buildRestartCurrentStateField(context, status: status, last: last),
          if (validation.isNotEmpty && _boolNullable(validation['valid'] ?? validation['accepted']) == false) ...[
            const SizedBox(height: 12),
            _messageBox(
              context,
              'Neustartbefehl nicht angenommen',
              _text(validation['reason'] ?? validation['error'] ?? validation['message'], fallback: 'Der Neustartbefehl wurde vom Backend abgelehnt.'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestartCurrentStateField(
    BuildContext context, {
    required Map<String, dynamic> status,
    required Map<String, dynamic> last,
  }) {
    final theme = Theme.of(context);
    final rawStatus = _text(status['status']).toLowerCase();
    final effective = rawStatus.isEmpty || rawStatus == 'idle'
        ? _text(last['status']).toLowerCase()
        : rawStatus;
    final activePayload = rawStatus.isEmpty || rawStatus == 'idle' ? last : status;
    final color = _restartStatusColor(effective, theme);
    final inProgress = effective == 'requested' ||
        effective == 'accepted' ||
        effective == 'sent' ||
        effective == 'resetting' ||
        effective == 'waiting_for_receiver' ||
        effective == 'validating';
    final currentStep = _restartCurrentStepLabel(effective, activePayload);
    final completedAt = _restartTimestampText(
      activePayload['completed_at'] ?? last['completed_at'],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_restartStatusIcon(effective), color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aktueller Neustartstatus', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                    const SizedBox(height: 2),
                    Text(currentStep, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ),
              if (completedAt != '-' && (effective == 'success' || rawStatus.isEmpty || rawStatus == 'idle'))
                Text(
                  'Abgeschlossen: $completedAt',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (inProgress) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(color: color),
          ],
        ],
      ),
    );
  }

  String _restartCurrentStepLabel(String status, Map<String, dynamic> payload) {
    if (status.isEmpty || status == 'idle') {
      return 'Kein Neustart aktiv';
    }
    if (status == 'requested' || status == 'accepted' || status == 'sent' || status == 'resetting') {
      return 'Befehl gesendet';
    }
    if (status == 'waiting_for_receiver') {
      if (_boolNullable(payload['nav_pvt_received']) == true && _boolNullable(payload['nav_sat_received']) != true) {
        return 'NAV-PVT empfangen';
      }
      return 'Empfänger antwortet';
    }
    if (status == 'validating') {
      if (_boolNullable(payload['nav_sat_received']) == true) {
        return 'NAV-SAT empfangen';
      }
      return 'Empfängerausgaben werden bestätigt';
    }
    if (status == 'success') return 'Empfängerausgaben bestätigt';
    if (status == 'failed' || status == 'error' || status == 'rejected' || status == 'send_failed') {
      return 'Neustart fehlgeschlagen: ${_restartReasonLabel(_text(payload['reason']))}';
    }
    return _restartStatusLabel(status);
  }


  Widget _buildCompactLastRestartPanel(
    BuildContext context,
    Map<String, dynamic> payload,
  ) {
    final theme = Theme.of(context);
    final status = _text(payload['status']).toLowerCase();
    final failed = status == 'failed' || status == 'error' || status == 'rejected' || status == 'send_failed';
    final statusColor = _restartStatusColor(status, theme);
    final statusLabel = _restartStatusLabel(status);
    final reason = _text(payload['reason']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_restartStatusIcon(status), color: statusColor, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Letzter abgeschlossener Neustart', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(statusLabel, style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (payload['restart_sequence'] != null)
                _compactStatusChip(context, 'Restart', '#${_fmt(payload['restart_sequence'])}', accent: status == 'success', warning: failed),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactStatusChip(context, 'Startart', _restartModeLabel(_text(payload['mode'], fallback: '-'))),
              _compactStatusChip(context, 'Reset-Modus', _text(payload['reset_mode'], fallback: '-')),
              _compactStatusChip(context, 'Angefordert', _restartTimestampText(payload['requested_at'])),
              _compactStatusChip(context, 'Dauer', _restartDurationText(payload)),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text('Details anzeigen', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _compactStatusChip(context, 'Abgeschlossen', _restartTimestampText(payload['completed_at'])),
                        _compactStatusChip(context, 'Statuscode', _text(payload['status'], fallback: '-')),
                        _compactStatusChip(context, 'navBbrMask', _fmt(payload['nav_bbr_mask'])),
                        _compactStatusChip(context, 'resetMode-Wert', _fmt(payload['reset_mode_value'])),
                        _compactStatusChip(context, 'Quelle', _text(payload['source'], fallback: '-')),
                      ],
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _messageBox(
                        context,
                        'Ergebnis / Fehlergrund',
                        '${_restartReasonLabel(reason)}\nTechnischer Wert: $reason',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestartStatusPanel(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> payload,
    required bool live,
  }) {
    final theme = Theme.of(context);
    final status = _text(payload['status']).toLowerCase();
    final isIdle = status.isEmpty || status == 'idle';
    final statusColor = _restartStatusColor(status, theme);
    final statusLabel = isIdle ? 'Kein Neustart aktiv' : _restartStatusLabel(status);
    final inProgress = status == 'resetting' || status == 'waiting_for_receiver' || status == 'validating';
    final failed = status == 'failed' || status == 'error' || status == 'rejected' || status == 'send_failed';
    final requestState = isIdle
        ? null
        : failed && (status == 'rejected' || status == 'send_failed')
            ? false
            : true;
    final resetState = isIdle ||
            status == 'sent' ||
            status == 'requested' ||
            status == 'accepted' ||
            status == 'resetting'
        ? null
        : failed && (status == 'send_failed' || status == 'rejected')
            ? false
            : true;
    bool? navPvtState = _boolNullable(payload['nav_pvt_received']);
    bool? navSatState = _boolNullable(payload['nav_sat_received']);
    bool? confirmedState = _boolNullable(payload['receiver_restart_confirmed']);
    final reason = _text(payload['reason']);
    if (failed && navPvtState == null && reason == 'nav_pvt_not_received_after_reset') navPvtState = false;
    if (failed && navSatState == null && reason == 'nav_sat_not_received_after_reset') navSatState = false;
    if (status == 'success') {
      navPvtState ??= true;
      navSatState ??= true;
      confirmedState ??= true;
    } else if (failed) {
      confirmedState ??= false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_restartStatusIcon(status), color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(statusLabel, style: theme.textTheme.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (payload['restart_sequence'] != null)
                _compactStatusChip(context, 'Restart', '#${_fmt(payload['restart_sequence'])}', accent: status == 'success', warning: failed),
            ],
          ),
          if (inProgress) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(color: statusColor),
          ],
          const SizedBox(height: 12),
          _restartCheckRow(context, 'Restart-Anforderung empfangen', requestState),
          _restartCheckRow(context, 'F9P-Reset ausgeführt', resetState),
          _restartCheckRow(context, 'Neue NAV-PVT-Daten empfangen', navPvtState),
          _restartCheckRow(context, 'Neue NAV-SAT-Daten empfangen', navSatState),
          _restartCheckRow(context, 'Receiver-Neustart bestätigt', confirmedState),
          if (!isIdle) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _compactStatusChip(context, 'Startart', _restartModeLabel(_text(payload['mode'], fallback: '-'))),
                _compactStatusChip(context, 'Reset-Modus', _text(payload['reset_mode'], fallback: '-')),
                _compactStatusChip(context, 'Angefordert', _restartTimestampText(payload['requested_at'])),
                _compactStatusChip(context, 'Abgeschlossen', _restartTimestampText(payload['completed_at'])),
                _compactStatusChip(context, live && inProgress ? 'Laufzeit' : 'Dauer', _restartDurationText(payload, includeRunning: live && inProgress)),
              ],
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _messageBox(
              context,
              'Ergebnis / Fehlergrund',
              '${_restartReasonLabel(reason)}\nTechnischer Wert: $reason',
            ),
          ],
          if (!isIdle) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('Technische Details', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _compactStatusChip(context, 'Statuscode', _text(payload['status'], fallback: '-')),
                      _compactStatusChip(context, 'navBbrMask', _fmt(payload['nav_bbr_mask'])),
                      _compactStatusChip(context, 'resetMode-Wert', _fmt(payload['reset_mode_value'])),
                      _compactStatusChip(context, 'Quelle', _text(payload['source'], fallback: '-')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _restartCheckRow(BuildContext context, String label, bool? state) {
    final theme = Theme.of(context);
    final color = state == true
        ? Colors.green.shade700
        : state == false
            ? Colors.red.shade700
            : theme.hintColor;
    final icon = state == true
        ? Icons.check_circle
        : state == false
            ? Icons.cancel
            : Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: state == null ? FontWeight.normal : FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildDriveReadinessCard(BuildContext context, Map<String, dynamic> state) {
    final hasDriveFields = _containsAny(state, const [
      'gps_drive_ready',
      'gps_drive_state',
      'gps_drive_label',
      'gps_drive_reason',
      'gps_drive_block_reason',
    ]);
    final ready = _boolNullable(state['gps_drive_ready']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _compactStatusChip(
            context,
            'Status',
            _text(
              state['gps_drive_state'],
              fallback: hasDriveFields ? (ready == true ? 'ready' : 'stop') : '-',
            ),
            accent: ready == true,
          ),
          _compactStatusChip(
            context,
            'RTK',
            _text(state['rtk_state'], fallback: '-'),
            accent: _text(state['rtk_state']).toLowerCase() == 'fixed',
          ),
          _compactStatusChip(
            context,
            'Genauigkeit',
            _metersText(state['position_accuracy_m']),
            accent: _accuracyOk(state['position_accuracy_m'], state['max_position_accuracy_m']),
          ),
          _compactStatusChip(context, 'Grenzwert', _metersText(state['max_position_accuracy_m'])),
          _compactStatusChip(context, 'Pose-Alter', _millisecondsText(state['pose_age_ms'])),
          _compactStatusChip(
            context,
            'Quality',
            _text(state['quality_class'], fallback: '-'),
            accent: _qualityGood(state['quality_class']),
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

  Widget _buildGpsLoggingSection(BuildContext context) {
    final lc = loggingController;
    final runtime = lc.runtime;
    final last = lc.lastPayload;
    final busy = lc.waitingForResponse.value || lc.commandPending.value;
    final controlsEnabled = lc.hasValidV2Status && !busy;
    final actionLabel = lc.running ? 'Stop' : (lc.armed || lc.requestActive ? 'Abbrechen' : 'Start');
    final actionIcon = lc.running ? Icons.stop : (lc.armed || lc.requestActive ? Icons.cancel_outlined : Icons.fiber_manual_record);
    return _sectionCard(
      context,
      icon: Icons.settings_input_antenna,
      title: 'GPS-/RTK-Aufzeichnung',
      subtitle: lc.hasData ? (lc.summary.isEmpty ? 'Status: ${lc.state}' : lc.summary) : 'Noch kein retained Logging-Status empfangen',
      active: lc.running || lc.armed,
      initiallyExpanded: lc.running || lc.armed || lc.errorText.isNotEmpty || controller.hasLoggingDrafts,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metricTile(context, 'Zustand', lc.state.isEmpty ? '-' : lc.state, accent: lc.running || lc.armed, warning: lc.errorText.isNotEmpty),
          _metricTile(context, 'Anforderung', lc.requestActive ? 'aktiv' : 'keine', accent: lc.requestActive),
          _metricTile(context, 'Trigger', lc.trigger.isEmpty ? '-' : _loggingTriggerLabel(lc.trigger)),
          _metricTile(context, 'Modus', lc.mode.isEmpty ? '-' : _loggingModeLabel(lc.mode)),
          _metricTile(context, 'Session-ID', _text(runtime['session_id'], fallback: '-')),
          _metricTile(context, 'Dauer', '${_fmt(runtime['duration_s'])} s'),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
            onPressed: controlsEnabled ? () {
              if (lc.running) {
                lc.sendControl(<String, dynamic>{'command': 'stop'});
              } else if (lc.armed || lc.requestActive) {
                lc.sendControl(<String, dynamic>{'command': 'cancel'});
              } else {
                lc.sendControl(controller.buildLoggingStartPayload());
              }
            } : null,
            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(actionIcon),
            label: Text(actionLabel),
          ),
          OutlinedButton.icon(onPressed: busy ? null : lc.requestStatus, icon: const Icon(Icons.refresh), label: const Text('Renew')),
        ]),
        if (!lc.hasValidV2Status) ...[
          const SizedBox(height: 10),
          _messageBox(
            context,
            'Laufzeitsteuerung nicht verfügbar',
            'Start, Stop und Abbrechen werden erst aktiviert, wenn ein gültiger Status mit dem Schema openmower.gps_state.logging.v2 empfangen wurde.',
          ),
        ],
        if (lc.lastStatus.value.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(lc.lastStatus.value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: lc.lastStatusOk.value == false ? Theme.of(context).colorScheme.error : Theme.of(context).hintColor)),
        ],
        if (lc.errorText.isNotEmpty) ...[
          const SizedBox(height: 10),
          SelectableText(lc.errorText, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1),
        _buildLoggingSettingsEditor(context),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Text('Letzte Session', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (last.isEmpty)
          Text('Noch keine abgeschlossene oder abgebrochene Session empfangen.', style: Theme.of(context).textTheme.bodySmall)
        else
          Builder(builder: (context) {
            final lastRuntime = last['runtime'] is Map
                ? Map<String, dynamic>.from(last['runtime'] as Map)
                : <String, dynamic>{};
            final lastStorage = last['storage'] is Map
                ? Map<String, dynamic>.from(last['storage'] as Map)
                : <String, dynamic>{};
            final files = lastStorage['files'] ?? last['files'];
            final result = _text(last['result'] ?? lastRuntime['state'], fallback: '-');
            return Wrap(spacing: 8, runSpacing: 8, children: [
              _metricTile(context, 'Ergebnis', result, warning: result == 'error'),
              _metricTile(context, 'Beendigungsgrund', _text(lastRuntime['stop_reason'] ?? last['stop_reason'], fallback: '-')),
              _metricTile(context, 'Dauer', '${_fmt(lastRuntime['duration_s'] ?? last['duration_s'])} s'),
              _metricTile(context, 'Dateien', files is List ? files.length.toString() : '0'),
            ]);
          }),
        if (settingsController.expertModeEnabled.value) ...[
          const SizedBox(height: 14),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Expertendetails und Rohdaten'),
            children: [
              SelectableText('Tatsächlicher Skriptpfad: ${lc.scriptPath.isEmpty ? '-' : lc.scriptPath}\nSeverity: ${lc.severity.isEmpty ? '-' : lc.severity}\n\nStatus:\n${lc.rawStatusJson}\n\nLetzte Session:\n${lc.rawLastJson}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _buildLoggingSettingsEditor(BuildContext context) {
    final theme = Theme.of(context);
    final supported = controller.hasCoreLoggingSettings;
    final settingsBusy = controller.waitingForResponse.value;
    final triggerKey = GpsStateController.loggingSettingKeys[0];
    final modeKey = GpsStateController.loggingSettingKeys[1];
    final areaKey = GpsStateController.loggingSettingKeys[2];

    final triggerOptions = controller.optionsFor(
      triggerKey,
      fallback: GpsStateController.loggingTriggerFallbackOptions,
    );
    final modeOptions = controller.optionsFor(
      modeKey,
      fallback: GpsStateController.loggingModeFallbackOptions,
    );
    final selectedTrigger = _optionValue(
      controller.settingValue(triggerKey),
      triggerOptions,
      fallback: 'ad_hoc',
    );
    final selectedMode = _optionValue(
      controller.settingValue(modeKey),
      modeOptions,
      fallback: 'until_docking',
    );
    final showArea = selectedTrigger == 'area_id';

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      initiallyExpanded: controller.hasLoggingDrafts,
      leading: Icon(
        Icons.tune,
        color: supported ? theme.primaryColor : theme.disabledColor,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('Logging-Einstellungen')),
          if (controller.loggingDirtyCount > 0)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${controller.loggingDirtyCount} Entwurf${controller.loggingDirtyCount == 1 ? '' : 'e'}'),
            ),
        ],
      ),
      subtitle: Text(
        supported
            ? 'Wie bei Software und Hardware: lokal ändern, für die Session anwenden oder dauerhaft speichern.'
            : 'Das Backend liefert die erforderlichen Logging-Felder noch nicht vollständig über gps_state/settings/json.',
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (supported ? theme.primaryColor : Colors.orange).withValues(alpha: 0.07),
            border: Border.all(
              color: (supported ? theme.primaryColor : Colors.orange).withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            supported
                ? '„Jetzt anwenden“ ändert die aktiven Vorgaben bis zum Neustart. „Dauerhaft speichern“ übernimmt sie als persistenten Standard. Eine bereits laufende oder vorgemerkte Aufzeichnung behält ihren beim Start übernommenen Trigger und Modus.'
                : 'Bis das Backend logging_default_trigger, logging_default_mode und logging_default_area_id bereitstellt, bleibt die Starttaste abwärtskompatibel und sendet ad_hoc / until_docking direkt im Startbefehl.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final triggerField = _loggingDropdownField(
              context,
              keyName: triggerKey,
              value: selectedTrigger,
              options: triggerOptions,
              enabled: supported && !settingsBusy,
              labelForOption: _loggingTriggerLabel,
            );
            final modeField = _loggingDropdownField(
              context,
              keyName: modeKey,
              value: selectedMode,
              options: modeOptions,
              enabled: supported && !settingsBusy,
              labelForOption: _loggingModeLabel,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  triggerField,
                  const SizedBox(height: 12),
                  modeField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: triggerField),
                const SizedBox(width: 12),
                Expanded(child: modeField),
              ],
            );
          },
        ),
        if (showArea) ...[
          const SizedBox(height: 12),
          _loggingAreaField(
            context,
            keyName: areaKey,
            enabled: supported && !settingsBusy,
          ),
        ],
        if (controller.hasLegacyLoggingScriptPath) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(6),
              color: theme.colorScheme.error.withValues(alpha: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Migration des Skriptpfads erforderlich',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aktiv oder gespeichert ist noch ${GpsStateController.legacyLoggingScriptPath}. Die automatische Vorbereitung ändert ausschließlich logging_script_path; Ziel- und RAM-Pfad bleiben unverändert.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: settingsBusy || !controller.hasSetting('logging_script_path')
                      ? null
                      : controller.prepareLoggingScriptPathMigration,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Neuen Skriptpfad vorbereiten'),
                ),
              ],
            ),
          ),
        ],
        if (settingsController.expertModeEnabled.value) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Experteneinstellungen'),
            subtitle: const Text('Pfade und optionale Containerzuordnung werden vollständig aus den Backend-Metadaten geladen.'),
            children: [
              for (final keyName in GpsStateController.loggingSettingKeys.skip(3)) ...[
                _loggingTextField(
                  context,
                  keyName: keyName,
                  enabled: controller.hasSetting(keyName) && !settingsBusy,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ],
        if ((loggingController.running || loggingController.armed || loggingController.requestActive) &&
            controller.hasLoggingDrafts) ...[
          const SizedBox(height: 10),
          _messageBox(
            context,
            'Gültigkeit',
            'Die Entwürfe gelten erst nach dem Anwenden und nur für eine neue Aufzeichnung. Die aktuelle Anforderung wird nicht nachträglich verändert.',
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: controller.hasLoggingDrafts && !settingsBusy
                  ? controller.resetLoggingDrafts
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text('Zurücksetzen'),
            ),
            ElevatedButton.icon(
              onPressed: supported && controller.hasLoggingDrafts && !settingsBusy
                  ? controller.applyLoggingSession
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jetzt anwenden'),
            ),
            ElevatedButton.icon(
              onPressed: supported && controller.hasLoggingDrafts && !settingsBusy
                  ? controller.applyLoggingPersistent
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Dauerhaft speichern'),
            ),
            OutlinedButton.icon(
              onPressed: settingsBusy ? null : controller.requestSettings,
              icon: settingsBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: const Text('Einstellungen neu laden'),
            ),
          ],
        ),
        if (controller.lastStatus.value.isNotEmpty &&
            (controller.lastTopic.value.startsWith('gps_state/settings/') ||
                controller.lastTopic.value.startsWith('local/'))) ...[
          const SizedBox(height: 10),
          Text(
            controller.lastStatus.value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: controller.lastStatusOk.value == false
                  ? theme.colorScheme.error
                  : theme.hintColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _loggingDropdownField(
    BuildContext context, {
    required String keyName,
    required String value,
    required List<String> options,
    required bool enabled,
    required String Function(String) labelForOption,
  }) {
    final theme = Theme.of(context);
    final description = controller.descriptionFor(keyName);
    final effectiveOptions = <String>[
      ...options,
      if (value.isNotEmpty && !options.contains(value)) value,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          controller.labelFor(keyName),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('${keyName}_${controller.editorRevision.value}'),
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: effectiveOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(labelForOption(option)),
                ),
              )
              .toList(growable: false),
          onChanged: enabled
              ? (newValue) {
                  if (newValue != null) controller.setDraftValue(keyName, newValue);
                }
              : null,
        ),
        const SizedBox(height: 6),
        _loggingSettingValues(context, keyName, labelForOption),
      ],
    );
  }

  Widget _loggingAreaField(
    BuildContext context, {
    required String keyName,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final value = _text(controller.settingValue(keyName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          controller.labelFor(keyName),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          controller.descriptionFor(keyName),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('${keyName}_${controller.editorRevision.value}'),
          initialValue: value,
          enabled: enabled,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            hintText: 'z. B. 3 oder mow_area_03',
          ),
          onChanged: (newValue) => controller.setDraftValue(
            keyName,
            newValue.trim().isEmpty ? null : newValue.trim(),
          ),
        ),
        const SizedBox(height: 6),
        _loggingSettingValues(context, keyName, (raw) => raw.isEmpty ? '-' : raw),
      ],
    );
  }

  Widget _loggingTextField(
    BuildContext context, {
    required String keyName,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final value = _text(controller.settingValue(keyName));
    return KeyedSubtree(
      key: ValueKey('logging_field_$keyName'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Text(
          controller.labelFor(keyName),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (controller.descriptionFor(keyName).isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            controller.descriptionFor(keyName),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('${keyName}_${controller.editorRevision.value}'),
          initialValue: value,
          enabled: enabled,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (newValue) => controller.setDraftValue(
            keyName,
            newValue.trim().isEmpty ? '' : newValue.trim(),
          ),
        ),
        if (keyName == 'logging_script_path' && controller.hasLegacyLoggingScriptPath) ...[
          const SizedBox(height: 6),
          Text(
            'Neuer Backend-Standard: ${GpsStateController.canonicalLoggingScriptPath}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 6),
        _loggingSettingValues(context, keyName, (raw) => raw.isEmpty ? '-' : raw),
        ],
      ),
    );
  }

  Widget _loggingSettingValues(
    BuildContext context,
    String keyName,
    String Function(String) labelForValue,
  ) {
    final active = _settingText(controller.confirmedSettingValue(keyName));
    final persistent = _settingText(controller.persistentSettingValue(keyName));
    final defaultValue = _settingText(controller.defaultSettingValue(keyName));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _compactStatusChip(context, 'Aktiv', labelForValue(active)),
        _compactStatusChip(context, 'Gespeichert', labelForValue(persistent)),
        if (defaultValue != '-')
          _compactStatusChip(context, 'Standard', labelForValue(defaultValue)),
      ],
    );
  }

  String _optionValue(dynamic raw, List<String> options, {required String fallback}) {
    final value = raw?.toString() ?? '';
    if (value.isNotEmpty) return value;
    return options.contains(fallback)
        ? fallback
        : (options.isNotEmpty ? options.first : fallback);
  }

  String _settingText(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  String _loggingTriggerLabel(String value) {
    switch (value) {
      case 'ad_hoc':
        return 'Sofort';
      case 'next_cycle':
        return 'Nächster Mähzyklus';
      case 'area_id':
        return 'Bestimmte Fläche';
      case '-':
        return '-';
      default:
        return value;
    }
  }

  String _loggingModeLabel(String value) {
    switch (value) {
      case 'manual':
        return 'Manuell stoppen';
      case 'until_docking':
        return 'Bis zum Andocken';
      case 'from_start_to_docking':
        return 'Arbeitsstart bis Andocken';
      case 'from_docking_to_docking':
        return 'Docking bis Docking';
      case '-':
        return '-';
      default:
        return value;
    }
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
    final color = theme.primaryColor;
    final jsonText = controller.exportJsonString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        return Card(
          margin: EdgeInsets.zero,
          child: Container(
            color: color.withValues(alpha: 0.08),
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
                                Text(
                                  'JSON-Ansicht',
                                  style: theme.textTheme.titleLarge?.copyWith(color: color),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GPS-State-Daten anzeigen und herunterladen',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (!isMobile) _gpsJsonDownloadButton(context, isMobile: false),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: _rawJsonExpanded ? 'JSON-Ansicht einklappen' : 'JSON-Ansicht ausklappen',
                            onPressed: () => setState(() => _rawJsonExpanded = !_rawJsonExpanded),
                            icon: Icon(
                              _rawJsonExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 12),
                        _gpsJsonDownloadButton(context, isMobile: true),
                      ],
                    ],
                  ),
                ),
                if (_rawJsonExpanded)
                  Container(
                    width: double.infinity,
                    color: theme.cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, contentConstraints) {
                            final compactContent = contentConstraints.maxWidth < 620;
                            final description = Text(
                              'Der Download enthält alle aktuell in der App vorhandenen GPS-State-Daten: Settings, Definitionen und Status von State1 bis State4, MQTT-Topics, Empfangszeiten, Validierungen, Neustartstatus und noch nicht gespeicherte Einstellungsentwürfe. Er löst keine neue MQTT-Aktualisierung aus.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            );
                            final copyButton = TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: jsonText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('GPS-Diagnose-JSON wurde kopiert.')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Kopieren'),
                            );
                            if (compactContent) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  description,
                                  const SizedBox(height: 8),
                                  Align(alignment: Alignment.centerRight, child: copyButton),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: description),
                                const SizedBox(width: 8),
                                copyButton,
                              ],
                            );
                          },
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
          ),
        );
      },
    );
  }

  Widget _gpsJsonDownloadButton(BuildContext context, {required bool isMobile}) {
    // Keep placement, outline style, icon and wording aligned with the JSON
    // download action on the areas page so both screens use the same pattern.
    return SizedBox(
      width: isMobile ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: _snapshotDownloadInProgress ? null : () => _downloadGpsSnapshot(context),
        icon: _snapshotDownloadInProgress
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download),
        label: Text(isMobile ? 'Herunterladen' : 'Download'),
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
      // Request all visible and normally hidden diagnostic data first. Hidden
      // detail states are activated only in the background for this snapshot.
      final snapshot = await controller.collectCompleteSnapshot();
      final jsonText = const JsonEncoder.withIndent('  ').convert(snapshot);
      await saveTextFile(
        fileName: fileName,
        content: jsonText,
        mimeType: 'application/json',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snapshot['snapshot']?['complete'] == true
              ? 'Vollständiger GPS-State-Snapshot wurde als $fileName bereitgestellt.'
              : 'GPS-State-Snapshot mit fehlenden oder veralteten Daten wurde als $fileName bereitgestellt.'),
        ),
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
    Color? iconColor,
    Widget? trailing,
    ValueChanged<bool>? onExpansionChanged,
  }) {
    final theme = Theme.of(context);
    final color = iconColor ?? (active ? Colors.green.shade700 : theme.primaryColor);
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

  Widget _satelliteTable(
    BuildContext context,
    List<Map<String, dynamic>> satellites, {
    required bool showUsed,
    required double viewportHeight,
  }) {
    final sortedSatellites = List<Map<String, dynamic>>.from(satellites)
      ..sort((left, right) {
        final leftSystem = _satText(
          left,
          const ['gnss', 'system', 'constellation'],
        );
        final rightSystem = _satText(
          right,
          const ['gnss', 'system', 'constellation'],
        );
        final systemComparison = leftSystem.compareTo(rightSystem);
        if (systemComparison != 0) {
          return systemComparison;
        }

        final leftSv = _satDouble(
              left,
              const ['sv', 'svid', 'id', 'satellite_id', 'prn'],
            ) ??
            0;
        final rightSv = _satDouble(
              right,
              const ['sv', 'svid', 'id', 'satellite_id', 'prn'],
            ) ??
            0;
        return leftSv.compareTo(rightSv);
      });

    return SizedBox(
      height: viewportHeight,
      child: satellites.isEmpty
          ? Center(
              child: Text(
                'Keine Satellitenliste empfangen.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 34,
                    dataRowMaxHeight: 42,
                    columns: [
                      const DataColumn(label: Text('System')),
                      const DataColumn(label: Text('GNSS-ID'), numeric: true),
                      const DataColumn(label: Text('SV'), numeric: true),
                      const DataColumn(
                        label: Text('C/N0 (dB-Hz)'),
                        numeric: true,
                      ),
                      const DataColumn(
                        label: Text('Elevation (°)'),
                        numeric: true,
                      ),
                      const DataColumn(
                        label: Text('Azimuth (°)'),
                        numeric: true,
                      ),
                      const DataColumn(label: Text('PRRes'), numeric: true),
                      const DataColumn(label: Text('Qual'), numeric: true),
                      if (showUsed) const DataColumn(label: Text('Used')),
                    ],
                    rows: sortedSatellites.map((satellite) {
                      return DataRow(
                        cells: [
                          DataCell(Text(_satText(
                            satellite,
                            const ['gnss', 'system', 'constellation'],
                          ))),
                          DataCell(Text(_fmt(_satDouble(
                            satellite,
                            const ['gnss_id', 'gnssId'],
                          )))),
                          DataCell(Text(_satText(
                            satellite,
                            const [
                              'sv',
                              'svid',
                              'id',
                              'satellite_id',
                              'prn',
                            ],
                          ))),
                          DataCell(Text(_fmt(_satDouble(
                            satellite,
                            const ['cn0', 'cno', 'c_n0'],
                          )))),
                          DataCell(Text(_fmt(_satDouble(
                            satellite,
                            const ['elev', 'elevation'],
                          )))),
                          DataCell(Text(_fmt(_satDouble(
                            satellite,
                            const ['azim', 'azimuth', 'az'],
                          )))),
                          DataCell(Text(_fmt(_satDouble(
                            satellite,
                            const ['prres', 'pr_res'],
                          )))),
                          DataCell(Text(_fmt(_satDouble(
                            satellite,
                            const ['qual', 'quality'],
                          )))),
                          if (showUsed)
                            DataCell(_usedIcon(_satBool(
                              satellite,
                              const ['used', 'in_fix', 'fix_used'],
                            ))),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
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
        constraints: const BoxConstraints(minWidth: 930),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 36),
              SizedBox(width: 42, child: Text('Nr.', style: style)),
              SizedBox(width: 350, child: Text('Entscheidungsknoten', style: style)),
              SizedBox(width: 205, child: Text('Aktueller Wert', style: style)),
              SizedBox(width: 175, child: Text('Bedingung', style: style)),
              SizedBox(width: 72, child: Text('Ergebnis', style: style, textAlign: TextAlign.center)),
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
    final firstBlockingIndex = rows.indexWhere((row) => row.isBlocking);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(rows.length, (index) {
        final row = rows[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _state0DecisionRow(
            context,
            row,
            isFirst: index == 0,
            isLast: index == rows.length - 1,
            beforeOrAtFirstBlocker: firstBlockingIndex < 0 || index <= firstBlockingIndex,
            snapshotCurrent: snapshotCurrent,
            waiting: waiting,
          ),
        );
      }),
    );
  }

  Widget _state0DecisionRow(
    BuildContext context,
    _DecisionRow row, {
    required bool isFirst,
    required bool isLast,
    required bool beforeOrAtFirstBlocker,
    required bool snapshotCurrent,
    required bool waiting,
  }) {
    final theme = Theme.of(context);
    // Einzelmerkmale bleiben auswertbar, auch wenn ein früherer Knoten bereits
    // blockiert. Snapshot-Aktualität wird separat über die Statuszeile gezeigt.
    final effectiveState = _decisionConditionState(row);
    final color = row.isInfo ? Colors.blue.shade700 : _decisionStateColor(effectiveState);
    final stateLabel = row.isInfo
        ? 'Information'
        : waiting
        ? 'Aktualisierung läuft'
        : snapshotCurrent
            ? _decisionStateLabel(effectiveState)
            : '${_decisionStateLabel(effectiveState)} (Snapshot nicht aktuell)';

    final line = Container(
      constraints: const BoxConstraints(minWidth: 930, minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: row.isInfo ? 0.055 : row.isBlocking ? 0.065 : 0.025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isFirst)
                  Positioned(
                    top: 0,
                    bottom: 17,
                    child: Container(
                      width: 2,
                      color: beforeOrAtFirstBlocker
                          ? Colors.red.shade400
                          : theme.dividerColor,
                    ),
                  ),
                if (!isLast)
                  Positioned(
                    top: 17,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: row.isBlocking || !beforeOrAtFirstBlocker
                          ? theme.dividerColor
                          : Colors.red.shade400,
                    ),
                  ),
                if (row.isInfo)
                  Icon(Icons.info_outline, size: 21, color: color)
                else
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.cardColor,
                      border: Border.all(color: color, width: 3),
                    ),
                  ),
                if (row.isBlocking)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Tooltip(
                      message: 'Erster Blockierer',
                      child: Icon(Icons.flag, size: 15, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              row.number,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          SizedBox(
            width: 350,
            child: Tooltip(
              message: row.description.isEmpty ? row.label : '${row.label}\n${row.description}',
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: row.isInfo ? color : null,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 205,
            child: Text(
              row.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 175,
            child: Text(
              row.threshold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 72,
            child: Center(
              child: Tooltip(
                message: stateLabel,
                child: Icon(
                  row.isInfo ? Icons.info_outline : _decisionStateIcon(effectiveState),
                  size: 22,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: line);
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
      final decisionRows = orderedKeys.map<_DecisionRow>((key) {
        final row = _buildState0DecisionRowData(
          key,
          definitionChecks[key],
          statusChecks[key],
          index,
          rootStatus: rootStatus,
          blockingStage: blockingStage,
          blockingKey: blockingKey,
        );
        index++;
        return row;
      }).toList(growable: true);

      final nestedData = rootStatus['data'] is Map
          ? Map<String, dynamic>.from(rootStatus['data'] as Map)
          : const <String, dynamic>{};
      final currentStatus = _text(
        rootStatus['current_status'] ??
            rootStatus['mowing_status'] ??
            nestedData['current_status'] ??
            nestedData['mowing_status'],
        fallback: '-',
      );
      decisionRows.insert(
        0,
        _DecisionRow(
          number: '0',
          label: 'Current Status',
          description: 'Aktueller Betriebsstatus des Mähers. Dieser Eintrag ist rein informativ und beeinflusst die Fahrfreigabe nicht.',
          value: currentStatus,
          threshold: '-',
          status: 'Info',
          ok: null,
          key: 'current_status',
          isInfo: true,
        ),
      );

      final quality = _text(rootStatus['quality_class'] ?? nestedData['quality_class'], fallback: '-');
      final stageOneIndex = decisionRows.indexWhere((row) => row.number == '1');
      decisionRows.insert(
        stageOneIndex >= 0 ? stageOneIndex + 1 : 1,
        _DecisionRow(
          number: '',
          label: 'GPS Quality',
          description: 'Zusammengefasste GPS-Qualitätsklasse. Dieser Eintrag ist rein informativ und kein Entscheidungsknoten.',
          value: quality,
          threshold: '-',
          status: 'Info',
          ok: null,
          key: 'quality_class',
          isInfo: true,
        ),
      );
      return decisionRows;
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
    required Map<String, dynamic> rootStatus,
    dynamic blockingStage,
    String blockingKey = '',
  }) {
    final stage = _text(status?['stage'] ?? definition?['stage'], fallback: fallbackIndex.toString());
    final label = _text(
      definition?['title'] ?? status?['title'] ?? definition?['name'] ?? status?['name'],
      fallback: checkId,
    );
    final description = _text(definition?['description'] ?? status?['description']);
    final source = _text(definition?['source'] ?? status?['source'], fallback: _text(status?['key'] ?? definition?['key'], fallback: checkId));
    final key = _text(status?['key'] ?? definition?['key'], fallback: checkId);
    final isDriveReadyRow = stage == '12' || key == 'gps_drive_ready' || checkId == '12_gps_drive_ready';
    final rootReady = _boolNullable(rootStatus['drive_ready'] ?? rootStatus['gps_drive_ready']);
    final rootDriveState = _text(rootStatus['drive_state'] ?? rootStatus['gps_drive_state']);
    final value = isDriveReadyRow
        ? (rootReady == true
            ? (rootDriveState.isEmpty ? 'fahrbereit' : rootDriveState)
            : rootReady == false
                ? (rootDriveState.isEmpty ? 'blockiert' : rootDriveState)
                : 'nicht eindeutig')
        : _state0ValueText(status, definition);
    final threshold = _state0ThresholdText(status, definition);
    final statusText = isDriveReadyRow
        ? (rootReady == true ? 'ok' : rootReady == false ? 'blocked' : 'unknown')
        : _text(status?['status'] ?? status?['result'] ?? status?['state'], fallback: definition == null ? 'Definition fehlt' : 'Status fehlt');

    return _DecisionRow(
      number: stage,
      label: label,
      description: description,
      value: value,
      threshold: threshold,
      status: statusText,
      ok: isDriveReadyRow ? rootReady : _state0StatusOk(status),
      source: source,
      key: key,
      severity: isDriveReadyRow ? _int(rootStatus['severity']) : _int(status?['severity']),
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
    if (status == null) return '-';
    if (!status.containsKey('value')) return '-';
    final value = status['value'];
    final unit = _text(definition?['unit'] ?? status['unit']).toLowerCase();
    if (value is num && unit == 'm' && value.abs() < 1) {
      return '${(value.toDouble() * 100).toStringAsFixed(1).replaceAll('.', ',')} cm';
    }
    if (value is num && unit == 's') {
      return '${value.toDouble().toStringAsFixed(2).replaceAll('.', ',')} s';
    }
    if (value is num && unit == 'samples') {
      return '${_formatValue(value)} Samples';
    }
    if (value is bool) {
      final key = _text(status['key'] ?? definition?['key']).toLowerCase();
      if (key.contains('enabled')) return value ? 'aktiv' : 'inaktiv';
      if (key.contains('received')) return value ? 'empfangen' : 'nicht empfangen';
      if (key.contains('valid')) return value ? 'gültig' : 'ungültig';
      return value ? 'Ja' : 'Nein';
    }
    if (_text(status['display']).toLowerCase() == 'nicht erforderlich') return 'nicht erforderlich';
    return _formatValue(value);
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

  String _restartModeLabel(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'hot_start':
        return 'Hot Start';
      case 'warm_start':
        return 'Warm Start';
      case 'cold_start':
        return 'Cold Start';
    }
    return mode;
  }

  String _restartStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'sent':
      case 'requested':
      case 'accepted':
        return 'Neustart wurde angefordert';
      case 'resetting':
        return 'Reset wird ausgeführt';
      case 'waiting_for_receiver':
        return 'Warten auf den GPS-Empfänger';
      case 'validating':
        return 'Empfängerausgaben werden geprüft';
      case 'success':
      case 'ok':
        return 'F9P-Neustart erfolgreich bestätigt';
      case 'failed':
      case 'error':
      case 'send_failed':
        return 'F9P-Neustart fehlgeschlagen';
      case 'rejected':
        return 'F9P-Neustartbefehl abgelehnt';
      case 'idle':
      case '':
        return 'Kein Neustart aktiv';
    }
    return status;
  }

  Color _restartStatusColor(String status, ThemeData theme) {
    switch (status.trim().toLowerCase()) {
      case 'success':
      case 'ok':
        return Colors.green.shade700;
      case 'failed':
      case 'error':
      case 'send_failed':
      case 'rejected':
        return Colors.red.shade700;
      case 'resetting':
      case 'waiting_for_receiver':
        return Colors.orange.shade800;
      case 'validating':
        return Colors.blue.shade700;
      case 'sent':
      case 'requested':
      case 'accepted':
        return Colors.blueGrey.shade700;
    }
    return theme.hintColor;
  }

  IconData _restartStatusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'success':
      case 'ok':
        return Icons.check_circle_outline;
      case 'failed':
      case 'error':
      case 'send_failed':
      case 'rejected':
        return Icons.error_outline;
      case 'resetting':
        return Icons.restart_alt;
      case 'waiting_for_receiver':
        return Icons.hourglass_top;
      case 'validating':
        return Icons.fact_check_outlined;
    }
    return Icons.info_outline;
  }

  String _restartReasonLabel(String reason) {
    switch (reason.trim().toLowerCase()) {
      case 'receiver_outputs_restored':
        return 'Empfängerausgaben wurden erfolgreich wiederhergestellt.';
      case 'nav_pvt_not_received_after_reset':
        return 'Nach dem Reset wurden keine neuen Positionsdaten (NAV-PVT) empfangen.';
      case 'nav_sat_not_received_after_reset':
        return 'Nach dem Reset wurden keine neuen Satellitendaten (NAV-SAT) empfangen.';
      case 'restart_command_rejected':
        return 'Der Neustartbefehl wurde vom Backend abgelehnt.';
      case 'restart_command_send_failed':
        return 'Der Neustartbefehl konnte nicht an den Empfänger gesendet werden.';
    }
    return reason;
  }

  bool _statePayloadIsStale(Map<String, dynamic> state) {
    if (state.isEmpty) return false;
    final status = _text(state['status']).trim().toLowerCase();
    final explicitlyUnavailable = state.containsKey('available') && _boolNullable(state['available']) == false;
    return _boolNullable(state['stale']) == true || status == 'stale' || explicitlyUnavailable;
  }

  Widget _staleDataNotice(BuildContext context, Map<String, dynamic> state, {required String stateName}) {
    final age = _millisecondsText(state['age_ms']);
    final severity = state['severity'];
    final details = <String>[
      'Die angezeigten Werte stammen aus einem älteren Stand und werden nicht als aktuelle Freigabe oder Qualitätsaussage gewertet.',
      if (age != '-') 'Quelldaten-Alter: $age.',
      if (severity != null) 'Severity: ${_fmt(severity)}.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$stateName: Daten nach GPS-Neustart noch nicht aktualisiert', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.orange.shade900)),
                const SizedBox(height: 3),
                Text(details.join(' '), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _restartDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final numeric = value is num ? value.toDouble() : double.tryParse(value.toString().trim());
    if (numeric != null) {
      final milliseconds = numeric.abs() >= 100000000000
          ? numeric.round()
          : (numeric * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _restartTimestampText(dynamic value) {
    final date = _restartDateTime(value);
    if (date == null) return '-';
    return '${_twoDigits(date.day)}.${_twoDigits(date.month)}.${date.year}, ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}:${_twoDigits(date.second)}';
  }

  String _restartDurationText(Map<String, dynamic> payload, {bool includeRunning = false}) {
    final requested = _restartDateTime(payload['requested_at']);
    final completed = _restartDateTime(payload['completed_at']);
    if (requested == null) return '-';
    final end = completed ?? (includeRunning ? DateTime.now() : null);
    if (end == null || end.isBefore(requested)) return '-';
    final milliseconds = end.difference(requested).inMilliseconds;
    if (milliseconds < 1000) return '$milliseconds ms';
    return '${(milliseconds / 1000).toStringAsFixed(1)} s';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
    this.isInfo = false,
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
  final bool isInfo;
}
