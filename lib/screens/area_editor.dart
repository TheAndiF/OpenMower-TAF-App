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
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: _buildMapEditorCard(context),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(Icons.edit_location_alt_outlined, color: color, size: 32),
                const SizedBox(width: 12),
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
                        'Polygone separat bearbeiten – ohne die Flächenübersicht zu blockieren.',
                        style: Theme.of(context).textTheme.bodyMedium,
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
            child: _buildMapEditorSection(context),
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
      final selectedType = selectedArea?.type ?? '-';
      final selectedName = selectedArea?.displayName ?? 'Keine Fläche ausgewählt';
      final selectedPointText = selectedPointCount == 0
          ? '-'
          : selectedPointCount == 1 && selectedPoint != null
              ? 'x ${selectedPoint.x.toStringAsFixed(3)} / y ${selectedPoint.y.toStringAsFixed(3)}'
              : '$selectedPointCount Punkte ausgewählt';
      final editableAreas = mapEditorController.editableAreas.toList(growable: false);
      final selectedAreaIndex = mapEditorController.selectedAreaIndex.value;

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
                onPressed: hasChanges ? mapEditorController.writeBackAndSend : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Speichern'),
              ),
              OutlinedButton.icon(
                onPressed: editMode ? mapEditorController.toggleMultiPointSelectionMode : null,
                icon: Icon(mapEditorController.multiPointSelectionMode.value ? Icons.check_box : Icons.check_box_outline_blank),
                label: Text(mapEditorController.multiPointSelectionMode.value ? 'Mehrfachauswahl an' : 'Mehrfachauswahl'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPointCount == 0 ? null : mapEditorController.clearPointSelection,
                icon: const Icon(Icons.deselect),
                label: const Text('Punkte abwählen'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPointCount == 0 ? null : () => mapEditorController.deleteSelectedPoint(),
                icon: const Icon(Icons.delete_outline),
                label: Text(selectedPointCount > 1 ? 'Punkte löschen' : 'Punkt löschen'),
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
                _editorMetaText(context, 'Auswahl', selectedPointText),
                _editorMetaText(context, 'Mehrfachauswahl', mapEditorController.multiPointSelectionMode.value ? 'An' : 'Aus'),
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
                ? 'Fläche bevorzugt über das Dropdown wählen. Punkte ziehen: Grenze verschieben. Plus-Marker antippen: Punkt einfügen. Mehrfachauswahl aktivieren: mehrere Punkte antippen, gemeinsam ziehen oder gemeinsam löschen. Der Zoom reicht jetzt bis 80×.'
                : 'Diese Unterseite ist getrennt von Dashboard-, Steuer- und Flächenübersicht. Bearbeiten aktiviert ausschließlich diesen Editor.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
}
