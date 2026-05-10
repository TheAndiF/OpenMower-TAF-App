import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TimetableController controller = Get.find<TimetableController>();
  bool _renewSent = false;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestTimetable();
      }
    });
  }

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
                  title: 'Time Settings',
                  subtitle: 'Zeitzone und Quelle für die einmalige Systemzeit-Synchronisation',
                  child: _buildTimeSettingsCard(context),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.pause_circle_outline,
                  title: 'Mähzeit aussetzen',
                  subtitle: 'Direkte MQTT-Aussetzung; Bestätigung kommt über robot_state.AutoMowSuspension',
                  child: _buildSuspensionCard(context),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.calendar_month,
                  title: 'Mähzeiten',
                  subtitle: 'Zeit-Einträge anzeigen, ändern, löschen und ergänzen',
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

  Widget _buildTimeSettingsCard(BuildContext context) {
    final source = controller.selectedTimeSource.value;
    final isManual = source == 'manual';
    final isNtp = source == 'ntp';
    final isGps = source == 'gps';
    final isSystem = source == 'system';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Alle Änderungen werden lokal in timeSettings aktualisiert. Übertragen wird erst mit Speichern in der JSON-Ansicht.',
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
                onChanged: controller.updateTimezone,
              ),
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
                onChanged: (_) => controller.updateManualTimeFromFields(),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextFormField(
                enabled: isManual,
                controller: controller.minuteController,
                decoration: const InputDecoration(labelText: 'Minuten'),
                keyboardType: TextInputType.number,
                onChanged: (_) => controller.updateManualTimeFromFields(),
              ),
            ),
            Text('Wird als manual.datetime gespeichert.', style: Theme.of(context).textTheme.bodySmall),
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
                onChanged: controller.updateNtpServer,
              ),
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
          ],
        ),
        const SizedBox(height: 8),
        _buildSourceRow(
          context,
          selected: isSystem,
          selectable: true,
          label: 'Systemzeit',
          onTap: () => controller.setSelectedTimeSource('system'),
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

  Widget _buildSuspensionCard(BuildContext context) {
    final oneDayActive = controller.isSuspended && _suspensionLooksLikeDays(1);
    final threeDaysActive = controller.isSuspended && _suspensionLooksLikeDays(3);
    final suspensionValue = controller.autoMowSuspension;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AutoMow Suspension', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Die Buttons senden timetable/suspension/set/json. Der bestätigte Zustand wird aus robot_state.AutoMowSuspension gelesen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _toggleButton(
              context,
              active: oneDayActive,
              icon: Icons.looks_one,
              label: '1 Tag aussetzen',
              onPressed: () => controller.toggleSuspensionDays(1),
            ),
            _toggleButton(
              context,
              active: threeDaysActive,
              icon: Icons.looks_3,
              label: '3 Tage aussetzen',
              onPressed: () => controller.toggleSuspensionDays(3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          controller.isSuspended ? 'Aktuell ausgesetzt bis: $suspensionValue' : 'Aktuell keine Aussetzung aktiv.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _toggleButton(BuildContext context, {required bool active, required IconData icon, required String label, required VoidCallback onPressed}) {
    return active
        ? ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text('✓ $label'))
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
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
          'Die technische ID wird automatisch erzeugt, intern als Key unter timetable verwendet und nicht angezeigt.',
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
                  onPressed: () => _confirmRemoveEntry(context, id),
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

  void _confirmRemoveEntry(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mähzeit löschen?'),
        content: const Text('Der Timeslot wird lokal aus der JSON entfernt. Übertragen wird erst mit Speichern.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              controller.removeEntry(id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Löschen'),
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
          title: const Text('Zusätzliche Felder'),
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
    final statusIcon = controller.lastStatusOk.value == null
        ? Icons.hourglass_empty
        : controller.lastStatusOk.value == true
            ? Icons.check_circle_outline
            : Icons.error_outline;
    final statusText = controller.lastStatus.value.isEmpty ? 'Noch keine Rückmeldung.' : controller.lastStatus.value;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.code, color: color, size: 32),
        title: Text('JSON-Ansicht', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 16, color: controller.lastStatusOk.value == false ? Colors.red : color),
            const SizedBox(width: 6),
            Expanded(child: Text(statusText, overflow: TextOverflow.ellipsis)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Download speichert die aktuelle lokale JSON als Datei. Upload lädt eine Datei lokal. Speichern sendet an timetable/set/json.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadJsonFile,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadJsonFile,
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
          _buildStatusCard(context),
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

  Widget _buildStatusCard(BuildContext context) {
    final ok = controller.lastStatusOk.value;
    final topic = controller.lastTopic.value;
    final updated = controller.lastUpdated.value;
    final remarks = controller.lastRemarks;
    final color = ok == false ? Colors.red.shade50 : ok == true ? Colors.green.shade50 : Colors.grey.shade100;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(controller.lastStatus.value.isEmpty ? 'Noch keine Rückmeldung.' : controller.lastStatus.value),
          if (topic.isNotEmpty) Text('Letztes Topic: $topic', style: Theme.of(context).textTheme.bodySmall),
          if (updated != null) Text('Zeit: ${_formatTime(updated)}', style: Theme.of(context).textTheme.bodySmall),
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Server-Hinweise:', style: Theme.of(context).textTheme.bodySmall),
            ...remarks.map((r) => Text('- $r', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ],
      ),
    );
  }

  void _downloadJsonFile() {
    final jsonText = controller.exportJsonString();
    final bytes = utf8.encode(jsonText);
    final blob = html.Blob(<Object>[bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final now = DateTime.now();
    final filename = 'openmower_timetable_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  void _uploadJsonFile() {
    final input = html.FileUploadInputElement()..accept = '.json,application/json';
    input.click();
    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String) {
          controller.importJsonString(result, filename: file.name);
        } else {
          controller.setError('Datei konnte nicht als Text gelesen werden.', topic: 'local/upload');
        }
      });
      reader.readAsText(file);
    });
  }

  bool _suspensionLooksLikeDays(int days) {
    final value = controller.autoMowSuspension;
    if (value == null || value == 0) return false;
    final until = DateTime.tryParse(value.toString());
    if (until == null) return false;
    final diffHours = until.difference(DateTime.now()).inHours;
    if (days == 1) return diffHours <= 48;
    if (days == 3) return diffHours > 48;
    return false;
  }

  String _safeValue(String value, List<String> allowed) => allowed.contains(value) ? value : allowed.first;

  String _currentTimeText() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
