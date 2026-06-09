import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/models/editable_map_model.dart';


class MapEditorController extends GetxController {
  final MqttAreasController _areasController = Get.find<MqttAreasController>();

  final editMode = false.obs;
  final editableAreas = <EditableMapArea>[].obs;
  final selectedAreaIndex = RxnInt();
  final selectedPointIndex = RxnInt();
  final selectedPointIndices = <int>{}.obs;
  final multiPointSelectionMode = false.obs;
  final hasUnsavedChanges = false.obs;
  final isDraggingPoint = false.obs;
  final showGrid = true.obs;
  final editorStatus = ''.obs;
  final editorRepaintTick = 0.obs;

  final List<List<EditableMapArea>> _undoStack = <List<EditableMapArea>>[];
  Offset? _dragStartWorldPoint;
  final Map<int, EditableMapPoint> _dragStartPoints = <int, EditableMapPoint>{};

  void requestEditorRepaint() {
    editorRepaintTick.value++;
  }

  @override
  void onInit() {
    super.onInit();
    if (_areasController.hasData) {
      loadFromAreaPayload(keepStatus: true);
    }
    ever(_areasController.areaPayload, (_) {
      if (!hasUnsavedChanges.value) {
        loadFromAreaPayload(keepStatus: true);
      }
    });
  }

  bool get hasEditableAreas => editableAreas.isNotEmpty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get hasPointSelection => selectedPointIndices.isNotEmpty || selectedPointIndex.value != null;
  int get selectedPointCount => selectedPointIndices.isNotEmpty ? selectedPointIndices.length : (selectedPointIndex.value == null ? 0 : 1);

  EditableMapArea? get selectedArea {
    final index = selectedAreaIndex.value;
    if (index == null || index < 0 || index >= editableAreas.length) return null;
    return editableAreas[index];
  }

  EditableMapPoint? get selectedPoint {
    final area = selectedArea;
    final index = selectedPointIndex.value;
    if (area == null || index == null || index < 0 || index >= area.outline.length) return null;
    return area.outline[index];
  }

  void loadFromAreaPayload({bool keepStatus = false}) {
    final next = <EditableMapArea>[];
    final root = _areasController.areaPayload;
    final rawAreas = root['areas'];
    if (rawAreas is List) {
      for (var i = 0; i < rawAreas.length; i++) {
        final raw = rawAreas[i];
        if (raw is! Map) continue;
        final area = Map<String, dynamic>.from(raw);
        final properties = area['properties'] is Map
            ? Map<String, dynamic>.from(area['properties'] as Map)
            : const <String, dynamic>{};
        final type = (properties['type'] ?? area['type'] ?? '').toString().trim().toLowerCase();
        if (type != 'mow' && type != 'nav' && type != 'obstacle') continue;

        final outline = _parseOutline(area['outline']);
        if (outline.length < 3) continue;

        next.add(EditableMapArea(
          id: (area['id'] ?? properties['id'] ?? '').toString(),
          type: type,
          sourceIndex: i,
          name: (properties['name'] ?? area['name'] ?? '').toString(),
          outline: outline,
        ));
      }
    }

    editableAreas.assignAll(next);
    selectedAreaIndex.value = null;
    _clearPointSelectionOnly();
    hasUnsavedChanges.value = false;
    isDraggingPoint.value = false;
    _clearDragState();
    _undoStack.clear();
    if (!keepStatus) {
      editorStatus.value = next.isEmpty
          ? 'Keine editierbaren areas[].outline-Polygone gefunden.'
          : '${next.length} editierbare Polygonfläche(n) geladen.';
    }
    requestEditorRepaint();
  }

  void toggleEditMode() {
    if (!editMode.value) {
      if (!hasEditableAreas && _areasController.hasData) {
        loadFromAreaPayload();
      }
      editMode.value = true;
      editorStatus.value = hasEditableAreas
          ? 'Bearbeitungsmodus aktiv. Fläche auswählen, Punkt verschieben oder Mehrfachauswahl nutzen.'
          : 'Bearbeitungsmodus aktiv, aber es sind keine editierbaren Flächen vorhanden.';
      requestEditorRepaint();
      return;
    }
    editMode.value = false;
    isDraggingPoint.value = false;
    _clearPointSelectionOnly();
    editorStatus.value = hasUnsavedChanges.value
        ? 'Bearbeitung pausiert. Ungespeicherte Änderungen bleiben lokal erhalten.'
        : 'Bearbeitungsmodus deaktiviert.';
    requestEditorRepaint();
  }

  bool selectAreaAt(Offset worldPoint) {
    final hit = _findAreaHit(worldPoint);
    if (hit == null) {
      clearAreaSelection();
      return false;
    }
    selectAreaByIndex(hit);
    return true;
  }

