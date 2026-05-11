import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MqttAreasController extends GetxController {
  final areaPayload = <String, dynamic>{}.obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final rawJsonController = TextEditingController();

  bool get hasData => areaPayload.isNotEmpty;

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

  String areaNameFor(Map<String, dynamic> area) {
    final props = propertiesFor(area);
    final name = (props['name'] ?? area['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final id = (area['id'] ?? props['id'] ?? '').toString();
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

  void setAreaPayload(Map<dynamic, dynamic> payload, {String topic = 'map/bson'}) {
    final root = payload['d'] is Map ? Map<dynamic, dynamic>.from(payload['d'] as Map) : payload;
    final normalized = Map<String, dynamic>.from(_jsonSafe(root) as Map);

    areaPayload
      ..clear()
      ..addAll(normalized);

    rawJsonController.text = jsonString;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    lastStatusOk.value = true;
    lastStatus.value = areas.isEmpty
        ? 'MQTT-Flächen empfangen, aber keine Flächenliste gefunden.'
        : '${mowAreas.length} Mähfläche(n) empfangen.';
  }

  void setError(String message, {String topic = 'map/bson'}) {
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
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
