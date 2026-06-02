import 'dart:ui';

class MowingProgressModel {
  MowingProgressModel({
    this.currentAreaId = '',
    Map<String, AreaMowingProgress>? areas,
  }) {
    if (areas != null) {
      this.areas.addAll(areas);
    }
  }

  final String currentAreaId;
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
    this.state = '',
  });

  final String areaId;
  final double percent;
  final String state;
  final int currentPath;
  final String currentPathId;
  final int currentPathIndex;
  final List<MowingPathProgress> plannedPaths;
  final List<MowingPathProgress> mowedPaths;

  AreaMowingProgress copyWith({
    double? percent,
    String? state,
    int? currentPath,
    String? currentPathId,
    int? currentPathIndex,
    List<MowingPathProgress>? plannedPaths,
    List<MowingPathProgress>? mowedPaths,
  }) {
    return AreaMowingProgress(
      areaId: areaId,
      percent: percent ?? this.percent,
      state: state ?? this.state,
      currentPath: currentPath ?? this.currentPath,
      currentPathId: currentPathId ?? this.currentPathId,
      currentPathIndex: currentPathIndex ?? this.currentPathIndex,
      plannedPaths: plannedPaths ?? this.plannedPaths,
      mowedPaths: mowedPaths ?? this.mowedPaths,
    );
  }
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
