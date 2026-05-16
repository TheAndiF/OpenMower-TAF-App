import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/controllers/map_editor_controller.dart';
import 'package:open_mower_app/controllers/remote_controller.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';
import 'package:open_mower_app/views/map_editor_widget.dart';

class MqttAreasScreen extends StatefulWidget {
  const MqttAreasScreen({super.key});

  @override
  State<MqttAreasScreen> createState() => _MqttAreasScreenState();
}

class _MqttAreasScreenState extends State<MqttAreasScreen> {
  final MqttAreasController controller = Get.find<MqttAreasController>();
  final MapEditorController mapEditorController = Get.find<MapEditorController>();
  final RobotStateController robotStateController = Get.find<RobotStateController>();
  final RemoteController remoteController = Get.find<RemoteController>();
  bool _jsonExpanded = false;
  bool _renewSent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_renewSent) {
      _renewSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !controller.hasData) {
          controller.requestMap();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final mowAreas = controller.mowAreas;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentAreaSection(context),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.grass,
                  title: 'Flächen',
                  subtitle: 'Nur Flächen vom Typ mow, sortiert nach Mähreihenfolge',
                  child: _buildMowAreasSection(context, mowAreas),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.edit_location_alt_outlined,
                  title: 'Karteneditor',
                  subtitle: 'Polygone separat bearbeiten – ohne die bisherigen Kartenansichten zu verändern',
                  child: _buildMapEditorSection(context),
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

  Widget _buildCurrentAreaSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final currentAreaId = robotStateController.robotState.value.currentAreaId.trim();
    final currentArea = controller.findAreaById(currentAreaId);
    final hasCurrentArea = currentArea != null;
    final currentName = currentArea == null ? 'Keine aktive Fläche' : controller.areaNameFor(currentArea);
    final currentOrder = currentArea == null ? '-' : controller.formatMowingOrder(controller.mowingOrderFor(currentArea));
    final skipAvailable = robotStateController.hasAction('mower_logic:mowing/skip_area');

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                _currentAreaHeaderIcon(color: color, active: hasCurrentArea),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fläche anzeigen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aktuelle Mähfläche anzeigen und bei Bedarf überspringen',
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
            child: _buildCurrentAreaCard(
              context,
              currentName: currentName,
              currentOrder: currentOrder,
              hasCurrentArea: hasCurrentArea,
              skipAvailable: skipAvailable,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAreaCard(
    BuildContext context, {
    required String currentName,
    required String currentOrder,
    required bool hasCurrentArea,
    required bool skipAvailable,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    final headline = hasCurrentArea ? 'Aktuelle Fläche' : 'Keine aktive Fläche';
    final detail = hasCurrentArea ? currentName : 'Aktuell meldet robot_state/json keine zuordenbare Mähfläche.';
    final orderText = hasCurrentArea ? 'Mähreihenfolge $currentOrder' : 'Mähreihenfolge -';
    final skipButton = _currentAreaActionButton(
      context,
      label: 'Fläche skippen',
      active: false,
      icon: Icons.skip_next,
      onPressed: (hasCurrentArea && skipAvailable)
          ? () => remoteController.callAction('mower_logic:mowing/skip_area')
          : null,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _currentAreaBodyIcon(context, active: hasCurrentArea)),
          const SizedBox(height: 18),
          Text(headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(orderText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 20),
          SizedBox(height: 56, child: skipButton),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _currentAreaBodyIcon(context, active: hasCurrentArea),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 8),
              Text(
                detail,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(orderText, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(width: 220, height: 56, child: skipButton),
      ],
    );
  }

  Widget _currentAreaHeaderIcon({required Color color, required bool active}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.65), width: 2),
      ),
      child: Icon(active ? Icons.grass : Icons.info_outline, color: color, size: 24),
    );
  }

  Widget _currentAreaBodyIcon(BuildContext context, {required bool active}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green.withOpacity(0.10) : color.withOpacity(0.08),
      ),
      child: Icon(active ? Icons.grass : Icons.remove_circle_outline, color: active ? Colors.green : color, size: 64),
    );
  }

  Widget _currentAreaActionButton(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    final childLabel = Text(
      active ? '✓ $label' : label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final child = icon == null
        ? childLabel
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: childLabel),
            ],
          );

    if (active) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: child,
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

  Widget _buildMowAreasSection(BuildContext context, List<Map<String, dynamic>> mowAreas) {
    if (!controller.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Noch keine Flächen empfangen. Sobald ein map/json Payload eintrifft, erscheinen die Mähflächen hier.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (mowAreas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Der letzte Payload enthält keine Fläche mit properties.type = mow.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ...mowAreas.map((area) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAreaRow(context, area),
          );
        }),
      ],
    );
  }

  Widget _buildAreaRow(BuildContext context, Map<String, dynamic> area) {
    final id = controller.areaIdFor(area);
    final editing = controller.isAreaEditing(id);
    final enabled = controller.mowingEnabledFor(area);
    final order = controller.mowingOrderFor(area);
    final name = controller.areaNameFor(area);
    final isCurrentArea = id.isNotEmpty && id == robotStateController.robotState.value.currentAreaId.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentArea ? Colors.green.withOpacity(0.12) : null,
        border: Border.all(color: isCurrentArea ? Colors.green.withOpacity(0.65) : Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _areaNameField(id, name, enabled: editing),
          _areaOrderField(id, order, enabled: editing),
          _boolSwitch('Aktiv', enabled, editing ? (value) => controller.updateMowingEnabled(id, value) : null),
          SizedBox(
            width: 56,
            child: IconButton(
              tooltip: editing ? 'Mähfläche speichern' : 'Mähfläche ändern',
              onPressed: id.isEmpty ? null : () => controller.toggleEditArea(id),
              icon: Icon(editing ? Icons.save_outlined : Icons.edit_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaNameField(String id, String value, {bool enabled = true}) {
    return SizedBox(
      width: 420,
      child: TextFormField(
        key: ValueKey('$id-name-$value-$enabled'),
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Name'),
        enabled: enabled,
        onChanged: enabled ? (next) => controller.updateAreaName(id, next) : null,
      ),
    );
  }

  Widget _areaOrderField(String id, int? value, {bool enabled = true}) {
    final text = controller.formatMowingOrder(value);
    return SizedBox(
      width: 160,
      child: TextFormField(
        key: ValueKey('$id-mowing-order-$text-$enabled'),
        initialValue: text,
        decoration: const InputDecoration(labelText: 'Mähreihenfolge'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        maxLength: 2,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        enabled: enabled,
        onChanged: enabled
            ? (next) {
                if (next.length == 2) {
                  controller.updateMowingOrder(id, next);
                }
              }
            : null,
      ),
    );
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

  Widget _buildMapEditorSection(BuildContext context) {
    return Obx(() {
      final selectedArea = mapEditorController.selectedArea;
      final selectedPoint = mapEditorController.selectedPoint;
      final status = mapEditorController.editorStatus.value;
      final editMode = mapEditorController.editMode.value;
      final hasChanges = mapEditorController.hasUnsavedChanges.value;
      final selectedType = selectedArea?.type ?? '-';
      final selectedName = selectedArea?.displayName ?? 'Keine Fläche ausgewählt';
      final selectedPointText = selectedPoint == null
          ? '-'
          : 'x ${selectedPoint.x.toStringAsFixed(3)} / y ${selectedPoint.y.toStringAsFixed(3)}';
      final editableAreas = mapEditorController.editableAreas.toList(growable: false);
      final selectedAreaIndex = mapEditorController.selectedAreaIndex.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.hasData ? mapEditorController.toggleEditMode : null,
                  icon: Icon(editMode ? Icons.pause_circle_outline : Icons.edit_outlined),
                  label: Text(editMode ? 'Bearbeitung pausieren' : 'Bearbeiten'),
                ),
                OutlinedButton.icon(
                  onPressed: mapEditorController.canUndo ? mapEditorController.undo : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Rückgängig'),
                ),
                OutlinedButton.icon(
                  onPressed: hasChanges ? mapEditorController.discardChanges : null,
                  icon: const Icon(Icons.restore),
                  label: const Text('Verwerfen'),
                ),
                ElevatedButton.icon(
                  onPressed: hasChanges ? mapEditorController.writeBackAndSend : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Speichern'),
                ),
                OutlinedButton.icon(
                  onPressed: selectedPoint == null ? null : () => mapEditorController.deleteSelectedPoint(),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Punkt löschen'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: selectedAreaIndex,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Fläche zur Bearbeitung',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.layers_outlined),
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Keine Fläche ausgewählt'),
                ),
                for (var i = 0; i < editableAreas.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      '${editableAreas[i].displayName} · ${editableAreas[i].type} · ${editableAreas[i].outline.length} Punkte',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: editableAreas.isEmpty ? null : mapEditorController.selectAreaByIndex,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.18)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _editorMetaText(context, 'Status', hasChanges ? 'Lokal geändert' : 'Synchron'),
                  _editorMetaText(context, 'Fläche', selectedName),
                  _editorMetaText(context, 'Typ', selectedType),
                  _editorMetaText(context, 'Punkte', '${selectedArea?.outline.length ?? 0}'),
                  _editorMetaText(context, 'Punkt', selectedPointText),
                  _editorMetaText(context, 'Raster', mapEditorController.showGrid.value ? 'An' : 'Aus'),
                ],
              ),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(status, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            const MapEditorWidget(),
            const SizedBox(height: 10),
            Text(
              editMode
                  ? 'Fläche bevorzugt über das Dropdown wählen. Alternativ weiter direkt in der Karte antippen. Punkte ziehen: Grenze verschieben. Plus-Marker antippen: Punkt einfügen. Unten links in der 3×3-Matrix lässt sich das Raster ein- oder ausblenden.'
                  : 'Der Editor ist getrennt von Dashboard- und Steuerkarten. Bearbeiten aktiviert ausschließlich diesen Bereich.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    });
  }

  Widget _editorMetaText(BuildContext context, String label, String value) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
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
                                Text('Flächen anzeigen, importieren und speichern', style: Theme.of(context).textTheme.bodyMedium),
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
                        _buildStatusCard(context),
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
        onPressed: _downloadJsonFile,
        icon: const Icon(Icons.download),
        label: Text(isMobile ? 'Herunterladen' : 'Download'),
      ),
      OutlinedButton.icon(
        onPressed: _uploadJsonFile,
        icon: const Icon(Icons.upload),
        label: Text(isMobile ? 'Hochladen' : 'Upload'),
      ),
      ElevatedButton.icon(
        onPressed: controller.hasData ? controller.sendMap : null,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Speichern'),
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

  Widget _buildStatusCard(BuildContext context) {
    final ok = controller.lastStatusOk.value;
    final topic = controller.lastTopic.value;
    final updated = controller.lastUpdated.value;
    final remarks = controller.lastRemarks;

    final Color accent;
    final Color background;
    final IconData icon;
    final String headline;
    if (ok == true) {
      accent = Colors.green.shade700;
      background = Colors.green.shade50;
      icon = Icons.check_circle_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Flächen vom Server empfangen.' : controller.lastStatus.value;
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
      headline = controller.lastStatus.value.isEmpty ? 'Noch keine Flächen empfangen.' : controller.lastStatus.value;
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
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Server-Hinweise', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  ...remarks.map((remark) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('• $remark', style: Theme.of(context).textTheme.bodySmall),
                      )),
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
            minLines: 10,
            maxLines: 22,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'map.json',
              alignLabelWithHint: true,
              helperText: 'Änderungen im Editor werden erst mit „Speichern“ an map/set/json gesendet.',
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
          'Lokale Flächen. Upload übernimmt lokal, Speichern sendet an map/set/json.',
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
    final filename = 'openmower_map_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
