import 'dart:ui';

class EditableMapPoint {
  EditableMapPoint({required this.x, required this.y});

  double x;
  double y;

  Offset get displayOffset => Offset(x, -y);

  EditableMapPoint copy() => EditableMapPoint(x: x, y: y);

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};
}

class EditableMapArea {
  EditableMapArea({
    required this.id,
    required this.type,
    required this.sourceIndex,
    required this.outline,
    this.name = '',
    this.active = true,
    this.description = '',
    this.mowingEnabled,
    this.mowingOrder,
  });

  final String id;
  final String type;
  int sourceIndex;
  final String name;
  final List<EditableMapPoint> outline;
  bool active;
  String description;
  bool? mowingEnabled;
  int? mowingOrder;

  bool get isSupported => type == 'mow' || type == 'nav' || type == 'obstacle';
  bool get isMow => type == 'mow';
  bool get isObstacle => type == 'obstacle';

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedId = id.trim();
    if (trimmedId.isNotEmpty) return trimmedId;
    return type;
  }

  EditableMapArea copy() => EditableMapArea(
        id: id,
        type: type,
        sourceIndex: sourceIndex,
        name: name,
        active: active,
        description: description,
        mowingEnabled: mowingEnabled,
        mowingOrder: mowingOrder,
        outline: outline.map((point) => point.copy()).toList(growable: true),
      );
}
