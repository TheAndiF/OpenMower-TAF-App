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
                    'Timetable',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.requestTimetable,
                  icon: const Icon(Icons.download),
                  label: const Text('Empfangen'),
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
            if (!controller.hasData)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Noch keine Daten empfangen. Über „Empfangen“ wird eine Anfrage per MQTT gesendet. Alternativ kann der Service die Timetable-Daten direkt publishen.',
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
    final color = ok == null
        ? Colors.blueGrey
        : ok
            ? Colors.green
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
            Expanded(child: Text(message.isEmpty ? 'Bereit' : message)),
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

  Widget _buildTimeCard(BuildContext context, Map<String, dynamic> time) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zeit-Einstellungen', style: Theme.of(context).textTheme.titleLarge),
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
                    value: _safeValue((time['fallback_source'] ?? 'system').toString(), const ['ntp', 'gps', 'manual', 'system']),
                    decoration: const InputDecoration(labelText: 'Fallback-Zeitquelle'),
                    items: const ['ntp', 'gps', 'manual', 'system'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) controller.updateTopLevel('time', 'fallback_source', value);
                    },
                  ),
                ),
              ],
            ),
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
              'Hier können Felder editiert werden, die oben noch nicht als Formular abgebildet sind.',
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

  String _safeValue(String value, List<String> allowed) {
    return allowed.contains(value) ? value : allowed.first;
  }
}
