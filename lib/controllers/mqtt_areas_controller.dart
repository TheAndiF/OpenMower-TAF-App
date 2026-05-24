import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class MqttAreasController extends GetxController {
  final areaPayload = <String, dynamic>{}.obs;
  final lastRemarks = <String>[].obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final rawJsonController = TextEditingController();
  final editingAreaIds = <String>{}.obs;

  bool get hasData => areaPayload.isNotEmpty;
  bool get hasActiveAreaEdit => editingAreaIds.isNotEmpty;


  List<Map<String, dynamic>> get areas {
    final value = areaPayload['areas'];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }

    final legacy = areaPayload['working_areas'];
    if (legacy is List) {
      return legacy
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> get mowAreas {
    final filtered = areas.where((area) {
      final props = propertiesFor(area);
      final type = (props['type'] ?? area['type'] ?? '').toString().toLowerCase().trim();
      return type == 'mow';
    }).toList(growable: false);

    final sorted = List<Map<String, dynamic>>.from(filtered);
    sorted.sort((a, b) {
      final propsA = propertiesFor(a);
      final propsB = propertiesFor(b);
      final orderCompare = _mowingOrderFor(propsA).compareTo(_mowingOrderFor(propsB));
      if (orderCompare != 0) return orderCompare;
      return areaNameFor(a).compareTo(areaNameFor(b));
    });
    return sorted;
  }

  String areaIdFor(Map<String, dynamic> area) {
    final props = propertiesFor(area);
    return (area['id'] ?? props['id'] ?? '').toString();
  }

  String areaNameFor(Map<String, dynamic> area) {
    final props = propertiesFor(area);
    final name = (props['name'] ?? area['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final id = areaIdFor(area);
    if (id.isEmpty) return 'Unbenannte Fläche';
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
  }

  bool mowingEnabledFor(Map<String, dynamic> area) {
    final props = propertiesFor(area);
    final value = props['mowing_enabled'] ?? area['mowing_enabled'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().toLowerCase() == 'true';
  }

  int? mowingOrderFor(Map<String, dynamic> area) {
    final props = propertiesFor(area);
    final value = props['mowing_order'] ?? area['mowing_order'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String formatMowingOrder(int? value) {
    if (value == null) {
      return '';
    }
    return value.clamp(1, 99).toString().padLeft(2, '0');
  }

  Map<String, dynamic>? findAreaById(String areaId) {
    final trimmed = areaId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final area in mowAreas) {
      if (areaIdFor(area) == trimmed) {
        return area;
      }
    }
    return null;
  }

  bool isMowingOrderAvailable(String areaId, int order) {
    for (final area in mowAreas) {
      final id = areaIdFor(area);
      if (id == areaId) {
        continue;
      }
      if (mowingOrderFor(area) == order) {
        return false;
      }
    }
    return true;
  }

  int _mowingOrderFor(Map<String, dynamic> props) {
    final value = props['mowing_order'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0x7fffffff;
  }

  String get jsonString {
    if (areaPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(_jsonSafe(areaPayload));
  }

  void setAreaPayload(Map<dynamic, dynamic> payload, {String topic = 'map/json'}) {
    final root = payload['d'] is Map ? Map<dynamic, dynamic>.from(payload['d'] as Map) : payload;
    final normalized = Map<String, dynamic>.from(_jsonSafe(root) as Map);

    areaPayload
      ..clear()
      ..addAll(_deepCopy(normalized));

    editingAreaIds.clear();
    syncRawJsonFromData();
    lastRemarks.clear();
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    lastStatusOk.value = true;
    waitingForResponse.value = false;
    lastStatus.value = areas.isEmpty
        ? 'Flächen empfangen, aber keine Flächenliste gefunden.'
        : '${mowAreas.length} Mähfläche(n) empfangen.';
  }

  void requestMap() {
    Get.find<MqttConnection>().requestMap();
    lastStatus.value = 'Flächen werden vom Server angefordert ...';
    lastTopic.value = 'map/set/renew/json';
    lastStatusOk.value = null;
    waitingForResponse.value = true;
  }

  void sendMap() {
    if (!applyRawJson(setLocalStatus: false)) {
      return;
    }
    syncAndSendMap('Flächen gesendet. Warte auf Serverantwort ...');
  }

  void syncAndSendMap(String statusMessage) {
    syncRawJsonFromData();
    if (!_validateUniqueMowingOrders()) {
      return;
    }
    Get.find<MqttConnection>().publishMap(Map<String, dynamic>.from(areaPayload));
    waitingForResponse.value = true;
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'map/set/json';
    lastStatus.value = statusMessage;
    lastStatusOk.value = null;
  }

  bool applyRawJson({bool setLocalStatus = true}) {
    try {
      final parsed = jsonDecode(rawJsonController.text);
      if (parsed is! Map) {
        setError('JSON muss ein Objekt sein.');
        return false;
      }
      final normalized = Map<String, dynamic>.from(_jsonSafe(parsed) as Map);
      if (normalized['areas'] is! List && normalized['working_areas'] is! List) {
        setError('JSON muss eine Flächenliste unter "areas" enthalten.', topic: 'local/upload');
        return false;
      }
      areaPayload
        ..clear()
        ..addAll(_deepCopy(normalized));
      editingAreaIds.clear();
      syncRawJsonFromData();
      lastUpdated.value = DateTime.now();
      if (setLocalStatus) {
        lastTopic.value = 'local/upload';
        lastStatus.value = 'JSON wurde lokal übernommen. Zum Übertragen an den Server bitte Speichern drücken.';
        lastStatusOk.value = true;
        waitingForResponse.value = false;
      }
      return true;
    } catch (e) {
      setError('JSON ist ungültig: $e', topic: 'local/upload');
      return false;
    }
  }

  bool importJsonString(String jsonText, {String filename = 'Datei'}) {
    rawJsonController.text = jsonText;
    final ok = applyRawJson();
    if (ok) {
      lastStatus.value = 'JSON-Datei "$filename" wurde lokal geladen. Noch nicht an den Server gesendet.';
    }
    return ok;
  }

  String exportJsonString() {
    syncRawJsonFromData();
    lastUpdated.value = DateTime.now();
    lastTopic.value = 'local/download';
    lastStatus.value = 'JSON-Datei wurde zum Download vorbereitet.';
    lastStatusOk.value = true;
    return rawJsonController.text;
  }

  void syncRawJsonFromData() {
    rawJsonController.text = const JsonEncoder.withIndent('  ').convert(areaPayload.isEmpty ? <String, dynamic>{'areas': <dynamic>[]} : areaPayload);
  }

  bool isAreaEditing(String areaId) => editingAreaIds.contains(areaId);

  void toggleEditArea(String areaId) {
    if (isAreaEditing(areaId)) {
      editingAreaIds.remove(areaId);
      editingAreaIds.refresh();
      syncAndSendMap('Mähfläche gespeichert und gesendet. Warte auf Serverantwort ...');
    } else {
      if (editingAreaIds.isNotEmpty) {
        setError('Bitte zuerst die aktuell geöffnete Mähfläche mit der Diskette speichern.', topic: 'local/edit');
        return;
      }
      editingAreaIds.add(areaId);
      editingAreaIds.refresh();
    }
  }

  void updateAreaName(String areaId, String value) {
    _updateAreaProperties(areaId, (properties) {
      properties['name'] = value.trim();
    });
  }

  void updateMowingEnabled(String areaId, bool value) {
    _updateAreaProperties(areaId, (properties) {
      properties['mowing_enabled'] = value;
    });
  }

  void updateMowingOrder(String areaId, String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{2}$').hasMatch(trimmed)) {
      setError('Die Mähreihenfolge muss zweistellig sein, z. B. 01 oder 02.', topic: 'local/edit');
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    if (parsed < 1 || parsed > 99) {
      setError('Die Mähreihenfolge muss zwischen 01 und 99 liegen.', topic: 'local/edit');
      return;
    }
    if (!isMowingOrderAvailable(areaId, parsed)) {
      setError('Mähreihenfolge ${formatMowingOrder(parsed)} ist bereits vergeben.', topic: 'local/edit');
      return;
    }
    _updateAreaProperties(areaId, (properties) {
      properties['mowing_order'] = parsed;
    });
    lastStatus.value = 'Mähreihenfolge ${formatMowingOrder(parsed)} lokal übernommen. Zum Senden bitte die Diskette drücken.';
    lastStatusOk.value = true;
    lastTopic.value = 'local/edit';
  }

  bool _validateUniqueMowingOrders() {
    final seen = <int, String>{};
    for (final area in mowAreas) {
      final id = areaIdFor(area);
      final order = mowingOrderFor(area);
      if (order == null) {
        setError('Jede mow-Fläche benötigt eine zweistellige Mähreihenfolge.', topic: 'local/validation');
        return false;
      }
      if (order < 1 || order > 99) {
        setError('Mähreihenfolge ${order.toString()} ist ungültig. Erlaubt sind zweistellige Werte von 01 bis 99.', topic: 'local/validation');
        return false;
      }
      final existing = seen[order];
      if (existing != null && existing != id) {
        setError('Mähreihenfolge ${formatMowingOrder(order)} ist mehrfach vergeben.', topic: 'local/validation');
        return false;
      }
      seen[order] = id;
    }
    return true;
  }

  void _updateAreaProperties(String areaId, void Function(Map<String, dynamic> properties) mutate) {
    final next = _deepCopy(areaPayload.isEmpty ? <String, dynamic>{'areas': <dynamic>[]} : areaPayload);
    final listKey = next['areas'] is List ? 'areas' : (next['working_areas'] is List ? 'working_areas' : 'areas');
    final list = List<dynamic>.from((next[listKey] as List?) ?? const <dynamic>[]);

    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is! Map) continue;
      final area = Map<String, dynamic>.from(raw);
      final currentId = areaIdFor(area);
      if (currentId != areaId) continue;

      final properties = Map<String, dynamic>.from((area['properties'] as Map?) ?? <String, dynamic>{});
      mutate(properties);
      area['properties'] = properties;
      list[i] = area;
      break;
    }

    next[listKey] = list;
    areaPayload
      ..clear()
      ..addAll(next);
    syncRawJsonFromData();
  }

  void setValidation(Map<String, dynamic> payload, {String topic = 'map/validation/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final ok = _validationResult(root);
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
    lastStatusOk.value = ok;
    lastRemarks.assignAll(_stringList(root['remarks']));
    if (ok == true) {
      lastStatus.value = 'Server-Validierung erfolgreich.';
    } else if (ok == false) {
      lastStatus.value = 'Speichern fehlgeschlagen. Server hat die Flächen abgelehnt.';
    } else {
      lastStatus.value = 'Validierungsantwort empfangen. Warte auf eindeutige Bestätigung ...';
    }
    waitingForResponse.value = false;
  }

  void setActionResult(Map<String, dynamic> payload, {String topic = 'map/action_result/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final ok = _validationResult(root);
    lastRemarks.assignAll(_stringList(root['remarks']));
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
    lastStatusOk.value = ok;
    final action = (root['action'] ?? 'Map-Aktion').toString();
    if (ok == true) {
      lastStatus.value = '$action bestätigt.';
    } else if (ok == false) {
      lastStatus.value = '$action abgelehnt.';
    } else {
      lastStatus.value = '$action verarbeitet. Warte auf Bestätigung ...';
    }
    waitingForResponse.value = false;
  }

  void setResponse(bool accepted, String reason, {String topic = 'map/response/json'}) {
    waitingForResponse.value = false;
    lastUpdated.value = DateTime.now();
    lastTopic.value = topic;
    lastStatusOk.value = accepted;
    lastStatus.value = accepted
        ? (reason.isEmpty ? 'Service hat die Änderung bestätigt.' : 'Bestätigt: $reason')
        : (reason.isEmpty ? 'Service hat die Änderung abgelehnt.' : 'Abgelehnt: $reason');
  }

  void setError(String message, {String topic = ''}) {
    waitingForResponse.value = false;
    lastUpdated.value = DateTime.now();
    if (topic.isNotEmpty) lastTopic.value = topic;
    lastStatusOk.value = false;
    lastStatus.value = message;
  }

  Map<String, dynamic> propertiesFor(Map<String, dynamic> area) {
    final props = area['properties'];
    if (props is Map) {
      return Map<String, dynamic>.from(props);
    }
    return const <String, dynamic>{};
  }

  int pointCountFor(Map<String, dynamic> area) {
    final outline = area['outline'];
    if (outline is List) {
      return outline.length;
    }
    final legacyOutline = area['area'];
    if (legacyOutline is List) {
      return legacyOutline.length;
    }
    return 0;
  }

  bool? _validationResult(Map<String, dynamic> root) {
    final status = (root['status'] ?? '').toString().toLowerCase().trim();
    final result = (root['result'] ?? '').toString().toLowerCase().trim();
    return _validOrNull(root['valid']) ??
        _validOrNull(root['ok']) ??
        _validOrNull(root['accepted']) ??
        _validOrNull(root['success']) ??
        (status == 'ok' || status == 'accepted' ? true : null) ??
        (status == 'error' || status == 'failed' || status == 'rejected' ? false : null) ??
        (result == 'valid' || result == 'ok' ? true : null) ??
        (result == 'invalid' || result == 'error' || result == 'failed' ? false : null);
  }

  bool? _validOrNull(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    if (text == 'true' || text == 'ok' || text == 'accepted' || text == 'success' || text == 'valid') return true;
    if (text == 'false' || text == 'error' || text == 'rejected' || text == 'failed' || text == 'invalid') return false;
    return null;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList(growable: false);
    }
    if (value == null || value.toString().trim().isEmpty) {
      return const <String>[];
    }
    return <String>[value.toString()];
  }

  Map<String, dynamic> _deepCopy(Map<dynamic, dynamic> value) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(_jsonSafe(value))) as Map);
  }

  Object? _jsonSafe(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic innerValue) => MapEntry(key.toString(), _jsonSafe(innerValue)));
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is num || value is String || value is bool || value == null) {
      return value;
    }
    return value.toString();
  }

  @override
  void onClose() {
    rawJsonController.dispose();
    super.onClose();
  }
}
