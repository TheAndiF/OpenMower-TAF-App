import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/map_editor_controller.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/views/map_editor_widget.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class AreaEditorScreen extends StatefulWidget {
  const AreaEditorScreen({super.key});

  @override
  State<AreaEditorScreen> createState() => _AreaEditorScreenState();
}

class _AreaEditorScreenState extends State<AreaEditorScreen> {
  final MqttAreasController controller = Get.find<MqttAreasController>();
  final MapEditorController mapEditorController = Get.find<MapEditorController>();
  bool _renewSent = false;

  static const double _obstacleMoveStep = 0.05;

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
        Positioned.fill(
          top: 52,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: _buildMapEditorCard(context),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RobotStateWidget(),
        ),
      ],
    );
  }

  Widget _buildMapEditorCard(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Icon(Icons.edit_location_alt_outlined, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flächeneditor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Polygone, Obstacles und Ersatzgeometrien separat bearbeiten.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _buildMapEditorSection(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapEditorSection(BuildContext context) {
    return Obx(() {
      final selectedArea = mapEditorController.selectedArea;
      final selectedPoint = mapEditorController.selectedPoint;
      final selectedPointCount = mapEditorController.selectedPointCount;
      final status = mapEditorController.editorStatus.value;
      final editMode = mapEditorController.editMode.value;
      final hasChanges = mapEditorController.hasUnsavedChanges.value;
      final hasPreview = mapEditorController.hasReplacementPreview;
      final hasObstaclePreview = mapEditorController.replacementPreviewIsObstacle;
      final hasAreaPreview = mapEditorController.replacementPreviewIsAreaLine;
      final selectedType = selectedArea?.type ?? '-';
      final selectedName = selectedArea?.displayName ?? 'Keine Fläche ausgewählt';
      final selectedIsObstacle = selectedArea?.isObstacle == true;
      final selectedIsMow = selectedArea?.isMow == true;
      final selectedObstacleActive = selectedArea?.active ?? true;
      final selectedPointText = selectedPointCount == 0
          ? '-'
          : selectedPointCount == 1 && selectedPoint != null
              ? 'x ${selectedPoint.x.toStringAsFixed(3)} / y ${selectedPoint.y.toStringAsFixed(3)}'
              : '$selectedPointCount Punkte ausgewählt';
      final editableAreas = mapEditorController.editableAreas.toList(growable: false);
      final selectedAreaIndex = mapEditorController.selectedAreaIndex.value;
      final canUseObstacleTools = editMode && selectedIsObstacle;
      final canUseAreaTools = editMode && selectedIsMow;
      final canScaleGeometry = editMode && (hasObstaclePreview || selectedIsObstacle);

      return Column(
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
                onPressed: hasChanges && !hasPreview ? mapEditorController.writeBackAndSend : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Speichern'),
              ),
              OutlinedButton.icon(
                onPressed: editMode && !hasPreview ? mapEditorController.toggleMultiPointSelectionMode : null,
                icon: Icon(mapEditorController.multiPointSelectionMode.value ? Icons.check_box : Icons.check_box_outline_blank),
                label: Text(mapEditorController.multiPointSelectionMode.value ? 'Mehrfachauswahl an' : 'Mehrfachauswahl'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPointCount == 0 || hasPreview ? null : mapEditorController.clearPointSelection,
                icon: const Icon(Icons.deselect),
                label: const Text('Punkte abwählen'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPointCount == 0 || hasPreview ? null : () => mapEditorController.deleteSelectedPoint(),
                icon: const Icon(Icons.delete_outline),
                label: Text(selectedPointCount > 1 ? 'Punkte löschen' : 'Punkt löschen'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildObstacleToolBar(
            context,
            canUseObstacleTools: canUseObstacleTools,
            canScaleGeometry: canScaleGeometry,
            hasPreview: hasObstaclePreview,
            selectedObstacleActive: selectedObstacleActive,
          ),
          const SizedBox(height: 8),
          _buildAreaToolBar(
            context,
            canUseAreaTools: canUseAreaTools,
            hasPreview: hasAreaPreview,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            key: ValueKey('selected-area-$selectedAreaIndex'),
            initialValue: selectedAreaIndex,
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
                    _areaDropdownText(editableAreas[i]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: editableAreas.isEmpty || hasPreview ? null : mapEditorController.selectAreaByIndex,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _editorMetaText(context, 'Status', hasChanges ? 'Lokal geändert' : 'Synchron'),
                _editorMetaText(context, 'Fläche', selectedName),
                _editorMetaText(context, 'Typ', selectedType),
                _editorMetaText(context, 'Aktiv', selectedArea == null ? '-' : (selectedArea.active ? 'Ja' : 'Nein')),
                _editorMetaText(context, 'Punkte', '${selectedArea?.outline.length ?? 0}'),
                _editorMetaText(context, 'Auswahl', selectedPointText),
                _editorMetaText(context, 'Vorschau', hasPreview ? 'An' : 'Aus'),
                _editorMetaText(context, 'Mehrfachauswahl', mapEditorController.multiPointSelectionMode.value ? 'An' : 'Aus'),
                _editorMetaText(context, 'Raster', mapEditorController.showGrid.value ? 'An' : 'Aus'),
              ],
            ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          const Expanded(child: MapEditorWidget()),
          const SizedBox(height: 6),
          Text(
            hasPreview
                ? 'Vorschau-Modus: Alte und neue Kontur vergleichen. Obstacle-Vorschauen können verschoben/skaliert werden; Flächen-Vorschauen werden über den Winkel neu berechnet.'
                : editMode
                    ? 'Fläche wählen oder anklicken. Punkte ziehen: Grenze verschieben. Flächen- und Obstacle-Werkzeuge erzeugen sichere Ersatzgeometrien.'
                    : 'Bearbeiten aktiviert ausschließlich diesen Editor.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    });
  }

  Widget _buildObstacleToolBar(
    BuildContext context, {
    required bool canUseObstacleTools,
    required bool canScaleGeometry,
    required bool hasPreview,
    required bool selectedObstacleActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Obstacle-Werkzeuge', style: Theme.of(context).textTheme.labelLarge),
          OutlinedButton.icon(
            onPressed: canUseObstacleTools && !hasPreview
                ? () => _runEditorAction(mapEditorController.toggleSelectedObstacleActive)
                : null,
            icon: Icon(selectedObstacleActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(selectedObstacleActive ? 'Obstacle deaktivieren' : 'Obstacle aktivieren'),
          ),
          OutlinedButton.icon(
            onPressed: canUseObstacleTools && !hasPreview
                ? () => _runEditorAction(() => mapEditorController.createReplacementPreview())
                : null,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Ersatz Auto'),
          ),
          OutlinedButton.icon(
            onPressed: canUseObstacleTools
                ? () => _runEditorAction(() => mapEditorController.createReplacementPreview(shape: 'circle'))
                : null,
            icon: const Icon(Icons.radio_button_unchecked),
            label: const Text('Kreis'),
          ),
          OutlinedButton.icon(
            onPressed: canUseObstacleTools
                ? () => _runEditorAction(() => mapEditorController.createReplacementPreview(shape: 'capsule'))
                : null,
            icon: const Icon(Icons.crop_16_9),
            label: const Text('Langloch'),
          ),
          OutlinedButton.icon(
            onPressed: hasPreview
                ? () => _runEditorAction(mapEditorController.acceptReplacementPreview)
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Vorschau übernehmen'),
          ),
          OutlinedButton.icon(
            onPressed: hasPreview
                ? () => _runEditorAction(() {
                      mapEditorController.discardReplacementPreview();
                      return true;
                    })
                : null,
            icon: const Icon(Icons.close),
            label: const Text('Vorschau verwerfen'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry
                ? () => _runEditorAction(() => mapEditorController.moveActiveObstacleGeometryBy(-_obstacleMoveStep, 0))
                : null,
            icon: const Icon(Icons.keyboard_arrow_left),
            label: const Text('X-'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry
                ? () => _runEditorAction(() => mapEditorController.moveActiveObstacleGeometryBy(_obstacleMoveStep, 0))
                : null,
            icon: const Icon(Icons.keyboard_arrow_right),
            label: const Text('X+'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry
                ? () => _runEditorAction(() => mapEditorController.moveActiveObstacleGeometryBy(0, _obstacleMoveStep))
                : null,
            icon: const Icon(Icons.keyboard_arrow_up),
            label: const Text('Y+'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry
                ? () => _runEditorAction(() => mapEditorController.moveActiveObstacleGeometryBy(0, -_obstacleMoveStep))
                : null,
            icon: const Icon(Icons.keyboard_arrow_down),
            label: const Text('Y-'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry
                ? () => _runEditorAction(() => mapEditorController.scaleActiveObstacleGeometry(0.95))
                : null,
            icon: const Icon(Icons.remove),
            label: const Text('-5 %'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry
                ? () => _runEditorAction(() => mapEditorController.scaleActiveObstacleGeometry(1.05))
                : null,
            icon: const Icon(Icons.add),
            label: const Text('+5 %'),
          ),
          OutlinedButton.icon(
            onPressed: canScaleGeometry ? () => _showScaleFactorDialog(context) : null,
            icon: const Icon(Icons.tune),
            label: const Text('Faktor'),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaToolBar(
    BuildContext context, {
    required bool canUseAreaTools,
    required bool hasPreview,
  }) {
    final angle = mapEditorController.replacementCornerAngleDeg.value;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Flächen-Werkzeuge', style: Theme.of(context).textTheme.labelLarge),
          OutlinedButton.icon(
            onPressed: canUseAreaTools && !hasPreview
                ? () => _runEditorAction(mapEditorController.createAreaLineReplacementPreview)
                : null,
            icon: const Icon(Icons.linear_scale),
            label: const Text('Ersatzlinie Auto'),
          ),
          OutlinedButton.icon(
            onPressed: canUseAreaTools || hasPreview
                ? () => _runEditorAction(() {
                      mapEditorController.decreaseReplacementCornerAngle();
                      return true;
                    })
                : null,
            icon: const Icon(Icons.remove),
            label: const Text('Winkel -5°'),
          ),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text('Ecke ab ${angle.toStringAsFixed(0)}°'),
          ),
          OutlinedButton.icon(
            onPressed: canUseAreaTools || hasPreview
                ? () => _runEditorAction(() {
                      mapEditorController.increaseReplacementCornerAngle();
                      return true;
                    })
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Winkel +5°'),
          ),
          OutlinedButton.icon(
            onPressed: hasPreview
                ? () => _runEditorAction(mapEditorController.acceptReplacementPreview)
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Flächen-Vorschau übernehmen'),
          ),
          OutlinedButton.icon(
            onPressed: hasPreview
                ? () => _runEditorAction(() {
                      mapEditorController.discardReplacementPreview();
                      return true;
                    })
                : null,
            icon: const Icon(Icons.close),
            label: const Text('Flächen-Vorschau verwerfen'),
          ),
        ],
      ),
    );
  }

  void _runEditorAction(bool Function() action) {
    action();
    mapEditorController.requestEditorRepaint();
    if (mounted) {
      setState(() {});
    }
  }

  String _areaDropdownText(dynamic area) {
    final activeSuffix = !area.active ? ' · inaktiv' : '';
    return '${area.displayName} · ${area.type}$activeSuffix · ${area.outline.length} Punkte';
  }

  Future<void> _showScaleFactorDialog(BuildContext context) async {
    final factorController = TextEditingController(text: '1.05');
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Skalierungsfaktor anwenden'),
          content: TextField(
            controller: factorController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: const InputDecoration(
              labelText: 'Faktor',
              helperText: 'Beispiele: 1.05 größer, 0.95 kleiner',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(factorController.text.trim().replaceAll(',', '.'));
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Anwenden'),
            ),
          ],
        );
      },
    );
    factorController.dispose();
    if (result == null) return;
    _runEditorAction(() => mapEditorController.scaleActiveObstacleGeometry(result));
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
}
