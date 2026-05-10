import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final data = controller.timetableData;
          final timetable = Map<String, dynamic>.from((data['timetable'] as Map?) ?? <String, dynamic>{});
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(
                  context,
                  icon: Icons.schedule,
                  title: 'Zeiteinstellungen',
                  subtitle: 'Zeitstatus, Time-Server-Aktionen und Zeitquellen-Konfiguration',
                  child: _buildTimeActionsCard(context),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.calendar_month,
                  title: 'Mähzeiten',
                  subtitle: 'Zeit-Einträge anzeigen, ändern und ergänzen',
                  child: _buildEntriesSection(context, timetable),
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

  Widget _buildTimetableActions(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: controller.requestTimetable,
            icon: const Icon(Icons.download),
            label: const Text('Timetable'),
          ),
          ElevatedButton.icon(
            onPressed: controller.requestTimeStatus,
            icon: const Icon(Icons.access_time),
            label: const Text('Zeitstatus'),
          ),
          ElevatedButton.icon(
            onPressed: controller.hasData ? controller.sendTimetable : null,
            icon: const Icon(Icons.upload),
            label: const Text('Senden'),
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
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.only(top: 16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeActionsCard(BuildContext context) {
    final source = controller.selectedTimeSource.value;
    final isManual = source == 'manual';
    final isNtp = source == 'ntp';
    final isGps = source == 'gps';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time-Server-Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Die Actions werden an /openmower/time/action/json gesendet. Antworten werden über /openmower/time/action_result/json oder /bson ausgewertet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SizedBox(width: 220, child: Text('Zeitzone')),
            SizedBox(
              width: 420,
              child: TextFormField(
                controller: controller.timezoneController,
                decoration: const InputDecoration(hintText: 'Europe/Berlin'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: controller.sendTimezone,
              icon: const Icon(Icons.public),
              label: const Text('Zeitzone setzen'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSourceRow(
          context,
          selected: isManual,
          selectable: true,
          label: 'manuelle Zeit',
          onTap: () => controller.setSelectedTimeSource('manual'),
          children: [
            SizedBox(
              width: 170,
              child: TextFormField(
                enabled: isManual,
                controller: controller.hourController,
                decoration: const InputDecoration(labelText: 'Stunden'),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 170,
              child: TextFormField(
                enabled: isManual,
                controller: controller.minuteController,
                decoration: const InputDecoration(labelText: 'Minuten'),
                keyboardType: TextInputType.number,
              ),
            ),
            ElevatedButton.icon(
              onPressed: isManual ? controller.sendManualTime : null,
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Manuelle Zeit setzen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSourceRow(
          context,
          selected: isNtp,
          selectable: true,
          label: 'ntp Zeit',
          onTap: () => controller.setSelectedTimeSource('ntp'),
          children: [
            SizedBox(
              width: 360,
              child: TextFormField(
                enabled: isNtp,
                controller: controller.ntpServerController,
                decoration: const InputDecoration(labelText: 'NTP Server', hintText: 'pool.ntp.org'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isNtp ? controller.sendNtpServer : null,
              icon: const Icon(Icons.dns),
              label: const Text('NTP Server setzen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSourceRow(
          context,
          selected: isGps,
          selectable: true,
          label: 'gps Zeit',
          onTap: () => controller.setSelectedTimeSource('gps'),
          children: [
            SizedBox(
              width: 360,
              child: Text('keine zusätzlichen Eingaben', style: Theme.of(context).textTheme.bodyMedium),
            ),
            ElevatedButton.icon(
              onPressed: isGps ? controller.synchronizeGps : null,
              icon: const Icon(Icons.sync),
              label: const Text('Synchronisieren'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSourceRow(
          context,
          selected: false,
          selectable: false,
          label: 'Systemzeit',
          children: [
            SizedBox(
              width: 360,
              child: Text('Aktuelle Uhrzeit: ${_currentTimeText()}', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceRow(
    BuildContext context, {
    required bool selected,
    required bool selectable,
    required String label,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    final color = Theme.of(context).primaryColor;
    final labelBox = Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
        color: selectable ? Colors.white : Colors.grey.shade100,
      ),
      child: Text(label, style: TextStyle(color: selected ? color : null)),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: selected ? Icon(Icons.check, color: color, size: 22) : const SizedBox.shrink(),
        ),
        labelBox,
        const SizedBox(width: 16),
        Flexible(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ),
      ],
    );

    if (!selectable) {
      return row;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }

  Widget _buildEntriesSection(BuildContext context, Map<String, dynamic> timetable) {
    final entries = timetable.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Jede Zeile entspricht einem Objekt unter timetable.*. Unten ist ein neuer Eintrag vorbereitet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Noch keine Mähzeiten vorhanden.', style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          ...entries.map((entry) {
            final item = Map<String, dynamic>.from((entry.value as Map?) ?? <String, dynamic>{});
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEntryRow(context, entry.key, item),
            );
          }),
        Text('Neuer Eintrag', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildNewEntryRow(context),
      ],
    );
  }

  Widget _buildEntryRow(BuildContext context, String id, Map<String, dynamic> item) {
    final editing = controller.isEntryEditing(id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 230, child: _idField(id, editable: false)),
          _entryDayDropdown(id, item, enabled: editing),
          _smallTextField(id, item, 'start', 'Start', enabled: editing, width: 120),
          _smallTextField(id, item, 'end', 'Ende', enabled: editing, width: 120),
          _entryEndBehaviorDropdown(id, item, enabled: editing),
          _fieldsButton(context, id, item),
          _boolSwitch('Aktiv', item['enabled'] == true, editing ? (value) => controller.updateEntry(id, 'enabled', value) : null),
          _boolSwitch('Auto-Start', item['auto_start'] == true, editing ? (value) => controller.updateEntry(id, 'auto_start', value) : null),
          SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Eintrag löschen',
                  onPressed: () => controller.removeEntry(id),
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: editing ? 'Eintrag speichern' : 'Eintrag ändern',
                  onPressed: () => controller.toggleEditEntry(id),
                  icon: Icon(editing ? Icons.save_outlined : Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewEntryRow(BuildContext context) {
    final draft = controller.newEntryDraft;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 230,
            child: TextFormField(
              controller: controller.newEntryIdController,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: _safeValue((draft['day'] ?? 'Sunday').toString(), days),
              decoration: const InputDecoration(labelText: 'Tag'),
              items: days.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) controller.updateNewEntry('day', value);
              },
            ),
          ),
          _newEntryTextField('start', 'Start', width: 120),
          _newEntryTextField('end', 'Ende', width: 120),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _safeValue((draft['end_behavior'] ?? 'return_to_dock').toString(), endBehaviors),
              decoration: const InputDecoration(labelText: 'Verhalten bei Ende'),
              items: endBehaviors.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) controller.updateNewEntry('end_behavior', value);
              },
            ),
          ),
          OutlinedButton(
            onPressed: null,
            child: const Text('0 Felder'),
          ),
          _boolSwitch('Aktiv', draft['enabled'] == true, (value) => controller.updateNewEntry('enabled', value)),
          _boolSwitch('Auto-Start', draft['auto_start'] == true, (value) => controller.updateNewEntry('auto_start', value)),
          SizedBox(
            width: 56,
            child: IconButton(
              tooltip: 'Eintrag hinzufügen',
              onPressed: () => controller.addEntryFromDraft(),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idField(String id, {bool editable = false}) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'ID'),
      child: Text(id, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _entryDayDropdown(String id, Map<String, dynamic> item, {bool enabled = true}) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        value: _safeValue((item['day'] ?? 'Monday').toString(), days),
        decoration: const InputDecoration(labelText: 'Tag'),
        items: days.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: enabled
            ? (value) {
                if (value != null) controller.updateEntry(id, 'day', value);
              }
            : null,
      ),
    );
  }

  Widget _entryEndBehaviorDropdown(String id, Map<String, dynamic> item, {bool enabled = true}) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        value: _safeValue((item['end_behavior'] ?? 'return_to_dock').toString(), endBehaviors),
        decoration: const InputDecoration(labelText: 'Verhalten bei Ende'),
        items: endBehaviors.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: enabled
            ? (value) {
                if (value != null) controller.updateEntry(id, 'end_behavior', value);
              }
            : null,
      ),
    );
  }

  Widget _smallTextField(String id, Map<String, dynamic> item, String field, String label, {double width = 120, bool enabled = true}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('$id-$field-${item[field]}-$enabled'),
        initialValue: (item[field] ?? '').toString(),
        decoration: InputDecoration(labelText: label, hintText: 'HH:MM'),
        keyboardType: TextInputType.datetime,
        readOnly: !enabled,
        onChanged: enabled ? (value) => controller.updateEntry(id, field, value) : null,
      ),
    );
  }

  Widget _newEntryTextField(String field, String label, {double width = 120}) {
    final value = controller.newEntryDraft[field];
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('new-entry-$field-$value'),
        initialValue: (value ?? '').toString(),
        decoration: InputDecoration(labelText: label, hintText: 'HH:MM'),
        keyboardType: TextInputType.datetime,
        onChanged: (text) => controller.updateNewEntry(field, text),
      ),
    );
  }

  Widget _fieldsButton(BuildContext context, String id, Map<String, dynamic> item) {
    final count = controller.extraFieldsCount(item);
    return OutlinedButton(
      onPressed: () => _showExtraFieldsDialog(context, id, item),
      child: Text('$count Felder'),
    );
  }

  void _showExtraFieldsDialog(BuildContext context, String id, Map<String, dynamic> item) {
    final extra = controller.extraFieldsFor(item);
    final textController = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(extra));
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Felder für $id'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: textController,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Zusätzliche Felder als JSON',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                if (controller.updateExtraFieldsFromJson(id, textController.text)) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    ).whenComplete(textController.dispose);
  }

  Widget _boolSwitch(String label, bool value, ValueChanged<bool>? onChanged) {
    return SizedBox(
      width: 150,
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildJsonSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.code, color: color, size: 32),
        title: Text('JSON-Ansicht', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
        subtitle: const Text('Optionaler Bereich für weitere Felder'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Eingeklappt. Zum Anzeigen und Bearbeiten des JSON hier öffnen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.requestTimetable,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: controller.applyRawJson,
                icon: const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: controller.hasData ? controller.sendTimetable : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Speichern'),
              ),
            ],
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
        ],
      ),
    );
  }

  String _safeValue(String value, List<String> allowed) => allowed.contains(value) ? value : allowed.first;

  String _currentTimeText() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
