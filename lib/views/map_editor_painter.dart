import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:open_mower_app/models/editable_map_model.dart';

class MapEditorViewport {
  MapEditorViewport({required this.size, required Rect bounds})
      : drawingRect = Rect.fromLTRB(22.0, 22.0, math.max(22.0, size.width - 22.0), math.max(22.0, size.height - 22.0)),
        worldBounds = _expandedBounds(bounds) {
    final safeWidth = math.max(worldBounds.width, 15.0);
    final safeHeight = math.max(worldBounds.height, 15.0);
    scale = math.min(drawingRect.width / safeWidth, drawingRect.height / safeHeight);
    if (!scale.isFinite || scale <= 0) scale = 1.0;
    worldWidth = safeWidth;
    worldHeight = safeHeight;
    mapTopLeft = Offset(
      drawingRect.left + (drawingRect.width - worldWidth * scale) / 2,
      drawingRect.top + (drawingRect.height - worldHeight * scale) / 2,
    );
    worldLeft = worldBounds.center.dx - worldWidth / 2;
    worldTop = worldBounds.center.dy - worldHeight / 2;
  }

  final Size size;
  final Rect drawingRect;
  final Rect worldBounds;
  late final double scale;
  late final double worldWidth;
  late final double worldHeight;
  late final Offset mapTopLeft;
  late final double worldLeft;
  late final double worldTop;

  Offset worldToCanvas(Offset world) {
    return Offset(
      mapTopLeft.dx + (world.dx - worldLeft) * scale,
      mapTopLeft.dy + (world.dy - worldTop) * scale,
    );
  }

  Offset canvasToWorld(Offset canvas) {
    return Offset(
      worldLeft + (canvas.dx - mapTopLeft.dx) / scale,
      worldTop + (canvas.dy - mapTopLeft.dy) / scale,
    );
  }

  static Rect _expandedBounds(Rect bounds) {
    if (!bounds.left.isFinite || !bounds.top.isFinite || !bounds.right.isFinite || !bounds.bottom.isFinite) {
      return const Rect.fromLTRB(-7.5, -7.5, 7.5, 7.5);
    }
    final horizontalPadding = math.max(bounds.width * 0.08, 0.75);
    final verticalPadding = math.max(bounds.height * 0.08, 0.75);
    return Rect.fromLTRB(
      bounds.left - horizontalPadding,
      bounds.top - verticalPadding,
      bounds.right + horizontalPadding,
      bounds.bottom + verticalPadding,
    );
  }
}

class MapEditorPainter extends CustomPainter {
  MapEditorPainter({
    required this.areas,
    required this.viewport,
    required this.editMode,
    required this.selectedAreaIndex,
    required this.selectedPointIndices,
    required this.viewerScale,
    required this.showGrid,
    required this.repaintTick,
    this.replacementPreview,
    this.replacementSourceIndex,
  });

  final List<EditableMapArea> areas;
  final MapEditorViewport viewport;
  final bool editMode;
  final int? selectedAreaIndex;
  final Set<int> selectedPointIndices;
  final EditableMapArea? replacementPreview;
  final int? replacementSourceIndex;
  final double viewerScale;
  final bool showGrid;
  final int repaintTick;

