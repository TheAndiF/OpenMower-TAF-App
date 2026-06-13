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
    required this.currentPathId,
    required this.paths,
    this.state = '',
  });

  final String areaId;
  final double percent;
  final String state;
  final String currentPathId;
  final List<MowingPathProgress> paths;

  AreaMowingProgress copyWith({
    double? percent,
    String? state,
    String? currentPathId,
    List<MowingPathProgress>? paths,
  }) {
    return AreaMowingProgress(
      areaId: areaId,
      percent: percent ?? this.percent,
      state: state ?? this.state,
      currentPathId: currentPathId ?? this.currentPathId,
      paths: paths ?? this.paths,
    );
  }
}

class MowingPathProgress {
  MowingPathProgress({
    required this.index,
    required this.pathId,
    required this.points,
    this.order,
    this.slicerSourcePathId,
    this.pathDirection = '',
    this.mowStatus = '',
    this.currentPoseIndex = 0,
    this.completedPercent = 0.0,
    this.hasGeometry = false,
    this.hasStatus = false,
  });

  final int index;
  final int? order;
  final String pathId;
  final int? slicerSourcePathId;
  final String pathDirection;
  final List<Offset> points;
  final String mowStatus;
  final int currentPoseIndex;
  final double completedPercent;
  final bool hasGeometry;
  final bool hasStatus;

  bool get isRenderable => hasGeometry && hasStatus;
  bool get isCurrent => mowStatus == 'mowing';
  bool get isCompleted => mowStatus == 'mowed';

  MowingPathProgress copyWith({
    int? index,
    int? order,
    String? pathId,
    int? slicerSourcePathId,
    String? pathDirection,
    List<Offset>? points,
    String? mowStatus,
    int? currentPoseIndex,
    double? completedPercent,
    bool? hasGeometry,
    bool? hasStatus,
  }) {
    return MowingPathProgress(
      index: index ?? this.index,
      order: order ?? this.order,
      pathId: pathId ?? this.pathId,
      slicerSourcePathId: slicerSourcePathId ?? this.slicerSourcePathId,
      pathDirection: pathDirection ?? this.pathDirection,
      points: points ?? this.points,
      mowStatus: mowStatus ?? this.mowStatus,
      currentPoseIndex: currentPoseIndex ?? this.currentPoseIndex,
      completedPercent: completedPercent ?? this.completedPercent,
      hasGeometry: hasGeometry ?? this.hasGeometry,
      hasStatus: hasStatus ?? this.hasStatus,
    );
  }
}
