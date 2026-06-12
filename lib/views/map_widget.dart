import 'package:flutter/material.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:get/get.dart';
import 'dart:math';

import 'package:open_mower_app/models/map_model.dart';
import 'package:open_mower_app/models/map_overlay_model.dart';
import 'package:open_mower_app/models/mowing_progress_model.dart';
import 'package:open_mower_app/models/robot_state.dart';

class MapWidget extends GetView<RobotStateController> {
  const MapWidget({super.key, required this.centerOnRobot});

  final bool centerOnRobot;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      panEnabled: !centerOnRobot,
      scaleEnabled: !centerOnRobot,
      maxScale: 10.0,
      minScale: 0.1,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: RepaintBoundary(
          child: Obx(
            () => CustomPaint(
              isComplex: true,
              painter: MapPainter(
                controller.map.value,
                controller.mapOverlay.value,
                controller.mowingProgress.value,
                controller.robotState.value,
                controller.lastActiveMowingAreaId.value,
                centerOnRobot,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  MapPainter(
    this.mapModel,
    this.mapOverlayModel,
    this.mowingProgressModel,
    this.robotState,
    this.lastActiveMowingAreaId,
    this.centerOnRobot,
  ) {
    // "robot" arrow
    pathRobot.reset();
    pathRobot.moveTo(0.1979167, 0.8750000);
    pathRobot.lineTo(0.1666667, 0.8437500);
    pathRobot.lineTo(0.5000000, 0.08333333);
    pathRobot.lineTo(0.8333333, 0.8437500);
    pathRobot.lineTo(0.8020833, 0.8750000);
    pathRobot.lineTo(0.5000000, 0.7375000);
    pathRobot.moveTo(0.5000000, 0.6708333);
    pathRobot.close();

    // "home" icon
    pathDock.moveTo(0.2291667, 0.8125000);
    pathDock.lineTo(0.3854167, 0.8125000);
    pathDock.lineTo(0.3854167, 0.5520833);
    pathDock.lineTo(0.6145833, 0.5520833);
    pathDock.lineTo(0.6145833, 0.8125000);
    pathDock.lineTo(0.7708333, 0.8125000);
    pathDock.lineTo(0.7708333, 0.4062500);
    pathDock.lineTo(0.5000000, 0.2031250);
    pathDock.lineTo(0.2291667, 0.4062500);
    pathDock.close();
    pathDock.moveTo(0.1666667, 0.8750000);
    pathDock.lineTo(0.1666667, 0.3750000);
    pathDock.lineTo(0.5000000, 0.1250000);
    pathDock.lineTo(0.8333333, 0.3750000);
    pathDock.lineTo(0.8333333, 0.8750000);
    pathDock.lineTo(0.5520833, 0.8750000);
    pathDock.lineTo(0.5520833, 0.6145833);
    pathDock.lineTo(0.4479167, 0.6145833);
    pathDock.lineTo(0.4479167, 0.8750000);
    pathDock.close();
    pathDock.moveTo(0.5000000, 0.5072917);
    pathDock.close();
  }

  final MapModel mapModel;
  final MapOverlayModel mapOverlayModel;
  final MowingProgressModel mowingProgressModel;
  final RobotState robotState;
  final String lastActiveMowingAreaId;
  final bool centerOnRobot;

  final _backgroundPaint = Paint()
    ..color = const Color.fromRGBO(0, 0, 0, 0.1)
    ..style = PaintingStyle.fill;
  final _mowOutlinePaint = Paint()
    ..strokeWidth = 0.02
    ..color = const Color.fromRGBO(50, 50, 50, 1.0)
    ..style = PaintingStyle.stroke;
  final _mowFillPaint = Paint()
    ..color = Colors.lightGreen
    ..style = PaintingStyle.fill;
  final _mowDisabledFillPaint = Paint()
    ..color = Colors.green.withOpacity(0.6)
    ..style = PaintingStyle.fill;
  final _mowDisabledOutlinePaint = Paint()
    ..strokeWidth = 0.02
    ..color = Colors.green.withOpacity(0.6)
    ..style = PaintingStyle.stroke;
  final _currentAreaOverlayPaint = Paint()
    ..strokeWidth = 0.08
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _plannedPathPaint = Paint()
    ..strokeWidth = 0.025
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _currentPathPaint = Paint()
    ..strokeWidth = 0.035
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _completedPathPaint = Paint()
    ..strokeWidth = 0.024
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _navigationFillPaint = Paint()
    ..color = const Color.fromRGBO(250, 250, 250, 1.0)
    ..style = PaintingStyle.fill;
  final _obstaclePaint = Paint()
    ..color = const Color.fromRGBO(50, 50, 50, 1.0)
    ..style = PaintingStyle.fill;
  final _coordinateLinesPaint = Paint()
    ..color = const Color.fromRGBO(210, 210, 210, 1)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square
    ..strokeWidth = 0;
  final _coordinateLinesPaintOrigin = Paint()
    ..color = const Color.fromRGBO(190, 190, 190, 1)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square
    ..strokeWidth = 0.1;
  final _robotPaint = Paint()
    ..color = const Color.fromRGBO(25, 25, 25, 1.0)
    ..style = PaintingStyle.fill;

  final Path pathRobot = Path();
  final Path pathDock = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundRect = Offset.zero & size;
    final drawingRect = Rect.fromLTRB(25, 150, size.width - 25, size.height - 25);

    canvas.drawRect(backgroundRect, _backgroundPaint);

    final double mapWidth = max(mapModel.width, 15);
    final double mapHeight = max(mapModel.height, 15);

    double mapScale = 60;
    if (!centerOnRobot) {
      mapScale = min(drawingRect.width / mapWidth, drawingRect.height / mapHeight);
    }

    canvas.translate(
      drawingRect.topLeft.dx + (drawingRect.width - mapWidth * mapScale) / 2.0,
      drawingRect.topLeft.dy + (drawingRect.height - mapHeight * mapScale) / 2.0,
    );

    canvas.scale(mapScale);

    if (!centerOnRobot) {
      canvas.translate(mapWidth / 2 - mapModel.centerX, mapHeight / 2 - mapModel.centerY);
    } else {
      canvas.translate(mapWidth / 2 - robotState.posX, mapHeight / 2 - robotState.posY);
    }

    final startX = ((-mapWidth / 2 +
                    mapModel.centerX -
                    (drawingRect.topLeft.dx + (drawingRect.width - mapWidth * mapScale) / 2.0) /
                        mapScale) /
                5)
            .round() *
        5;
    final startY = ((-(mapHeight / 2 - mapModel.centerY) -
                    (drawingRect.topLeft.dy + (drawingRect.height - mapHeight * mapScale) / 2.0) /
                        mapScale) /
                5)
            .round() *
        5;

    final Path grid = Path();
    final width = backgroundRect.width * mapScale;
    final height = backgroundRect.height * mapScale;
    for (int x = startX.round(); x < startX + width; x += 5) {
      if (x != 0) {
        grid.moveTo(x.toDouble(), startY.toDouble());
        grid.lineTo(x.toDouble(), startY + height);
      }
    }
    for (int y = startY; y < startY + height; y += 5) {
      if (y != 0) {
        grid.moveTo(startX.toDouble(), y.toDouble());
        grid.lineTo(startX + width, y.toDouble());
      }
    }

    final Path axes = Path();
    axes.moveTo(startX.toDouble(), 0);
    axes.lineTo(startX + width, 0);
    axes.moveTo(0, startY.toDouble());
    axes.lineTo(0, startY + height);

    canvas.drawPath(grid, _coordinateLinesPaint);
    canvas.drawPath(axes, _coordinateLinesPaintOrigin);
    canvas.drawCircle(Offset.zero, 0.5, _coordinateLinesPaintOrigin..style = PaintingStyle.fill);

    for (final area in mapModel.navigationAreas) {
      canvas.drawPath(area, _navigationFillPaint);
      canvas.drawPath(area, _mowOutlinePaint);
    }

    final currentAreaId = _effectiveCurrentAreaId;
    final activeProgress = currentAreaId.isEmpty
        ? null
        : mowingProgressModel.areaById(currentAreaId);

    for (final area in mapModel.mowingAreas) {
      final fillPaint = area.mowingEnabled ? _mowFillPaint : _mowDisabledFillPaint;
      final outlinePaint = area.mowingEnabled ? _mowOutlinePaint : _mowDisabledOutlinePaint;

      canvas.drawPath(area.outline, fillPaint);
      canvas.drawPath(area.outline, outlinePaint);
    }

    _drawCurrentAreaOverlay(canvas, activeProgress);

    // Draw the circular order/progress labels after paths and outlines.
    // This keeps the text and white background readable even when planned
    // mowing paths pass through the label position.
    for (final area in mapModel.mowingAreas) {
      if (area.mowingOrder != null) {
        final progressCurrentAreaId = mowingProgressModel.currentAreaId.trim();
        final realCurrentAreaId = progressCurrentAreaId.isNotEmpty
            ? progressCurrentAreaId
            : robotState.currentAreaId.trim();
        final isActivelyMowingArea =
            realCurrentAreaId.isNotEmpty && area.id == realCurrentAreaId;
        _drawMowingOverlayLabel(
          canvas,
          area.labelPosition,
          area.mowingOrder!,
          area.mowingEnabled,
          isActivelyMowingArea ? mowingProgressModel.areaById(realCurrentAreaId)?.percent : null,
        );
      }
    }

    for (final path in mapModel.obstacles) {
      canvas.drawPath(path, _obstaclePaint);
    }

    canvas.save();
    canvas.translate(mapModel.dockX, mapModel.dockY);
    canvas.drawCircle(
      Offset.zero,
      0.3,
      Paint()
        ..color = Colors.greenAccent.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );
    canvas.scale(0.5);
    canvas.translate(-0.5, -0.5);
    canvas.drawPath(pathDock, _robotPaint);
    canvas.restore();

    for (final overlay in mapOverlayModel.polygons) {
      canvas.drawPath(overlay.overlay, getOverlayPaint(overlay));
    }

    canvas.save();
    canvas.translate(robotState.posX, robotState.posY);
    canvas.drawCircle(
      Offset.zero,
      0.3,
      Paint()
        ..color = Colors.blueAccent.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );
    canvas.rotate(-(robotState.heading - pi / 2) % (2.0 * pi));
    canvas.scale(0.5);
    canvas.translate(-0.5, -0.5);
    canvas.drawPath(pathRobot, _robotPaint);
    canvas.restore();
  }

  String get _effectiveCurrentAreaId {
    final progressAreaId = mowingProgressModel.currentAreaId.trim();
    if (progressAreaId.isNotEmpty) {
      return progressAreaId;
    }

    final currentAreaId = robotState.currentAreaId.trim();
    if (currentAreaId.isNotEmpty) {
      return currentAreaId;
    }
    return lastActiveMowingAreaId.trim();
  }

  void _drawCurrentAreaOverlay(Canvas canvas, AreaMowingProgress? progress) {
    final currentAreaId = _effectiveCurrentAreaId;
    if (currentAreaId.isEmpty) {
      return;
    }

    for (final area in mapModel.mowingAreas) {
      if (area.id != currentAreaId) {
        continue;
      }

      canvas.drawPath(area.outline, _currentAreaOverlayPaint);

      if (progress != null) {
        _drawPlannedPaths(canvas, progress);
      }

      return;
    }
  }

  void _drawPlannedPaths(Canvas canvas, AreaMowingProgress progress) {
    final currentPathId = progress.currentPathId.trim();
    final mowedPathIds = progress.mowedPaths
        .map((path) => path.pathId.trim())
        .where((pathId) => pathId.isNotEmpty)
        .toSet();

    for (final path in progress.plannedPaths) {
      final pathShape = _pathFromPoints(path.points);
      if (pathShape == null) {
        continue;
      }

      final isCurrent = currentPathId.isNotEmpty
          ? path.pathId == currentPathId
          : path.index == progress.currentPath;
      final isCompleted = !isCurrent &&
          (mowedPathIds.contains(path.pathId) ||
              progress.mowedPaths.any((mowed) => mowed.index == path.index));

      if (isCurrent) {
        _drawDashedPath(canvas, pathShape, _currentPathPaint, 0.18, 0.10);
      } else if (isCompleted) {
        _drawDashedPath(canvas, pathShape, _completedPathPaint, 0.014, 0.10);
      } else {
        canvas.drawPath(pathShape, _plannedPathPaint);
      }
    }
  }

  Path? _pathFromPoints(List<Offset> points) {
    if (points.isEmpty) {
      return null;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint,
    double dashLength,
    double gapLength,
  ) {
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = min(distance + dashLength, metric.length);
        if (next > distance) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next + gapLength;
      }
    }
  }

  void _drawMowingOverlayLabel(
    Canvas canvas,
    Offset position,
    int order,
    bool enabled,
    double? percent,
  ) {
    final hasProgress = percent != null;
    final textColor = enabled
        ? const Color.fromRGBO(27, 94, 32, 1.0)
        : const Color.fromRGBO(129, 199, 132, 1.0);
    final borderColor = enabled
        ? const Color.fromRGBO(46, 125, 50, 1.0)
        : const Color.fromRGBO(129, 199, 132, 0.85);

    // One stable overlay circle for all mowing areas.
    // Inactive areas show only the mowing order centered in this circle.
    // Active areas use the same circle and split it into order / progress.
    const double radius = 0.58;
    final center = position;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        // Light grey background with 10% opacity so content behind the marker remains visible.
        ..color = const Color.fromARGB(210, 230, 231, 229)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = borderColor
        ..strokeWidth = 0.065
        ..style = PaintingStyle.stroke,
    );

    final orderPainter = TextPainter(
      text: TextSpan(
        text: order.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: hasProgress ? 0.34 : 0.46,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    if (!hasProgress) {
      // No active mowing progress on this area: show only the mowing order
      // exactly in the center of the same circle.
      _paintTextCentered(canvas, orderPainter, center);
      return;
    }

    final dividerY = center.dy;
    canvas.drawLine(
      Offset(center.dx - radius * 0.60, dividerY),
      Offset(center.dx + radius * 0.60, dividerY),
      Paint()
        ..color = textColor.withOpacity(0.75)
        ..strokeWidth = 0.035
        ..style = PaintingStyle.stroke,
    );

    final orderCenter = Offset(center.dx, center.dy - radius / 2.0);
    _paintTextCentered(canvas, orderPainter, orderCenter);

    final percentPainter = TextPainter(
      text: TextSpan(
        text: _formatPercent(percent),
        style: TextStyle(
          color: textColor,
          fontSize: 0.22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 1.65);

    final percentCenter = Offset(center.dx, center.dy + radius / 2.0);
    _paintTextCentered(canvas, percentPainter, percentCenter);
  }

  void _paintTextCentered(Canvas canvas, TextPainter textPainter, Offset center) {
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2.0,
        center.dy + textPainter.height / 3.0,
      ),
    );
  }

  String _formatPercent(double percent) {
    final clamped = percent.clamp(0.0, 100.0).toDouble();
    final decimals = clamped == clamped.roundToDouble() ? 0 : 1;
    return '${clamped.toStringAsFixed(decimals)} %';
  }

  Paint getOverlayPaint(OverlayPolygon overlay) {
    final p = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = overlay.lineWidth;

    switch (overlay.color) {
      case 'red':
        p.color = Colors.red;
        break;
      case 'green':
        p.color = Colors.lightGreenAccent;
        break;
      case 'blue':
        p.color = Colors.blueAccent;
        break;
    }
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is MapPainter) {
      if (oldDelegate.robotState != robotState ||
          oldDelegate.mapModel != mapModel ||
          oldDelegate.mapOverlayModel != mapOverlayModel ||
          oldDelegate.mowingProgressModel != mowingProgressModel ||
          oldDelegate.lastActiveMowingAreaId != lastActiveMowingAreaId) {
        return true;
      }
    }
    return false;
  }
}