  final Paint _backgroundPaint = Paint()
    ..color = const Color.fromRGBO(0, 0, 0, 0.06)
    ..style = PaintingStyle.fill;
  final Paint _gridPaint = Paint()
    ..color = const Color.fromRGBO(210, 210, 210, 1)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  final Paint _axisPaint = Paint()
    ..color = const Color.fromRGBO(170, 170, 170, 1)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  final Paint _mowFillPaint = Paint()
    ..color = Colors.lightGreen.withValues(alpha: 0.70)
    ..style = PaintingStyle.fill;
  final Paint _inactiveMowFillPaint = Paint()
    ..color = Colors.lightGreen.withValues(alpha: 0.20)
    ..style = PaintingStyle.fill;
  final Paint _navFillPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..style = PaintingStyle.fill;
  final Paint _obstacleFillPaint = Paint()
    ..color = const Color.fromRGBO(55, 55, 55, 0.90)
    ..style = PaintingStyle.fill;
  final Paint _inactiveObstacleFillPaint = Paint()
    ..color = const Color.fromRGBO(120, 120, 120, 0.22)
    ..style = PaintingStyle.fill;
  final Paint _selectedAreaFillPaint = Paint()
    ..color = Colors.cyanAccent.withValues(alpha: 0.34)
    ..style = PaintingStyle.fill;
  final Paint _replacementPreviewFillPaint = Paint()
    ..color = Colors.deepPurpleAccent.withValues(alpha: 0.26)
    ..style = PaintingStyle.fill;
  final Paint _outlinePaint = Paint()
    ..color = const Color.fromRGBO(55, 55, 55, 1)
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _inactiveObstacleOutlinePaint = Paint()
    ..color = const Color.fromRGBO(120, 120, 120, 0.95)
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _inactiveMowOutlinePaint = Paint()
    ..color = const Color.fromRGBO(80, 130, 80, 0.90)
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _selectedOutlinePaint = Paint()
    ..color = Colors.orange.shade800
    ..strokeWidth = 3.2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _replacementPreviewOutlinePaint = Paint()
    ..color = Colors.deepPurple.shade700
    ..strokeWidth = 3.2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _replacementSourceOutlinePaint = Paint()
    ..color = Colors.blueGrey.shade700
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _vertexPaint = Paint()
    ..color = Colors.blue.shade700
    ..style = PaintingStyle.fill;
  final Paint _selectedVertexPaint = Paint()
    ..color = Colors.orange.shade900
    ..style = PaintingStyle.fill;
  final Paint _vertexBorderPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  final Paint _midpointPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final Paint _midpointBorderPaint = Paint()
    ..color = Colors.orange.shade700
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke;
  final Paint _previewCenterPaint = Paint()
    ..color = Colors.deepPurple.shade700
    ..style = PaintingStyle.fill;
  final Paint _previewCenterBorderPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _backgroundPaint);

    _applyScreenConstantStrokeWidths();
    if (showGrid) {
      _drawGrid(canvas);
    }

    for (final i in _paintOrderIndices()) {
      final area = areas[i];
      final path = _pathFor(area);
      final isReplacementSource = replacementPreview != null && area.sourceIndex == replacementSourceIndex;
      canvas.drawPath(path, _fillPaintFor(area));
      if (i == selectedAreaIndex) {
        canvas.drawPath(path, _selectedAreaFillPaint);
      }
      canvas.drawPath(
        path,
        isReplacementSource
            ? _replacementSourceOutlinePaint
            : i == selectedAreaIndex
                ? _selectedOutlinePaint
                : _outlinePaintFor(area),
      );
    }

    final preview = replacementPreview;
    if (preview != null) {
      _drawReplacementPreview(canvas, preview);
    }

    if (!editMode || replacementPreview != null || selectedAreaIndex == null || selectedAreaIndex! < 0 || selectedAreaIndex! >= areas.length) {
      return;
    }

    final selectedArea = areas[selectedAreaIndex!];
    _drawMidpoints(canvas, selectedArea);
    _drawVertices(canvas, selectedArea);
  }

  void _applyScreenConstantStrokeWidths() {
    final scale = _safeViewerScale;
    _gridPaint.strokeWidth = 1.0 / scale;
    _axisPaint.strokeWidth = 1.4 / scale;
    _outlinePaint.strokeWidth = 2.0 / scale;
    _inactiveObstacleOutlinePaint.strokeWidth = 2.0 / scale;
    _inactiveMowOutlinePaint.strokeWidth = 2.0 / scale;
    _selectedOutlinePaint.strokeWidth = 3.2 / scale;
    _replacementPreviewOutlinePaint.strokeWidth = 3.2 / scale;
    _replacementSourceOutlinePaint.strokeWidth = 2.2 / scale;
    _previewCenterBorderPaint.strokeWidth = 1.4 / scale;
  }

  void _drawGrid(Canvas canvas) {
    final bounds = viewport.worldBounds;
    final startX = (bounds.left / 5).floor() * 5;
    final endX = (bounds.right / 5).ceil() * 5;
    final startY = (bounds.top / 5).floor() * 5;
    final endY = (bounds.bottom / 5).ceil() * 5;

    for (var x = startX; x <= endX; x += 5) {
      final p1 = viewport.worldToCanvas(Offset(x.toDouble(), bounds.top));
      final p2 = viewport.worldToCanvas(Offset(x.toDouble(), bounds.bottom));
      canvas.drawLine(p1, p2, x == 0 ? _axisPaint : _gridPaint);
    }
    for (var y = startY; y <= endY; y += 5) {
      final p1 = viewport.worldToCanvas(Offset(bounds.left, y.toDouble()));
      final p2 = viewport.worldToCanvas(Offset(bounds.right, y.toDouble()));
      canvas.drawLine(p1, p2, y == 0 ? _axisPaint : _gridPaint);
    }

    final origin = viewport.worldToCanvas(Offset.zero);
    canvas.drawCircle(origin, 4, _axisPaint..style = PaintingStyle.fill);
    _axisPaint.style = PaintingStyle.stroke;
  }

  List<int> _paintOrderIndices() {
    final indexed = <int>[];
    for (var i = 0; i < areas.length; i++) {
      indexed.add(i);
    }
    indexed.sort((a, b) => _paintCompare(areas[a], areas[b], a, b));
    return indexed;
  }

  int _paintCompare(EditableMapArea a, EditableMapArea b, int indexA, int indexB) {
    final layerCompare = _paintLayer(a).compareTo(_paintLayer(b));
    if (layerCompare != 0) return layerCompare;

    // Bigger polygons are painted first. Smaller obstacle geometries are painted later
    // and therefore stay visible and easier to grab above larger source geometries.
    final areaCompare = _displayPolygonArea(b.outline).compareTo(_displayPolygonArea(a.outline));
    if (areaCompare != 0) return areaCompare;

    return indexA.compareTo(indexB);
  }

  int _paintLayer(EditableMapArea area) {
    if (area.type == 'obstacle' && area.active) return 4;
    if (area.type == 'obstacle') return 3;
    if (area.type == 'nav') return 2;
    if (area.type == 'mow' && area.active) return 1;
    return 0;
  }

  double _displayPolygonArea(List<EditableMapPoint> outline) {
    if (outline.length < 3) return 0;
    var twiceArea = 0.0;
    for (var i = 0; i < outline.length; i++) {
      final current = outline[i].displayOffset;
      final next = outline[(i + 1) % outline.length].displayOffset;
      twiceArea += current.dx * next.dy - next.dx * current.dy;
    }
    final area = (twiceArea / 2).abs();
    return area.isFinite ? area : 0;
  }

  Path _pathFor(EditableMapArea area) {
    final path = Path();
    if (area.outline.isEmpty) return path;
    final first = viewport.worldToCanvas(area.outline.first.displayOffset);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < area.outline.length; i++) {
      final point = viewport.worldToCanvas(area.outline[i].displayOffset);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  Paint _fillPaintFor(EditableMapArea area) {
    if (area.type == 'nav') return _navFillPaint;
    if (area.type == 'obstacle' && !area.active) return _inactiveObstacleFillPaint;
    if (area.type == 'obstacle') return _obstacleFillPaint;
    if (area.type == 'mow' && !area.active) return _inactiveMowFillPaint;
    return _mowFillPaint;
  }

  Paint _outlinePaintFor(EditableMapArea area) {
    if (area.type == 'obstacle' && !area.active) return _inactiveObstacleOutlinePaint;
    if (area.type == 'mow' && !area.active) return _inactiveMowOutlinePaint;
    return _outlinePaint;
  }

  void _drawReplacementPreview(Canvas canvas, EditableMapArea preview) {
    final path = _pathFor(preview);
    canvas.drawPath(path, _replacementPreviewFillPaint);
    canvas.drawPath(path, _replacementPreviewOutlinePaint);
    _drawPreviewVertices(canvas, preview);
    _drawPreviewCenter(canvas, preview);
  }

  void _drawPreviewVertices(Canvas canvas, EditableMapArea area) {
    final scale = _safeViewerScale;
    final borderWidth = 1.0 / scale;
    _vertexBorderPaint.strokeWidth = borderWidth;
    final radius = 4.5 / scale;
    for (final point in area.outline) {
      final center = viewport.worldToCanvas(point.displayOffset);
      canvas.drawCircle(center, radius, _previewCenterPaint);
      canvas.drawCircle(center, radius, _vertexBorderPaint);
    }
  }

  void _drawPreviewCenter(Canvas canvas, EditableMapArea area) {
    if (area.outline.isEmpty) return;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final point in area.outline) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }
    final displayCenter = Offset((minX + maxX) / 2, -(minY + maxY) / 2);
    final center = viewport.worldToCanvas(displayCenter);
    final scale = _safeViewerScale;
    final radius = 7.0 / scale;
    final crossHalf = 11.0 / scale;
    canvas.drawCircle(center, radius, _previewCenterPaint);
    canvas.drawCircle(center, radius, _previewCenterBorderPaint);
    canvas.drawLine(center.translate(-crossHalf, 0), center.translate(crossHalf, 0), _replacementPreviewOutlinePaint);
    canvas.drawLine(center.translate(0, -crossHalf), center.translate(0, crossHalf), _replacementPreviewOutlinePaint);
  }

  void _drawVertices(Canvas canvas, EditableMapArea area) {
    final scale = _safeViewerScale;
    final borderWidth = 1.2 / scale;
    _vertexBorderPaint.strokeWidth = borderWidth;
    for (var i = 0; i < area.outline.length; i++) {
      final center = viewport.worldToCanvas(area.outline[i].displayOffset);
      final selected = selectedPointIndices.contains(i);
      final radius = (selected ? 7.2 : 6.0) / scale;
      canvas.drawCircle(center, radius, selected ? _selectedVertexPaint : _vertexPaint);
      canvas.drawCircle(center, radius, _vertexBorderPaint);
    }
  }

  void _drawMidpoints(Canvas canvas, EditableMapArea area) {
    final scale = _safeViewerScale;
    final radius = 5.0 / scale;
    final plusHalfLength = 2.5 / scale;
    _midpointBorderPaint.strokeWidth = 1.6 / scale;
    for (var i = 0; i < area.outline.length; i++) {
      final current = area.outline[i].displayOffset;
      final next = area.outline[(i + 1) % area.outline.length].displayOffset;
      final midpoint = viewport.worldToCanvas(Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2));
      canvas.drawCircle(midpoint, radius, _midpointPaint);
      canvas.drawCircle(midpoint, radius, _midpointBorderPaint);
      canvas.drawLine(midpoint.translate(-plusHalfLength, 0), midpoint.translate(plusHalfLength, 0), _midpointBorderPaint);
      canvas.drawLine(midpoint.translate(0, -plusHalfLength), midpoint.translate(0, plusHalfLength), _midpointBorderPaint);
    }
  }

  double get _safeViewerScale => math.max(viewerScale, 1.0);

  @override
  bool shouldRepaint(covariant MapEditorPainter oldDelegate) {
    return oldDelegate.areas != areas ||
        oldDelegate.viewport != viewport ||
        oldDelegate.editMode != editMode ||
        oldDelegate.selectedAreaIndex != selectedAreaIndex ||
        oldDelegate.selectedPointIndices.length != selectedPointIndices.length ||
        !oldDelegate.selectedPointIndices.containsAll(selectedPointIndices) ||
        oldDelegate.replacementPreview != replacementPreview ||
        oldDelegate.replacementSourceIndex != replacementSourceIndex ||
        oldDelegate.viewerScale != viewerScale ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.repaintTick != repaintTick;
  }
}