  int? areaIndexAt(Offset worldPoint) => _findAreaHit(worldPoint);

  void selectAreaByIndex(int? index) {
    if (index == null || index < 0 || index >= editableAreas.length) {
      clearAreaSelection();
      return;
    }
    selectedAreaIndex.value = index;
    _clearPointSelectionOnly();
    editorStatus.value = '${editableAreas[index].displayName} ausgewählt.';
    requestEditorRepaint();
  }

  void clearAreaSelection() {
    selectedAreaIndex.value = null;
    _clearPointSelectionOnly();
    editorStatus.value = 'Keine Fläche ausgewählt.';
    requestEditorRepaint();
  }

  int? selectPointNear(Offset worldPoint, double toleranceWorld) {
    final area = selectedArea;
    if (area == null) return null;
    final index = _nearestPointIndex(area, worldPoint, toleranceWorld);
    if (index == null) {
      _clearPointSelectionOnly();
      return null;
    }
    selectedPointIndices
      ..clear()
      ..add(index);
    selectedPointIndices.refresh();
    selectedPointIndex.value = index;
    editorStatus.value = 'Punkt ${index + 1} von ${area.outline.length} ausgewählt.';
    requestEditorRepaint();
    return index;
  }

  int? togglePointSelectionNear(Offset worldPoint, double toleranceWorld) {
    final area = selectedArea;
    if (area == null) return null;
    final index = _nearestPointIndex(area, worldPoint, toleranceWorld);
    if (index == null) return null;
    if (selectedPointIndices.contains(index)) {
      selectedPointIndices.remove(index);
      selectedPointIndices.refresh();
      selectedPointIndex.value = selectedPointIndices.isEmpty ? null : _sortedSelectedPointIndices().last;
      editorStatus.value = selectedPointIndices.isEmpty
          ? 'Keine Punkte ausgewählt.'
          : '${selectedPointIndices.length} Punkt(e) ausgewählt.';
    } else {
      selectedPointIndices.add(index);
      selectedPointIndices.refresh();
      selectedPointIndex.value = index;
      editorStatus.value = '${selectedPointIndices.length} Punkt(e) ausgewählt.';
    }
    requestEditorRepaint();
    return index;
  }

  void toggleMultiPointSelectionMode() {
    multiPointSelectionMode.toggle();
    editorStatus.value = multiPointSelectionMode.value
        ? 'Mehrfachauswahl aktiv: Punkte antippen zum Hinzufügen/Entfernen, ausgewählte Punkte gemeinsam ziehen oder löschen.'
        : 'Mehrfachauswahl deaktiviert.';
    requestEditorRepaint();
  }

  void clearPointSelection() {
    _clearPointSelectionOnly();
    editorStatus.value = 'Keine Punkte ausgewählt.';
    requestEditorRepaint();
  }

  bool startPointDrag(Offset worldPoint, double toleranceWorld) {
    if (!editMode.value) return false;
    final area = selectedArea;
    if (area == null) {
      return false;
    }
    final index = _nearestPointIndex(area, worldPoint, toleranceWorld);
    if (index == null) return false;

    if (!selectedPointIndices.contains(index)) {
      if (!multiPointSelectionMode.value) {
        selectedPointIndices.clear();
      }
      selectedPointIndices.add(index);
      selectedPointIndices.refresh();
    }
    selectedPointIndex.value = index;

    final selectedIndices = _sortedSelectedPointIndices()
        .where((pointIndex) => pointIndex >= 0 && pointIndex < area.outline.length)
        .toList(growable: false);
    if (selectedIndices.isEmpty) return false;

    _pushUndoSnapshot();
    _dragStartWorldPoint = worldPoint;
    _dragStartPoints
      ..clear()
      ..addEntries(selectedIndices.map((pointIndex) => MapEntry(pointIndex, area.outline[pointIndex].copy())));
    isDraggingPoint.value = true;
    requestEditorRepaint();
    return true;
  }

  void updateDraggedPoint(Offset displayWorldPoint) {
    if (!isDraggingPoint.value) return;
    final area = selectedArea;
    final dragStartWorldPoint = _dragStartWorldPoint;
    if (area == null || dragStartWorldPoint == null || _dragStartPoints.isEmpty) {
      return;
    }

    final delta = displayWorldPoint - dragStartWorldPoint;
    for (final entry in _dragStartPoints.entries) {
      final pointIndex = entry.key;
      if (pointIndex < 0 || pointIndex >= area.outline.length) continue;
      final startPoint = entry.value;
      area.outline[pointIndex]
        ..x = _rounded(startPoint.x + delta.dx)
        ..y = _rounded(startPoint.y - delta.dy);
    }
    editableAreas.refresh();
    hasUnsavedChanges.value = true;
    requestEditorRepaint();
  }

