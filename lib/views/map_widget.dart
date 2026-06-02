import 'package:flutter/material.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

import 'package:open_mower_app/models/map_model.dart';
import 'package:open_mower_app/models/map_overlay_model.dart';
import 'package:open_mower_app/models/mowing_progress_model.dart';
import 'package:open_mower_app/models/robot_state.dart';

class MapWidget extends GetView<RobotStateController> {
  const MapWidget({super.key, required this.centerOnRobot});

  final bool centerOnRobot;

  // load the image async and then draw with `canvas.drawImage(image, Offset.zero, Paint());`
  Future<ui.Image> loadImageAsset(String assetName) async {
    final data = await rootBundle.load(assetName);
    return decodeImageFromList(data.buffer.asUint8List());
  }

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
                child: Obx(() => CustomPaint(
                      isComplex: true,
                      painter: MapPainter(
                          controller.map.value,
                          controller.mapOverlay.value,
                          controller.mowingProgress.value,
                          controller.robotState.value,
                          centerOnRobot),
                    )))));
  }
}

class MapPainter extends CustomPainter {
  MapPainter(this.mapModel, this.mapOverlayModel, this.mowingProgressModel,
      this.robotState, this.centerOnRobot) {
    // "robot" arrow
    path_0.reset();
    path_0.moveTo(0.1979167, 0.8750000);
    path_0.lineTo(0.1666667, 0.8437500);
    path_0.lineTo(0.5000000, 0.08333333);
    path_0.lineTo(0.8333333, 0.8437500);
    path_0.lineTo(0.8020833, 0.8750000);
    path_0.lineTo(0.5000000, 0.7375000);

    path_0.moveTo(0.5000000, 0.6708333);
    path_0.close();

    // "home" icon

    path_1.moveTo(0.2291667, 0.8125000);
    path_1.lineTo(0.3854167, 0.8125000);
    path_1.lineTo(0.3854167, 0.5520833);
    path_1.lineTo(0.6145833, 0.5520833);
    path_1.lineTo(0.6145833, 0.8125000);
    path_1.lineTo(0.7708333, 0.8125000);
    path_1.lineTo(0.7708333, 0.4062500);
    path_1.lineTo(0.5000000, 0.2031250);
    path_1.lineTo(0.2291667, 0.4062500);
    path_1.close();
    path_1.moveTo(0.1666667, 0.8750000);
    path_1.lineTo(0.1666667, 0.3750000);
    path_1.lineTo(0.5000000, 0.1250000);
    path_1.lineTo(0.8333333, 0.3750000);
    path_1.lineTo(0.8333333, 0.8750000);
    path_1.lineTo(0.5520833, 0.8750000);
    path_1.lineTo(0.5520833, 0.6145833);
    path_1.lineTo(0.4479167, 0.6145833);
    path_1.lineTo(0.4479167, 0.8750000);
    path_1.close();
    path_1.moveTo(0.5000000, 0.5072917);
    path_1.close();
  }

  final MapModel mapModel;
  final MapOverlayModel mapOverlayModel;
  final MowingProgressModel mowingProgressModel;
  final RobotState robotState;
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
    // Disabled mowing areas are shown in green with 60% opacity.
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
  final _pathDashPaint = Paint()
    ..strokeWidth = 0.035
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

  final Path path_0 = Path();
  final Path path_1 = Path();

