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
  final isDraggingReplacementPreview = false.obs;
  final showGrid = true.obs;
  final editorStatus = ''.obs;
  final editorRepaintTick = 0.obs;
  final replacementPreview = Rxn<EditableMapArea>();
  final replacementPreviewShape = ''.obs;
  final replacementPreviewSourceIndex = RxnInt();

  final List<List<EditableMapArea>> _undoStack = <List<EditableMapArea>>[];
  Offset? _dragStartWorldPoint;
  final Map<int, EditableMapPoint> _dragStartPoints = <int, EditableMapPoint>{};
  Offset? _previewDragStartWorldPoint;
  final List<EditableMapPoint> _previewDragStartPoints = <EditableMapPoint>[];

  void requestEditorRepaint() {
    editorRepaintTick.value++;
    editorRepaintTick.refresh();
  }

  @override
  void onInit() {
    super.onInit();
    if (_areasController.hasData) {
      loadFromAreaPayload(keepStatus: true);
    }
    ever(_areasController.areaPayload, (_) {
      if (!hasUnsavedChanges.value && !hasReplacementPreview) {
        loadFromAreaPayload(keepStatus: true);
      }
    });
  }

  bool get hasEditableAreas => editableAreas.isNotEmpty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get hasPointSelection => selectedPointIndices.isNotEmpty || selectedPointIndex.value != null;
  bool get hasReplacementPreview => replacementPreview.value != null;
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
          active: _parseActive(properties['active'] ?? area['active'], defaultValue: true),
          description: (properties['description'] ?? area['description'] ?? '').toString(),
          outline: outline,
        ));
      }
    }

    editableAreas.assignAll(next);
    selectedAreaIndex.value = null;
    _clearPointSelectionOnly();
    _clearReplacementPreviewOnly();
    hasUnsavedChanges.value = false;
    isDraggingPoint.value = false;
    isDraggingReplacementPreview.value = false;
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
          ? 'Bearbeitungsmodus aktiv. Fläche auswählen, Punkt verschieben oder Obstacle-Werkzeuge nutzen.'
          : 'Bearbeitungsmodus aktiv, aber es sind keine editierbaren Flächen vorhanden.';
      requestEditorRepaint();
      return;
    }
    editMode.value = false;
    isDraggingPoint.value = false;
    isDraggingReplacementPreview.value = false;
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
    if (hasReplacementPreview && index != null) {
      final sourceAreaIndex = _areaIndexForSourceIndex(replacementPreviewSourceIndex.value);
      if (sourceAreaIndex != index) {
        editorStatus.value = 'Bitte die Ersatzgeometrie zuerst übernehmen oder verwerfen.';
        requestEditorRepaint();
        return;
      }
    }
    if (index == null || index < 0 || index >= editableAreas.length) {
      clearAreaSelection();
      return;
    }
    selectedAreaIndex.value = index;
    _clearPointSelectionOnly();
    final area = editableAreas[index];
    final activeSuffix = area.isObstacle ? (area.active ? ' Aktiv.' : ' Inaktiv.') : '';
    editorStatus.value = '${area.displayName} ausgewählt.$activeSuffix';
    requestEditorRepaint();
  }

  void clearAreaSelection() {
    if (hasReplacementPreview) {
      editorStatus.value = 'Bitte die Ersatzgeometrie zuerst übernehmen oder verwerfen.';
      requestEditorRepaint();
      return;
    }
    selectedAreaIndex.value = null;
    _clearPointSelectionOnly();
    editorStatus.value = 'Keine Fläche ausgewählt.';
    requestEditorRepaint();
  }

  int? selectPointNear(Offset worldPoint, double toleranceWorld) {
    if (hasReplacementPreview) return null;
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
    if (hasReplacementPreview) return null;
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
    if (hasReplacementPreview) {
      editorStatus.value = 'Mehrfachauswahl ist während der Ersatzgeometrie-Vorschau deaktiviert.';
      return;
    }
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
    if (!editMode.value || hasReplacementPreview) return false;
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
    if (!editMode.value || hasReplacementPreview) return false;
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
    if (!editMode.value || hasReplacementPreview) return false;
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

  bool toggleSelectedObstacleActive() {
    if (!editMode.value) return false;
    if (hasReplacementPreview) {
      editorStatus.value = 'Bitte die Ersatzgeometrie zuerst übernehmen oder verwerfen.';
      return false;
    }
    final area = selectedArea;
    if (area == null || !area.isObstacle) {
      editorStatus.value = 'Bitte zuerst ein Obstacle auswählen.';
      return false;
    }

    _pushUndoSnapshot();
    area.active = !area.active;
    editableAreas.refresh();
    hasUnsavedChanges.value = true;
    editorStatus.value = area.active
        ? 'Obstacle „${area.displayName}“ aktiviert.'
        : 'Obstacle „${area.displayName}“ deaktiviert.';
    requestEditorRepaint();
    return true;
  }

  bool createReplacementPreview({String shape = 'auto'}) {
    if (!editMode.value) return false;
    final area = selectedArea;
    if (area == null || !area.isObstacle) {
      editorStatus.value = 'Bitte zuerst ein Obstacle auswählen.';
      return false;
    }
    if (area.outline.length < 3) {
      editorStatus.value = 'Für eine Ersatzgeometrie benötigt das Obstacle mindestens drei Punkte.';
      return false;
    }

    final normalizedShape = shape.toLowerCase().trim();
    final useCapsule = normalizedShape == 'capsule' ||
        normalizedShape == 'langloch' ||
        (normalizedShape == 'auto' && _looksLikeCapsule(area.outline));
    final previewShape = useCapsule ? 'capsule' : 'circle';
    final previewOutline = useCapsule ? _buildCapsuleOutline(area.outline) : _buildCircleOutline(area.outline);
    if (previewOutline.length < 3) {
      editorStatus.value = 'Ersatzgeometrie konnte aus der aktuellen Kontur nicht berechnet werden.';
      return false;
    }

    replacementPreview.value = EditableMapArea(
      id: 'replacement_preview',
      type: 'obstacle',
      sourceIndex: -1,
      name: 'Ersatzgeometrie Vorschau',
      active: true,
      outline: previewOutline,
    );
    replacementPreviewShape.value = previewShape;
    replacementPreviewSourceIndex.value = area.sourceIndex;
    _clearPointSelectionOnly();
    editorStatus.value = previewShape == 'capsule'
        ? 'Langloch-Vorschau erzeugt. Alte und neue Kontur vergleichen, dann skalieren/verschieben oder übernehmen.'
        : 'Kreis-Vorschau erzeugt. Alte und neue Kontur vergleichen, dann skalieren/verschieben oder übernehmen.';
    requestEditorRepaint();
    return true;
  }

  bool acceptReplacementPreview() {
    final preview = replacementPreview.value;
    final sourceIndex = replacementPreviewSourceIndex.value;
    if (preview == null || sourceIndex == null) {
      editorStatus.value = 'Keine Ersatzgeometrie-Vorschau vorhanden.';
      return false;
    }
    final sourceAreaIndex = _areaIndexForSourceIndex(sourceIndex);
    if (sourceAreaIndex == null) {
      editorStatus.value = 'Herkunftsgeometrie zur Vorschau wurde nicht gefunden.';
      return false;
    }
    final sourceArea = editableAreas[sourceAreaIndex];
    if (!sourceArea.isObstacle) {
      editorStatus.value = 'Ersatzgeometrien können nur für Obstacles übernommen werden.';
      return false;
    }

    _pushUndoSnapshot();
    final date = _todayIsoDate();
    final newId = _newReplacementObstacleId(sourceArea.id);
    final shapeLabel = replacementPreviewShape.value == 'capsule' ? 'capsule' : 'circle';
    final replacement = EditableMapArea(
      id: newId,
      type: 'obstacle',
      sourceIndex: -1,
      name: newId,
      active: true,
      description: 'Generated replacement geometry from obstacle ${sourceArea.id} on $date. Shape: $shapeLabel.',
      outline: preview.outline.map((point) => point.copy()).toList(growable: true),
    );

    sourceArea.active = false;
    sourceArea.description = _appendDescriptionLine(
      sourceArea.description,
      'Inactive source geometry. Replaced by obstacle $newId on $date.',
    );

    editableAreas.add(replacement);
    selectedAreaIndex.value = editableAreas.length - 1;
    _clearPointSelectionOnly();
    _clearReplacementPreviewOnly();
    editableAreas.refresh();
    hasUnsavedChanges.value = true;
    editorStatus.value = 'Ersatzgeometrie übernommen. Die neue Geometrie ist aktiv und kann normal weiterbearbeitet werden.';
    requestEditorRepaint();
    return true;
  }

  void discardReplacementPreview() {
    if (!hasReplacementPreview) return;
    _clearReplacementPreviewOnly();
    editorStatus.value = 'Ersatzgeometrie-Vorschau verworfen. Die Herkunftsgeometrie bleibt unverändert.';
    requestEditorRepaint();
  }

  bool scaleActiveObstacleGeometry(double factor) {
    if (!editMode.value || factor <= 0 || !factor.isFinite) return false;

    final preview = replacementPreview.value;
    if (preview != null) {
      _scaleOutline(preview.outline, factor);
      replacementPreview.refresh();
      editorStatus.value = 'Ersatzgeometrie-Vorschau mit Faktor ${factor.toStringAsFixed(3)} skaliert.';
      requestEditorRepaint();
      return true;
    }

    final area = selectedArea;
    if (area == null || !area.isObstacle) {
      editorStatus.value = 'Bitte zuerst ein Obstacle auswählen.';
      return false;
    }
    _pushUndoSnapshot();
    _scaleOutline(area.outline, factor);
    editableAreas.refresh();
    hasUnsavedChanges.value = true;
    editorStatus.value = 'Obstacle „${area.displayName}“ mit Faktor ${factor.toStringAsFixed(3)} skaliert.';
    requestEditorRepaint();
    return true;
  }

  bool moveActiveObstacleGeometryBy(double dx, double dy) {
    if (!editMode.value || !dx.isFinite || !dy.isFinite) return false;
    if (dx == 0 && dy == 0) return false;

    final preview = replacementPreview.value;
    if (preview != null) {
      _moveOutline(preview.outline, dx, dy);
      replacementPreview.refresh();
      editorStatus.value = 'Ersatzgeometrie-Vorschau um x ${dx.toStringAsFixed(3)} / y ${dy.toStringAsFixed(3)} m verschoben.';
      requestEditorRepaint();
      return true;
    }

    final area = selectedArea;
    if (area == null || !area.isObstacle) {
      editorStatus.value = 'Bitte zuerst ein Obstacle auswählen.';
      return false;
    }

    _pushUndoSnapshot();
    _moveOutline(area.outline, dx, dy);
    editableAreas.refresh();
    hasUnsavedChanges.value = true;
    editorStatus.value = 'Obstacle „${area.displayName}“ um x ${dx.toStringAsFixed(3)} / y ${dy.toStringAsFixed(3)} m verschoben.';
    requestEditorRepaint();
    return true;
  }

  bool startReplacementPreviewDrag(Offset worldPoint, double toleranceWorld) {
    final preview = replacementPreview.value;
    if (!editMode.value || preview == null) return false;
    final center = _displayCenterOf(preview.outline);
    final hitCenter = (center - worldPoint).distance <= toleranceWorld * 1.4;
    final hitPreview = _pathFor(preview).contains(worldPoint);
    if (!hitCenter && !hitPreview) return false;

    _previewDragStartWorldPoint = worldPoint;
    _previewDragStartPoints
      ..clear()
      ..addAll(preview.outline.map((point) => point.copy()));
    isDraggingReplacementPreview.value = true;
    requestEditorRepaint();
    return true;
  }

  void updateReplacementPreviewDrag(Offset displayWorldPoint) {
    if (!isDraggingReplacementPreview.value) return;
    final preview = replacementPreview.value;
    final start = _previewDragStartWorldPoint;
    if (preview == null || start == null || _previewDragStartPoints.length != preview.outline.length) return;

    final delta = displayWorldPoint - start;
    for (var i = 0; i < preview.outline.length; i++) {
      final startPoint = _previewDragStartPoints[i];
      preview.outline[i]
        ..x = _rounded(startPoint.x + delta.dx)
        ..y = _rounded(startPoint.y - delta.dy);
    }
    replacementPreview.refresh();
    requestEditorRepaint();
  }

  void finishReplacementPreviewDrag() {
    if (!isDraggingReplacementPreview.value) return;
    isDraggingReplacementPreview.value = false;
    _previewDragStartWorldPoint = null;
    _previewDragStartPoints.clear();
    editorStatus.value = 'Ersatzgeometrie-Vorschau verschoben.';
    requestEditorRepaint();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _clearReplacementPreviewOnly();
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
    if (hasReplacementPreview) {
      editorStatus.value = 'Speichern nicht möglich: Bitte die Ersatzgeometrie zuerst übernehmen oder verwerfen.';
      return;
    }
    if (!_validateEditorState()) return;
    final next = _deepCopyMap(Map<String, dynamic>.from(_areasController.areaPayload));
    final rawAreas = next['areas'];
    if (rawAreas is! List) {
      editorStatus.value = 'Speichern nicht möglich: areas[] fehlt im aktuellen Payload.';
      return;
    }

    final mutableAreas = List<dynamic>.from(rawAreas);
    for (final area in editableAreas) {
      if (area.sourceIndex >= 0 && area.sourceIndex < mutableAreas.length) {
        final raw = mutableAreas[area.sourceIndex];
        if (raw is! Map) continue;
        final mapArea = Map<String, dynamic>.from(raw);
        mapArea['outline'] = area.outline.map((point) => point.toJson()).toList(growable: false);
        mapArea['properties'] = _propertiesForExistingMapArea(mapArea, area);
        mutableAreas[area.sourceIndex] = mapArea;
      } else {
        area.sourceIndex = mutableAreas.length;
        mutableAreas.add(_mapAreaForNewEditableArea(area));
      }
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
    final allOutlines = <List<EditableMapPoint>>[
      for (final area in editableAreas) area.outline,
      if (replacementPreview.value != null) replacementPreview.value!.outline,
    ];
    if (allOutlines.isEmpty) return const Rect.fromLTRB(-7.5, -7.5, 7.5, 7.5);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final outline in allOutlines) {
      for (final point in outline) {
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
    indexed.sort((a, b) => _hitTestCompare(editableAreas[a], editableAreas[b], a, b));
    for (final index in indexed) {
      final path = _pathFor(editableAreas[index]);
      if (path.contains(worldPoint)) return index;
    }
    return null;
  }

  int _hitTestCompare(EditableMapArea a, EditableMapArea b, int indexA, int indexB) {
    final layerCompare = _hitTestLayer(b).compareTo(_hitTestLayer(a));
    if (layerCompare != 0) return layerCompare;

    final areaCompare = _displayPolygonArea(a.outline).compareTo(_displayPolygonArea(b.outline));
    if (areaCompare != 0) return areaCompare;

    // Later-created replacement geometries usually sit visually above their source.
    return indexB.compareTo(indexA);
  }

  int _hitTestLayer(EditableMapArea area) {
    if (area.type == 'obstacle' && area.active) return 4;
    if (area.type == 'obstacle') return 3;
    if (area.type == 'mow') return 2;
    if (area.type == 'nav') return 1;
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

  void _clearReplacementPreviewOnly() {
    replacementPreview.value = null;
    replacementPreviewShape.value = '';
    replacementPreviewSourceIndex.value = null;
    isDraggingReplacementPreview.value = false;
    _previewDragStartWorldPoint = null;
    _previewDragStartPoints.clear();
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
      final rawMap = Map<String, dynamic>.from(raw);
      final rawProperties = rawMap['properties'] is Map
          ? Map<String, dynamic>.from(rawMap['properties'] as Map)
          : const <String, dynamic>{};
      final sourceActive = _parseActive(rawProperties['active'] ?? rawMap['active'], defaultValue: true);
      final sourceDescription = (rawProperties['description'] ?? rawMap['description'] ?? '').toString();
      if (sourceActive != area.active) return true;
      if (sourceDescription != area.description) return true;

      final sourceOutline = _parseOutline(rawMap['outline']);
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

  Map<String, dynamic> _propertiesForExistingMapArea(Map<String, dynamic> mapArea, EditableMapArea area) {
    final properties = mapArea['properties'] is Map
        ? Map<String, dynamic>.from(mapArea['properties'] as Map)
        : <String, dynamic>{};
    properties['type'] = area.type;
    if (area.name.trim().isNotEmpty) {
      properties['name'] = area.name;
    }
    properties['active'] = area.active;
    if (area.description.trim().isNotEmpty) {
      properties['description'] = area.description.trim();
    } else {
      properties.remove('description');
    }
    return properties;
  }

  Map<String, dynamic> _mapAreaForNewEditableArea(EditableMapArea area) {
    final properties = <String, dynamic>{
      'type': area.type,
      'name': area.name.trim().isNotEmpty ? area.name : area.id,
      'active': area.active,
    };
    if (area.isObstacle) {
      properties['mowing_enabled'] = false;
      properties['mowing_order'] = 0;
    }
    if (area.description.trim().isNotEmpty) {
      properties['description'] = area.description.trim();
    }
    return <String, dynamic>{
      'id': area.id,
      'properties': properties,
      'outline': area.outline.map((point) => point.toJson()).toList(growable: false),
    };
  }

  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
    final encoded = jsonEncode(source);
    final decoded = jsonDecode(encoded);
    return Map<String, dynamic>.from(decoded as Map);
  }

  bool _parseActive(dynamic value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1' || normalized == 'active') return true;
    if (normalized == 'false' || normalized == 'no' || normalized == '0' || normalized == 'inactive' || normalized == 'disabled') return false;
    return defaultValue;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _looksLikeCapsule(List<EditableMapPoint> outline) {
    final stats = _principalAxisStats(outline);
    if (stats == null) return false;
    final width = math.max(stats.width, 0.001);
    final ratio = stats.length / width;
    return ratio >= 1.35;
  }

  List<EditableMapPoint> _buildCircleOutline(List<EditableMapPoint> outline, {int segments = 32}) {
    final center = _coordinateCenterOf(outline);
    var radius = 0.0;
    for (final point in outline) {
      radius = math.max(radius, math.sqrt(math.pow(point.x - center.dx, 2) + math.pow(point.y - center.dy, 2)));
    }
    if (!radius.isFinite || radius <= 0) return <EditableMapPoint>[];
    return List<EditableMapPoint>.generate(segments, (index) {
      final angle = 2 * math.pi * index / segments;
      return EditableMapPoint(
        x: _rounded(center.dx + math.cos(angle) * radius),
        y: _rounded(center.dy + math.sin(angle) * radius),
      );
    }, growable: true);
  }

  List<EditableMapPoint> _buildCapsuleOutline(List<EditableMapPoint> outline, {int capSegments = 16}) {
    final stats = _principalAxisStats(outline);
    if (stats == null) return _buildCircleOutline(outline);
    final radius = math.max(stats.width / 2, 0.05);
    final halfLength = stats.length / 2;
    final straightHalfLength = math.max(0.0, halfLength - radius);
    if (straightHalfLength <= 0.001) return _buildCircleOutline(outline);

    final points = <EditableMapPoint>[];
    for (var i = 0; i <= capSegments; i++) {
      final angle = -math.pi / 2 + math.pi * i / capSegments;
      points.add(_capsuleLocalToPoint(stats, straightHalfLength + math.cos(angle) * radius, math.sin(angle) * radius));
    }
    for (var i = 0; i <= capSegments; i++) {
      final angle = math.pi / 2 + math.pi * i / capSegments;
      points.add(_capsuleLocalToPoint(stats, -straightHalfLength + math.cos(angle) * radius, math.sin(angle) * radius));
    }
    return points;
  }

  EditableMapPoint _capsuleLocalToPoint(_AxisStats stats, double major, double minor) {
    return EditableMapPoint(
      x: _rounded(stats.center.dx + stats.majorAxis.dx * major + stats.minorAxis.dx * minor),
      y: _rounded(stats.center.dy + stats.majorAxis.dy * major + stats.minorAxis.dy * minor),
    );
  }

  _AxisStats? _principalAxisStats(List<EditableMapPoint> outline) {
    if (outline.length < 3) return null;
    final mean = _coordinateCenterOf(outline);
    var covarianceXX = 0.0;
    var covarianceYY = 0.0;
    var covarianceXY = 0.0;
    for (final point in outline) {
      final dx = point.x - mean.dx;
      final dy = point.y - mean.dy;
      covarianceXX += dx * dx;
      covarianceYY += dy * dy;
      covarianceXY += dx * dy;
    }

    final angle = 0.5 * math.atan2(2 * covarianceXY, covarianceXX - covarianceYY);
    final majorAxis = Offset(math.cos(angle), math.sin(angle));
    final minorAxis = Offset(-math.sin(angle), math.cos(angle));

    var minMajor = double.infinity;
    var maxMajor = double.negativeInfinity;
    var minMinor = double.infinity;
    var maxMinor = double.negativeInfinity;
    for (final point in outline) {
      final dx = point.x - mean.dx;
      final dy = point.y - mean.dy;
      final major = dx * majorAxis.dx + dy * majorAxis.dy;
      final minor = dx * minorAxis.dx + dy * minorAxis.dy;
      minMajor = math.min(minMajor, major);
      maxMajor = math.max(maxMajor, major);
      minMinor = math.min(minMinor, minor);
      maxMinor = math.max(maxMinor, minor);
    }
    if (!minMajor.isFinite || !maxMajor.isFinite || !minMinor.isFinite || !maxMinor.isFinite) return null;

    final centerMajor = (minMajor + maxMajor) / 2;
    final centerMinor = (minMinor + maxMinor) / 2;
    final center = Offset(
      mean.dx + majorAxis.dx * centerMajor + minorAxis.dx * centerMinor,
      mean.dy + majorAxis.dy * centerMajor + minorAxis.dy * centerMinor,
    );
    return _AxisStats(
      center: center,
      majorAxis: majorAxis,
      minorAxis: minorAxis,
      length: maxMajor - minMajor,
      width: maxMinor - minMinor,
    );
  }

  void _scaleOutline(List<EditableMapPoint> outline, double factor) {
    if (outline.isEmpty) return;
    final center = _coordinateCenterOf(outline);
    for (final point in outline) {
      point
        ..x = _rounded(center.dx + (point.x - center.dx) * factor)
        ..y = _rounded(center.dy + (point.y - center.dy) * factor);
    }
  }

  void _moveOutline(List<EditableMapPoint> outline, double dx, double dy) {
    for (final point in outline) {
      point
        ..x = _rounded(point.x + dx)
        ..y = _rounded(point.y + dy);
    }
  }

  double _displayPolygonArea(List<EditableMapPoint> outline) {
    if (outline.length < 3) return double.infinity;
    var twiceArea = 0.0;
    for (var i = 0; i < outline.length; i++) {
      final current = outline[i].displayOffset;
      final next = outline[(i + 1) % outline.length].displayOffset;
      twiceArea += current.dx * next.dy - next.dx * current.dy;
    }
    final area = (twiceArea / 2).abs();
    return area.isFinite ? area : double.infinity;
  }

  Offset _coordinateCenterOf(List<EditableMapPoint> outline) {
    if (outline.isEmpty) return Offset.zero;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final point in outline) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  Offset _displayCenterOf(List<EditableMapPoint> outline) {
    final center = _coordinateCenterOf(outline);
    return Offset(center.dx, -center.dy);
  }

  int? _areaIndexForSourceIndex(int? sourceIndex) {
    if (sourceIndex == null) return null;
    final index = editableAreas.indexWhere((area) => area.sourceIndex == sourceIndex);
    return index < 0 ? null : index;
  }

  String _newReplacementObstacleId(String sourceId) {
    final trimmedSourceId = sourceId.trim();
    final rootId = trimmedSourceId.isEmpty
        ? 'obstacle'
        : trimmedSourceId.replaceFirst(RegExp(r'_re\d{2}$'), '');
    final existingIds = editableAreas.map((area) => area.id.trim()).toSet();

    for (var number = 1; number <= 99; number++) {
      final candidate = '${rootId}_re${number.toString().padLeft(2, '0')}';
      if (!existingIds.contains(candidate)) return candidate;
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '${rootId}_re$timestamp';
  }

  String _appendDescriptionLine(String existing, String nextLine) {
    final trimmedExisting = existing.trim();
    if (trimmedExisting.isEmpty) return nextLine;
    if (trimmedExisting.contains(nextLine)) return trimmedExisting;
    return '$trimmedExisting\n$nextLine';
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  double _rounded(double value) => double.parse(value.toStringAsFixed(6));
}

class _AxisStats {
  _AxisStats({
    required this.center,
    required this.majorAxis,
    required this.minorAxis,
    required this.length,
    required this.width,
  });

  final Offset center;
  final Offset majorAxis;
  final Offset minorAxis;
  final double length;
  final double width;
}
