import 'dart:ui';

class MapArea {
  MapArea({
    required this.outline,
    required this.labelPosition,
    this.mowingEnabled = true,
    this.mowingOrder,
  });

  final Path outline;
  final Offset labelPosition;
  final bool mowingEnabled;
  final int? mowingOrder;
}

class MapModel {
  final List<Path> navigationAreas = [];
  final List<MapArea> mowingAreas = [];
  final List<Path> obstacles = [];
  double width = 0,
      height = 0,
      centerX = 0,
      centerY = 0,
      dockX = 0,
      dockY = 0,
      dockHeading = 0;
}