  @override
  void paint(Canvas canvas, Size size) {
    // print("map paint");
    final backgroundRect = Offset.zero & size;

    final drawingRect =
        Rect.fromLTRB(25, 150, size.width - 25, size.height - 25);

    canvas.drawRect(backgroundRect, _backgroundPaint);
    // backgroundPattern.paintOnRect(canvas, backgroundRect.size, backgroundRect);

/*
    canvas.drawRect(
        backgroundRect,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill);
    canvas.drawRect(
        drawingRect,
        Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.fill);

    canvas.drawLine(
        drawingRect.topLeft,
        drawingRect.bottomRight,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    canvas.drawLine(
        drawingRect.topRight,
        drawingRect.bottomLeft,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
*/

    // don't try to draw map if it has size 0

    double mapWidth = max(mapModel.width, 15);
    double mapHeight = max(mapModel.height, 15);


    double mapScale = 80;

    if (!centerOnRobot) {
      mapScale = min(drawingRect.width / mapWidth,
          drawingRect.height / mapHeight);
    }

    canvas.translate(
        drawingRect.topLeft.dx +
            (drawingRect.width - mapWidth * mapScale) / 2.0,
        drawingRect.topLeft.dy +
            (drawingRect.height - mapHeight * mapScale) / 2.0);


    canvas.scale(mapScale);

    /* draw map outline
    canvas.drawRect(
        // Rect.fromCenter(
        //     center: Offset(mapModel.centerX, mapModel.centerY),
        //     width: mapWidth,
        //     height: mapHeight),
        Offset(0,0) & Size(mapWidth, mapHeight),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 0.1
          ..style = PaintingStyle.stroke);
    */

    if (!centerOnRobot) {
      // fit map to the center
      canvas.translate(mapWidth / 2 - mapModel.centerX,
          mapHeight / 2 - mapModel.centerY);
    } else {
      // center on robot
      canvas.translate(mapWidth / 2 - robotState.posX,
          mapHeight / 2 - robotState.posY);
      // canvas.rotate((robotState.heading - pi/2) % (2.0*pi));
      // canvas.translate(, );
    }

    final startX = ((-mapWidth / 2 +
                    mapModel.centerX -
                    (drawingRect.topLeft.dx +
                            (drawingRect.width - mapWidth * mapScale) /
                                2.0) /
                        mapScale) /
                5)
            .round() *
        5;
    final startY = ((-(mapHeight / 2 - mapModel.centerY) -
                    (drawingRect.topLeft.dy +
                            (drawingRect.height - mapHeight * mapScale) /
                                2.0) /
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
    canvas.drawCircle(Offset.zero, 0.5,
        _coordinateLinesPaintOrigin..style = PaintingStyle.fill);

/*
    for (final area in mapModel.mowingAreas) {
      canvas.drawShadow(area.outline, Colors.black, 5, false);
    }
    for (final area in mapModel.navigationAreas) {
      canvas.drawShadow(area.outline, Colors.black, 5, false);
    }
*/

    //
    // for(final area in mapModel.navigationAreas) {
    //   shadowPath = Path.combine(PathOperation.union, shadowPath, area.outline);
    // }
    //
    // remove all obstacles
    // for(final area in mapModel.mowingAreas) {
    //   for(final obstacle in area.obstacles) {
    //     shadowPath =
    //         Path.combine(PathOperation.difference, shadowPath, obstacle);
    //   }
    // }
    //
    // for(final area in mapModel.navigationAreas) {
    //   for(final obstacle in area.obstacles) {
    //     shadowPath =
    //         Path.combine(PathOperation.difference, shadowPath, obstacle);
    //   }
    // }

    //

    for (final area in mapModel.navigationAreas) {
      canvas.drawPath(area, _navigationFillPaint);
      canvas.drawPath(area, _mowOutlinePaint);
    }

    for (final area in mapModel.mowingAreas) {
      final fillPaint =
          area.mowingEnabled ? _mowFillPaint : _mowDisabledFillPaint;
      final outlinePaint =
          area.mowingEnabled ? _mowOutlinePaint : _mowDisabledOutlinePaint;

      canvas.drawPath(area.outline, fillPaint);
      // grassPattern.paintOnPath(canvas, Size(mapWidth, mapHeight), area.outline);
      canvas.drawPath(area.outline, outlinePaint);
    }

    _drawCurrentAreaOverlay(canvas);

    for (final path in mapModel.obstacles) {
      canvas.drawPath(path, _obstaclePaint);
    }

    // draw dock
    {
      canvas.save();
      canvas.translate(mapModel.dockX, mapModel.dockY);
      canvas.drawCircle(
          Offset.zero,
          0.3,
          Paint()
            ..color = Colors.greenAccent.withOpacity(0.4)
            ..style = PaintingStyle.fill);
      // canvas.rotate(-(mapModel.dockHeading - pi / 2) % (2.0 * pi));
      canvas.scale(0.5);
      canvas.translate(-0.5, -0.5);
      canvas.drawPath(path_1, _robotPaint);
      canvas.restore();
    }

    // draw overlays
    for (final overlay in mapOverlayModel.polygons) {
      canvas.drawPath(overlay.overlay, getOverlayPaint(overlay));
    }

    // Draw robot icon
    {
      canvas.translate(robotState.posX, robotState.posY);
      // canvas.drawCircle(Offset.zero, 0.3, Paint()..color = Colors.blueAccent.withOpacity(0.8) ..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset.zero,
          0.3,
          Paint()
            ..color = Colors.blueAccent.withOpacity(0.4)
            ..style = PaintingStyle.fill);

      canvas.rotate(-(robotState.heading - pi / 2) % (2.0 * pi));
      canvas.scale(0.5);
      canvas.translate(-0.5, -0.5);
      canvas.drawPath(path_0, _robotPaint);
    }
  }

  void _drawCurrentAreaOverlay(Canvas canvas) {
    final currentAreaId = robotState.currentAreaId.trim();
    if (currentAreaId.isEmpty) {
      return;
    }

    final progress = mowingProgressModel.areaById(currentAreaId);

    for (final area in mapModel.mowingAreas) {
      if (area.id == currentAreaId) {
        canvas.drawPath(area.outline, _currentAreaOverlayPaint);
        if (progress != null) {
          _drawPlannedPaths(canvas, progress);
        }
        if (area.mowingOrder != null) {
          _drawMowingOrderLabel(
            canvas,
            area.labelPosition,
            area.mowingOrder!,
            area.mowingEnabled,
            progress?.percent,
          );
        }
        return;
      }
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
      final isMowed = !isCurrent &&
          (mowedPathIds.contains(path.pathId) ||
              progress.mowedPaths.any((mowed) => mowed.index == path.index));

      if (isCurrent) {
        _drawDashedPath(canvas, pathShape, _pathDashPaint, 0.02, 0.08);
      } else if (isMowed) {
        _drawDashedPath(canvas, pathShape, _pathDashPaint, 0.18, 0.10);
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

  void _drawMowingOrderLabel(
    Canvas canvas,
    Offset position,
    int order,
    bool enabled,
    double? percent,
  ) {
    final hasProgress = percent != null;
    final double radius = hasProgress ? 0.48 : 0.35;

    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..color = const Color.fromRGBO(255, 255, 255, 0.92)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..color = enabled
            ? const Color.fromRGBO(46, 125, 50, 1.0)
            : const Color.fromRGBO(129, 199, 132, 0.85)
        ..strokeWidth = 0.05
        ..style = PaintingStyle.stroke,
    );

    final textColor = enabled
        ? const Color.fromRGBO(27, 94, 32, 1.0)
        : const Color.fromRGBO(129, 199, 132, 1.0);

    final orderPainter = TextPainter(
      text: TextSpan(
        text: order.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: hasProgress ? 0.34 : 0.42,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    if (!hasProgress) {
      orderPainter.paint(
        canvas,
        position - Offset(orderPainter.width / 2, orderPainter.height / 2),
      );
      return;
    }

    orderPainter.paint(
      canvas,
      Offset(position.dx - orderPainter.width / 2, position.dy - 0.36),
    );

    canvas.drawLine(
      Offset(position.dx - 0.28, position.dy),
      Offset(position.dx + 0.28, position.dy),
      Paint()
        ..color = textColor.withOpacity(0.75)
        ..strokeWidth = 0.025
        ..style = PaintingStyle.stroke,
    );

    final percentPainter = TextPainter(
      text: TextSpan(
        text: _formatPercent(percent),
        style: TextStyle(
          color: textColor,
          fontSize: 0.20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 0.86);

    percentPainter.paint(
      canvas,
      Offset(position.dx - percentPainter.width / 2, position.dy + 0.08),
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
      case "red":
        p.color = Colors.red;
        break;
      case "green":
        p.color = Colors.lightGreenAccent;
        break;
      case "blue":
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
          oldDelegate.mowingProgressModel != mowingProgressModel) {
        // print("new map model, should repaint!");
        return true;
      } else {
        // print("same map model, should NOT repaint!");
      }
    }
    return false;
  }
}
