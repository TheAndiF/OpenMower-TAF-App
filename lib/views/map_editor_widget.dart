import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/map_editor_controller.dart';
import 'package:open_mower_app/views/map_editor_painter.dart';

class MapEditorWidget extends GetView<MapEditorController> {
  const MapEditorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final areas = controller.editableAreas.toList(growable: false);
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 900.0;
          final height = width < 700 ? 360.0 : 520.0;
          final viewport = MapEditorViewport(size: Size(width, height), bounds: controller.displayBounds());
          return Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 12,
              panEnabled: !controller.isDraggingPoint.value,
              scaleEnabled: true,
              child: SizedBox(
                width: width,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: controller.editMode.value ? (details) => _handleTap(details.localPosition, viewport) : null,
                  onPanStart: controller.editMode.value ? (details) => _handlePanStart(details.localPosition, viewport) : null,
                  onPanUpdate: controller.editMode.value ? (details) => _handlePanUpdate(details.localPosition, viewport) : null,
                  onPanEnd: controller.editMode.value ? (_) => controller.finishPointDrag() : null,
                  onPanCancel: controller.editMode.value ? controller.finishPointDrag : null,
                  child: CustomPaint(
                    painter: MapEditorPainter(
                      areas: areas,
                      viewport: viewport,
                      editMode: controller.editMode.value,
                      selectedAreaIndex: controller.selectedAreaIndex.value,
                      selectedPointIndex: controller.selectedPointIndex.value,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  void _handleTap(Offset canvasPoint, MapEditorViewport viewport) {
    final worldPoint = viewport.canvasToWorld(canvasPoint);
    final toleranceWorld = 14 / viewport.scale;
    if (controller.insertPointNearMidpoint(worldPoint, toleranceWorld)) return;
    if (controller.selectPointNear(worldPoint, toleranceWorld) != null) return;
    controller.selectAreaAt(worldPoint);
  }

  void _handlePanStart(Offset canvasPoint, MapEditorViewport viewport) {
    final worldPoint = viewport.canvasToWorld(canvasPoint);
    final toleranceWorld = 16 / viewport.scale;
    if (!controller.startPointDrag(worldPoint, toleranceWorld)) {
      controller.selectAreaAt(worldPoint);
    }
  }

  void _handlePanUpdate(Offset canvasPoint, MapEditorViewport viewport) {
    if (!controller.isDraggingPoint.value) return;
    controller.updateDraggedPoint(viewport.canvasToWorld(canvasPoint));
  }
}
