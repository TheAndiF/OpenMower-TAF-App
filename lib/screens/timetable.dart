import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';

class TimetableScreen extends GetView<TimetableController> {
  const TimetableScreen({super.key});

  static const days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const endBehaviors = <String>[
    'return_to_dock',
    'finish_current_run',
    'pause',
    'stop',
  ];

  static const batteryStates = <String>[
    'full',
    'sufficient',
  ];

  static const timeSources = <String>[
    'ntp',
    'gps',
    'manual',
    'system',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.timetableData;
      final timetable = Map<String, dynamic>.from((data['timetable'] as Map?) ?? <String, dynamic>{});
      final time = Map<String, dynamic>.from((data['time'] as Map?) ?? <String, dynamic>{});

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Timetable & Zeitservice',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.requestTimetable,
                  icon: const Icon(Icons.download),
                  label: const Text('Timetable'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: controller.requestTimeStatus,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Zeitstatus'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: controller.hasData ? controller.sendTimetable : null,
                  icon: const Icon(Icons.upload),
                  label: const Text('Senden'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatus(context),
            const SizedBox(height: 16),
            _buildTimeStateCard(context),
            const SizedBox(height: 16),
            if (controller.hasRobotState) ...[
              _buildRobotStateCard(context),
              const SizedBox(height: 16),
            ],
            _buildTimeActionsCard(context),
            const SizedBox(height: 16),
            if (!controller.hasData)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Noch keine Timetable-Daten empfangen. „Timetable“ fragt den Wochenplan per MQTT an; „Zeitstatus“ fragt den Time-Server an. Die Seite bleibt auch ohne MQTT-Daten bedienbar.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            else ...[
              _buildTimeCard(context, time),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Zeitfenster',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.addEntry,
                    icon: const Icon(Icons.add),
                    label: const Text('Eintrag hinzufügen'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...timetable.entries.map((entry) {
                final item = Map<String, dynamic>.from((entry.value as Map?) ?? <String, dynamic>{});
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildEntryCard(context, entry.key, item),
                );
              }).toList(),
              const SizedBox(height: 16),
              _buildRawJsonCard(context),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildStatus(BuildContext context) {
    final waiting = controller.waitingForResponse.value;
    final ok = controller.lastStatusOk.value;
    final message = controller.lastStatus.value;
    final remarks = controller.lastRemarks;
    final color = ok == null
        ? Colors.blueGrey
        : ok
            ? Colors.green
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(ok == false ? Icons.error_outline : Icons.info_outline, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.isEmpty ? 'Bereit' : message),
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(remarks.join('\n'), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (controller.lastUpdated.value != null)
              Text(
                'Update: ${controller.lastUpdated.value!.hour.toString().padLeft(2, '0')}:${controller.lastUpdated.value!.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStateCard(BuildContext context) {
    final state = controller.timeState;
    final valid = state['valid'] == true;
    final quality = (state['quality'] ?? 'unbekannt').toString();
    final source = (state['source'] ?? 'none').toString();
    final timezone = (state['timezone'] ?? '-').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(valid ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: valid ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('Aktueller Zeitstatus', style: Theme.of(context).textTheme.titleLarge)),
                OutlinedButton.icon(
                  onPressed: controller.requestTimeStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Aktualisieren'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!controller.hasTimeState)
              Text('Noch kein Zeitstatus empfangen.', style: Theme.of(context).textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip('valid', valid ? 'true' : 'false'),
                  _infoChip('source', source),
                  _infoChip('timezone', timezone),
                  _infoChip('quality', quality),
                  if (state['sync_age_seconds'] != null) _infoChip('sync age', '${state['sync_age_seconds']} s'),
                ],
              ),
            if (controller.hasTimeState) ...[
              const SizedBox(height: 12),
              _keyValue('UTC', state['utc_time']),
              _keyValue('Lokal', state['local_time']),
              _keyValue('Letzter Sync', state['last_sync_at']),
              _keyValue('Hinweise', state['remarks'] is List ? (state['remarks'] as List).join(', ') : state['remarks']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRobotStateCard(BuildContext context) {
    final state = controller.robotState;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timetable-Entscheidung / robot_state', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip('auto_mowing_time', '${state['auto_mowing_time']}'),
                _infoChip('active_window', '${state['active_window']}'),
                _infoChip('start_allowed', '${state['start_allowed']}'),
                _infoChip('mission_trigger_allowed', '${state['mission_trigger_allowed']}'),
                _infoChip('reason', '${state['reason'] ?? '-'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeActionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time-Server Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Die Actions werden an /openmower/time/action/json gesendet. Antworten werden über /openmower/time/action_result/json oder /bson ausgewertet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: controller.timezoneController,
                    decoration: const InputDecoration(labelText: 'Zeitzone', hintText: 'Europe/Berlin'),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.sendTimezone,
                  icon: const Icon(Icons.public),
                  label: const Text('Zeitzone setzen'),
                ),
                ElevatedButton.icon(
                  onPressed: () => controller.requestTimeResync(preferredSource: 'ntp'),
                  icon: const Icon(Icons.sync),
                  label: const Text('Resync NTP'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.clearManualTime,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Manual löschen'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextFormField(
                    controller: controller.manualLocalTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Manuelle lokale Zeit',
                      hintText: '2026-05-10T22:30:00+02:00',
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.sendManualTime,
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Manuelle Zeit setzen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context, Map<String, dynamic> time) {
    final allowedSources = List<String>.from((time['allowed_sources'] as List?)?.map((e) => e.toString()) ?? const <String>[]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('timetable.time / Zeitquellen-Konfiguration', style: Theme.of(context).textTheme.titleLarge)),
                OutlinedButton.icon(
                  onPressed: controller.hasData ? controller.sendTimeConfig : null,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Zeit-Konfig senden'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    key: ValueKey("timezone-${time['timezone']}"),
                    initialValue: (time['timezone'] ?? '').toString(),
                    decoration: const InputDecoration(labelText: 'Zeitzone'),
                    onChanged: (value) => controller.updateTopLevel('time', 'timezone', value),
                  ),
                ),
                _boolSwitch('Zeit erforderlich', time['required'] == true, (value) => controller.updateTopLevel('time', 'required', value)),
                _boolSwitch('Nur gültige Zeit', time['require_valid_time'] == true, (value) => controller.updateTopLevel('time', 'require_valid_time', value)),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _safeValue((time['fallback_source'] ?? 'system').toString(), timeSources),
                    decoration: const InputDecoration(labelText: 'Fallback-Zeitquelle'),
                    items: timeSources.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) controller.updateTopLevel('time', 'fallback_source', value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Erlaubte Zeitquellen', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: timeSources
                  .map((source) => FilterChip(
                        label: Text(source),
                        selected: allowedSources.contains(source),
                        onSelected: (selected) => controller.updateAllowedSource(source, selected),
                      ))
                  .toList(),
            ),
            if (controller.hasTimeConfigStatus) ...[
              const SizedBox(height: 12),
              Text('Bestätigte Konfiguration: ${controller.timeConfigStatus}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, String id, Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Eintrag $id', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Eintrag löschen',
                  onPressed: () => controller.removeEntry(id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _safeValue((item['day'] ?? 'Monday').toString(), days),
                    decoration: const InputDecoration(labelText: 'Tag'),
                    items: days.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) controller.updateEntry(id, 'day', value);
                    },
                  ),
                ),
                _smallTextField(id, item, 'start', 'Start', keyboardType: TextInputType.datetime),
                _smallTextField(id, item, 'end', 'Ende', keyboardType: TextInputType.datetime),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _safeValue((item['end_behavior'] ?? 'return_to_dock').toString(), endBehaviors),
                    decoration: const InputDecoration(labelText: 'Verhalten bei Ende'),
                    items: endBehaviors.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) controller.updateEntry(id, 'end_behavior', value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _safeValue((item['required_battery_state'] ?? 'full').toString(), batteryStates),
                    decoration: const InputDecoration(labelText: 'Akku'),
                    items: batteryStates.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) controller.updateEntry(id, 'required_battery_state', value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    key: ValueKey("$id-minimum_remaining_window_minutes-${item['minimum_remaining_window_minutes']}"),
                    initialValue: (item['minimum_remaining_window_minutes'] ?? 0).toString(),
                    decoration: const InputDecoration(labelText: 'Min. Restzeit'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => controller.updateEntry(id, 'minimum_remaining_window_minutes', int.tryParse(value) ?? 0),
                  ),
                ),
                _boolSwitch('Aktiv', item['enabled'] == true, (value) => controller.updateEntry(id, 'enabled', value)),
                _boolSwitch('Auto-Start', item['auto_start'] == true, (value) => controller.updateEntry(id, 'auto_start', value)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTextField(String id, Map<String, dynamic> item, String field, String label, {TextInputType? keyboardType}) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        key: ValueKey('$id-$field-${item[field]}'),
        initialValue: (item[field] ?? '').toString(),
        decoration: InputDecoration(labelText: label, hintText: 'HH:MM'),
        keyboardType: keyboardType,
        onChanged: (value) => controller.updateEntry(id, field, value),
      ),
    );
  }

  Widget _boolSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 170,
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildRawJsonCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('JSON-Ansicht', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Hier können Felder editiert werden, die oben noch nicht als Formular abgebildet sind. Gesendet wird der Timetable-Konfigurationsblock.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.rawJsonController,
              minLines: 8,
              maxLines: 20,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'timetable.json',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: controller.applyRawJson,
                icon: const Icon(Icons.check),
                label: const Text('JSON übernehmen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _keyValue(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value'),
    );
  }

  String _safeValue(String value, List<String> allowed) {
    return allowed.contains(value) ? value : allowed.first;
  }
}