  void finishPointDrag() {
    if (!isDraggingPoint.value) return;
    isDraggingPoint.value = false;
    final area = selectedArea;
    final count = _dragStartPoints.length;
    _clearDragState();
    if (area != null && count > 0) {
      editorStatus.value = count == 1
          ? 'Punkt in ${area.displayName} lokal verschoben.'
          : '$count Punkte in ${area.displayName} lokal verschoben.';
    }
    requestEditorRepaint();
  }

  bool insertPointNearMidpoint(Offset worldPoint, double toleranceWorld) {
    if (!editMode.value) return false;
    final area = selectedArea;
    if (area == null || area.outline.length < 2) return false;

    for (var i = 0; i < area.outline.length; i++) {
      final current = area.outline[i].displayOffset;
      final next = area.outline[(i + 1) % area.outline.length].displayOffset;
      final midpoint = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
      if ((midpoint - worldPoint).distance <= toleranceWorld) {
        _pushUndoSnapshot();
        area.outline.insert(i + 1, EditableMapPoint(x: _rounded(midpoint.dx), y: _rounded(-midpoint.dy)));
        selectedPointIndices
          ..clear()
          ..add(i + 1);
        selectedPointIndices.refresh();
        selectedPointIndex.value = i + 1;
        editableAreas.refresh();
        hasUnsavedChanges.value = true;
        editorStatus.value = 'Neuer Punkt in ${area.displayName} eingefügt.';
        requestEditorRepaint();
        return true;
      }
    }
    return false;
  }

  bool deleteSelectedPoint() {
    if (!editMode.value) return false;
    final area = selectedArea;
    if (area == null) return false;
    final indices = _sortedSelectedPointIndices()
        .where((index) => index >= 0 && index < area.outline.length)
        .toList(growable: false);
    if (indices.isEmpty) return false;
    if (area.outline.length - indices.length < 3) {
      editorStatus.value = 'Ein Polygon benötigt mindestens drei Punkte. Auswahl kann so nicht gelöscht werden.';
      return false;
    }
    _pushUndoSnapshot();
    for (final index in indices.reversed) {
      area.outline.removeAt(index);
    }
    _clearPointSelectionOnly();
    editableAreas.refresh();
    hasUnsavedChanges.value = true;
    editorStatus.value = indices.length == 1
        ? 'Punkt aus ${area.displayName} gelöscht.'
        : '${indices.length} Punkte aus ${area.displayName} gelöscht.';
    requestEditorRepaint();
    return true;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    final selectedAreaSourceIndex = selectedArea?.sourceIndex;
    editableAreas.assignAll(previous.map((area) => area.copy()).toList(growable: true));
    _clearPointSelectionOnly();
    selectedAreaIndex.value = selectedAreaSourceIndex == null
        ? null
        : editableAreas.indexWhere((area) => area.sourceIndex == selectedAreaSourceIndex);
    if (selectedAreaIndex.value == -1) selectedAreaIndex.value = null;
    hasUnsavedChanges.value = _undoStack.isNotEmpty || _mapDiffersFromPayload();
    editorStatus.value = 'Letzte Kartenänderung zurückgenommen.';
    requestEditorRepaint();
  }

  void discardChanges() {
    loadFromAreaPayload();
    multiPointSelectionMode.value = false;
    editMode.value = false;
    editorStatus.value = 'Lokale Kartenänderungen verworfen.';
    requestEditorRepaint();
  }

  void toggleGridVisibility() {
    showGrid.toggle();
    editorStatus.value = showGrid.value
        ? 'Raster im Karteneditor eingeblendet.'
        : 'Raster im Karteneditor ausgeblendet.';
    requestEditorRepaint();
  }

  void writeBackAndSend() {
    if (!_validateEditorState()) return;
    final next = _deepCopyMap(Map<String, dynamic>.from(_areasController.areaPayload));
    final rawAreas = next['areas'];
    if (rawAreas is! List) {
      editorStatus.value = 'Speichern nicht möglich: areas[] fehlt im aktuellen Payload.';
      return;
    }

    final mutableAreas = List<dynamic>.from(rawAreas);
    for (final area in editableAreas) {
      if (area.sourceIndex < 0 || area.sourceIndex >= mutableAreas.length) continue;
      final raw = mutableAreas[area.sourceIndex];
      if (raw is! Map) continue;
      final mapArea = Map<String, dynamic>.from(raw);
      mapArea['outline'] = area.outline.map((point) => point.toJson()).toList(growable: false);
      mutableAreas[area.sourceIndex] = mapArea;
    }
    next['areas'] = mutableAreas;

    _areasController.areaPayload
      ..clear()
      ..addAll(next);
    _areasController.syncRawJsonFromData();
    hasUnsavedChanges.value = false;
    _undoStack.clear();
    editorStatus.value = 'Kartenpunkte in JSON übernommen. Übertragung an den Server läuft.';
    requestEditorRepaint();
    _areasController.sendMap();
  }

