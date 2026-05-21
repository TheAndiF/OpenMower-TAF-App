import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
  static const double _maxViewerScale = 80.0;
  double _viewerScale = 1.0;
  Size _lastViewportSize = Size.zero;

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
          _lastViewportSize = Size(width, height);
          final viewport = MapEditorViewport(size: _lastViewportSize, bounds: controller.displayBounds());
          return Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _handleEditorPointerSignal,
              child: Stack(
                children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: _minViewerScale,
                  maxScale: _maxViewerScale,
                  boundaryMargin: const EdgeInsets.all(56),
                  panEnabled: !controller.isDraggingPoint.value,
                  scaleEnabled: true,
                  trackpadScrollCausesScale: true,
                  onInteractionUpdate: (_) => _syncViewerScale(),
                  onInteractionEnd: (_) => _syncViewerScale(),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerSignal: _handlePointerSignal,
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
                            selectedPointIndices: controller.selectedPointIndices.toSet(),
                            viewerScale: _viewerScale,
                            showGrid: controller.showGrid.value,
                          ),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlButton(
                  tooltip: 'Herauszoomen',
                  onPressed: _viewerScale <= _minViewerScale + 0.01 ? null : () => _zoomBy(0.62),
                  icon: Icons.remove,
                ),
                _controlButton(
                  tooltip: 'Karte nach oben verschieben',
                  onPressed: () => _panBy(const Offset(0, -1)),
                  icon: Icons.keyboard_arrow_up,
                ),
                _controlButton(
                  tooltip: 'Hineinzoomen',
                  onPressed: _viewerScale >= _maxViewerScale - 0.01 ? null : () => _zoomBy(1.60),
                  icon: Icons.add,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlButton(
                  tooltip: 'Karte nach links verschieben',
                  onPressed: () => _panBy(const Offset(-1, 0)),
                  icon: Icons.keyboard_arrow_left,
                ),
                _controlButton(
                  tooltip: 'Ansicht zurücksetzen',
                  onPressed: _resetZoom,
                  icon: Icons.fit_screen_outlined,
                ),
                _controlButton(
                  tooltip: 'Karte nach rechts verschieben',
                  onPressed: () => _panBy(const Offset(1, 0)),
                  icon: Icons.keyboard_arrow_right,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlButton(
                  tooltip: controller.showGrid.value ? 'Raster ausblenden' : 'Raster anzeigen',
                  onPressed: controller.toggleGridVisibility,
                  icon: controller.showGrid.value ? Icons.grid_on : Icons.grid_off,
                  highlighted: controller.showGrid.value,
                ),
                _controlButton(
                  tooltip: 'Karte nach unten verschieben',
                  onPressed: () => _panBy(const Offset(0, 1)),
                  icon: Icons.keyboard_arrow_down,
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Text(
                      '${_viewerScale.toStringAsFixed(_viewerScale < 10 ? 1 : 0)}×',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
    bool highlighted = false,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: highlighted ? theme.primaryColor.withOpacity(0.14) : null,
          foregroundColor: highlighted ? theme.primaryColor : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon),
      ),
    );
  }

  void _handleEditorPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
      if (resolvedEvent is! PointerScrollEvent) return;
      final dy = resolvedEvent.scrollDelta.dy;
      if (dy == 0) return;

      resolvedEvent.respond(allowPlatformDefault: false);
      _zoomBy(dy > 0 ? 0.86 : 1.18);
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
      if (resolvedEvent is! PointerScrollEvent) return;
      final dy = resolvedEvent.scrollDelta.dy;
      if (dy == 0) return;

      resolvedEvent.respond(allowPlatformDefault: false);
      _zoomBy(dy > 0 ? 0.86 : 1.18);
    });
  }

  void _handleTap(Offset canvasPoint, MapEditorViewport viewport) {
    final worldPoint = viewport.canvasToWorld(canvasPoint);
    final toleranceWorld = 14 / (viewport.scale * _safeViewerScale);
    final hitAreaIndex = controller.areaIndexAt(worldPoint);
    final currentAreaIndex = controller.selectedAreaIndex.value;

    // Eine andere Fläche hat Vorrang vor Punktaktionen der bisher markierten Fläche.
    // Dadurch wechselt die Auswahl eindeutig: neue Fläche markieren, alte entmarkieren.
    if (hitAreaIndex != null && hitAreaIndex != currentAreaIndex) {
      controller.selectAreaByIndex(hitAreaIndex);
      return;
    }

    // Punktbearbeitung ist nur innerhalb der aktuell aktiven Fläche relevant.
    if (controller.multiPointSelectionMode.value) {
      if (controller.togglePointSelectionNear(worldPoint, toleranceWorld) != null) return;
      if (hitAreaIndex != null && hitAreaIndex == currentAreaIndex) return;
    } else {
      if (controller.insertPointNearMidpoint(worldPoint, toleranceWorld)) return;
      if (controller.selectPointNear(worldPoint, toleranceWorld) != null) return;
    }

    if (hitAreaIndex != null) {
      controller.selectAreaByIndex(hitAreaIndex);
    } else {
      controller.clearAreaSelection();
    }
  }

  void _handlePanStart(Offset canvasPoint, MapEditorViewport viewport) {
    final worldPoint = viewport.canvasToWorld(canvasPoint);
    final toleranceWorld = 16 / (viewport.scale * _safeViewerScale);
    final hitAreaIndex = controller.areaIndexAt(worldPoint);
    final currentAreaIndex = controller.selectedAreaIndex.value;

    // Beginnt die Geste auf einer anderen Fläche, wird zuerst nur die Fläche gewechselt.
    // Der Nutzer kann anschließend deren Punkte gezielt bewegen.
    if (hitAreaIndex != null && hitAreaIndex != currentAreaIndex) {
      controller.selectAreaByIndex(hitAreaIndex);
      return;
    }

    if (!controller.startPointDrag(worldPoint, toleranceWorld)) {
      if (hitAreaIndex != null) {
        controller.selectAreaByIndex(hitAreaIndex);
      } else {
        controller.clearAreaSelection();
      }
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


  void _panBy(Offset direction) {
    if (_lastViewportSize == Size.zero) return;
    final step = math.max(36.0, math.min(_lastViewportSize.shortestSide * 0.12, 96.0));
    final matrix = _transformationController.value.clone();
    matrix.storage[12] += direction.dx * step;
    matrix.storage[13] += direction.dy * step;
    _transformationController.value = matrix;
  }

  void _zoomBy(double factor) {
    final currentScale = _safeViewerScale;
    final targetScale = (currentScale * factor).clamp(_minViewerScale, _maxViewerScale).toDouble();
    if ((targetScale - currentScale).abs() < 0.001) return;

    final focalPoint = _lastViewportSize == Size.zero
        ? Offset.zero
        : Offset(_lastViewportSize.width / 2, _lastViewportSize.height / 2);
    final scenePoint = _transformationController.toScene(focalPoint);
    final next = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(targetScale)
      ..translate(-scenePoint.dx, -scenePoint.dy);

    _transformationController.value = next;
    if (!mounted) return;
    setState(() => _viewerScale = targetScale);
  }
}
