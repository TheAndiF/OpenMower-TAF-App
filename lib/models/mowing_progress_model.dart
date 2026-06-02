import 'dart:ui';

class MowingProgressModel {
  final Map<String, AreaMowingProgress> areas = {};

  AreaMowingProgress? areaById(String areaId) {
    if (areaId.isEmpty) {
      return null;
    }
    return areas[areaId];
  }
}

class AreaMowingProgress {
  AreaMowingProgress({
    required this.areaId,
    required this.percent,
    required this.currentPath,
    required this.currentPathId,
    required this.currentPathIndex,
    required this.plannedPaths,
    required this.mowedPaths,
  });

  final String areaId;
  final double percent;
  final int currentPath;
  final String currentPathId;
  final int currentPathIndex;
  final List<MowingPathProgress> plannedPaths;
  final List<MowingPathProgress> mowedPaths;
}

class MowingPathProgress {
  MowingPathProgress({
    required this.index,
    required this.pathId,
    required this.points,
    this.completedPercent = 0.0,
  });

  final int index;
  final String pathId;
  final List<Offset> points;
  final double completedPercent;
}