  Rect displayBounds() {
    if (editableAreas.isEmpty) return const Rect.fromLTRB(-7.5, -7.5, 7.5, 7.5);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final area in editableAreas) {
      for (final point in area.outline) {
        final display = point.displayOffset;
        minX = math.min(minX, display.dx);
        minY = math.min(minY, display.dy);
        maxX = math.max(maxX, display.dx);
        maxY = math.max(maxY, display.dy);
      }
    }
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return const Rect.fromLTRB(-7.5, -7.5, 7.5, 7.5);
    }
    if ((maxX - minX).abs() < 0.001) {
      minX -= 7.5;
      maxX += 7.5;
    }
    if ((maxY - minY).abs() < 0.001) {
      minY -= 7.5;
      maxY += 7.5;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  List<EditableMapPoint> _parseOutline(dynamic rawOutline) {
    if (rawOutline is! List) return <EditableMapPoint>[];
    final points = <EditableMapPoint>[];
    for (final rawPoint in rawOutline) {
      if (rawPoint is! Map) continue;
      final x = _toDouble(rawPoint['x']);
      final y = _toDouble(rawPoint['y']);
      if (x == null || y == null) continue;
      points.add(EditableMapPoint(x: x, y: y));
    }
    return points;
  }

  int? _findAreaHit(Offset worldPoint) {
    final indexed = <int>[];
    for (var i = 0; i < editableAreas.length; i++) {
      indexed.add(i);
    }
    indexed.sort((a, b) => _selectionPriority(editableAreas[b].type).compareTo(_selectionPriority(editableAreas[a].type)));
    for (final index in indexed) {
      final path = _pathFor(editableAreas[index]);
      if (path.contains(worldPoint)) return index;
    }
    return null;
  }

  int _selectionPriority(String type) {
    if (type == 'obstacle') return 3;
    if (type == 'mow') return 2;
    if (type == 'nav') return 1;
    return 0;
  }

  Path _pathFor(EditableMapArea area) {
    final path = Path();
    if (area.outline.isEmpty) return path;
    final first = area.outline.first.displayOffset;
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < area.outline.length; i++) {
      final point = area.outline[i].displayOffset;
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  int? _nearestPointIndex(EditableMapArea area, Offset worldPoint, double toleranceWorld) {
    var bestDistance = double.infinity;
    int? bestIndex;
    for (var i = 0; i < area.outline.length; i++) {
      final distance = (area.outline[i].displayOffset - worldPoint).distance;
      if (distance <= toleranceWorld && distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  List<int> _sortedSelectedPointIndices() {
    final indices = selectedPointIndices.toList(growable: false)..sort();
    if (indices.isNotEmpty) return indices;
    final index = selectedPointIndex.value;
    return index == null ? <int>[] : <int>[index];
  }

  void _clearPointSelectionOnly() {
    selectedPointIndices.clear();
    selectedPointIndices.refresh();
    selectedPointIndex.value = null;
  }

  void _clearDragState() {
    _dragStartWorldPoint = null;
    _dragStartPoints.clear();
  }

  void _pushUndoSnapshot() {
    _undoStack.add(editableAreas.map((area) => area.copy()).toList(growable: true));
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  bool _validateEditorState() {
    for (final area in editableAreas) {
      if (area.outline.length < 3) {
        editorStatus.value = 'Speichern nicht möglich: ${area.displayName} hat weniger als drei Punkte.';
        return false;
      }
      for (final point in area.outline) {
        if (!point.x.isFinite || !point.y.isFinite) {
          editorStatus.value = 'Speichern nicht möglich: ${area.displayName} enthält ungültige Koordinaten.';
          return false;
        }
      }
    }
    return true;
  }

  bool _mapDiffersFromPayload() {
    final rootAreas = _areasController.areaPayload['areas'];
    if (rootAreas is! List) return editableAreas.isNotEmpty;
    for (final area in editableAreas) {
      if (area.sourceIndex < 0 || area.sourceIndex >= rootAreas.length) return true;
      final raw = rootAreas[area.sourceIndex];
      if (raw is! Map) return true;
      final sourceOutline = _parseOutline(raw['outline']);
      if (sourceOutline.length != area.outline.length) return true;
      for (var i = 0; i < sourceOutline.length; i++) {
        if ((sourceOutline[i].x - area.outline[i].x).abs() > 0.000001 ||
            (sourceOutline[i].y - area.outline[i].y).abs() > 0.000001) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
    final encoded = jsonEncode(source);
    final decoded = jsonDecode(encoded);
    return Map<String, dynamic>.from(decoded as Map);
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double _rounded(double value) => double.parse(value.toStringAsFixed(6));
}
