import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/map_editor_controller.dart';
import 'package:open_mower_app/views/map_editor_painter.dart';

class MapEditorWidget extends StatefulWidget {
  const MapEditorWidget({super.key});

  @override
  State<MapEditorWidget> createState() => _MapEditorWidgetState();
}

class _MapEditorWidgetState extends State<MapEditorWidget> {
  final MapEditorController controller = Get.find<MapEditorController>();
  final TransformationController _transformationController = TransformationController();

  static const double _minViewerScale = 1.0;
  static const double _maxViewerScale = 8.0;
  double _viewerScale = 1.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

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
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: _minViewerScale,
                  maxScale: _maxViewerScale,
                  boundaryMargin: const EdgeInsets.all(56),
                  panEnabled: !controller.isDraggingPoint.value,
                  scaleEnabled: true,
                  onInteractionUpdate: (_) => _syncViewerScale(),
                  onInteractionEnd: (_) => _syncViewerScale(),
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
                          viewerScale: _viewerScale,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildZoomControls(context),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildZoomControls(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor.withOpacity(0.94),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Hineinzoomen',
              visualDensity: VisualDensity.compact,
              onPressed: _viewerScale >= _maxViewerScale - 0.01 ? null : () => _zoomBy(1.25),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: 'Herauszoomen',
              visualDensity: VisualDensity.compact,
              onPressed: _viewerScale <= _minViewerScale + 0.01 ? null : () => _zoomBy(0.8),
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: 'Ansicht zurücksetzen',
              visualDensity: VisualDensity.compact,
              onPressed: _resetZoom,
              icon: const Icon(Icons.fit_screen_outlined),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(Offset canvasPoint, MapEditorViewport viewport) {
    final worldPoint = viewport.canvasToWorld(canvasPoint);
    final toleranceWorld = 14 / (viewport.scale * _safeViewerScale);
    if (controller.insertPointNearMidpoint(worldPoint, toleranceWorld)) return;
    if (controller.selectPointNear(worldPoint, toleranceWorld) != null) return;
    controller.selectAreaAt(worldPoint);
  }

  void _handlePanStart(Offset canvasPoint, MapEditorViewport viewport) {
    final worldPoint = viewport.canvasToWorld(canvasPoint);
    final toleranceWorld = 16 / (viewport.scale * _safeViewerScale);
    if (!controller.startPointDrag(worldPoint, toleranceWorld)) {
      controller.selectAreaAt(worldPoint);
    }
  }

  void _handlePanUpdate(Offset canvasPoint, MapEditorViewport viewport) {
    if (!controller.isDraggingPoint.value) return;
    controller.updateDraggedPoint(viewport.canvasToWorld(canvasPoint));
  }

  double get _safeViewerScale => math.max(_viewerScale, _minViewerScale);

  void _syncViewerScale() {
    final next = _transformationController.value.getMaxScaleOnAxis().clamp(_minViewerScale, _maxViewerScale).toDouble();
    if ((next - _viewerScale).abs() < 0.001) return;
    if (!mounted) return;
    setState(() => _viewerScale = next);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    if (!mounted) return;
    setState(() => _viewerScale = _minViewerScale);
  }

  void _zoomBy(double factor) {
    final currentScale = _safeViewerScale;
    final targetScale = (currentScale * factor).clamp(_minViewerScale, _maxViewerScale).toDouble();
    final actualFactor = targetScale / currentScale;
    if ((actualFactor - 1.0).abs() < 0.001) return;
    final next = _transformationController.value.clone()..scale(actualFactor);
    _transformationController.value = next;
    if (!mounted) return;
    setState(() => _viewerScale = targetScale);
  }
}
