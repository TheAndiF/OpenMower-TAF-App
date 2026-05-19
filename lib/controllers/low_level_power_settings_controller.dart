import 'dart:convert';

import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class LowLevelPowerSettingsController extends GetxController {
  static const List<String> orderedKeys = <String>[
    'battery_critical_voltage',
    'battery_empty_voltage',
    'battery_full_voltage',
    'battery_critical_high_voltage',
    'charge_critical_high_voltage',
    'charge_critical_high_current',
  ];

  static const Map<String, Map<String, String>> meta = <String, Map<String, String>>{
    'battery_critical_voltage': <String, String>{
      'label': 'Kritische Batteriespannung',
      'unit': 'V',
      'description': 'Untere Schutzgrenze für die Batteriespannung.',
    },
    'battery_empty_voltage': <String, String>{
      'label': 'Akku leer',
      'unit': 'V',
      'description': 'Spannung, ab der der Akku als leer betrachtet wird.',
    },
    'battery_full_voltage': <String, String>{
      'label': 'Akku voll',
      'unit': 'V',
      'description': 'Spannung, ab der der Akku als voll betrachtet wird.',
    },
    'battery_critical_high_voltage': <String, String>{
      'label': 'Maximale Batteriespannung',
      'unit': 'V',
      'description': 'Obere Schutzgrenze der Batteriespannung.',
    },
    'charge_critical_high_voltage': <String, String>{
      'label': 'Maximale Ladespannung',
      'unit': 'V',
      'description': 'Obere Schutzgrenze der Ladespannung.',
    },
    'charge_critical_high_current': <String, String>{
      'label': 'Maximaler Ladestrom',
      'unit': 'A',
      'description': 'Maximaler Ladestrom vor Schutzabschaltung.',
    },
  };

  final statusPayload = <String, dynamic>{}.obs;
  final activeValues = <String, double>{}.obs;
  final draftTexts = <String, String>{}.obs;
  final dirtyKeys = <String>{}.obs;

  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;

  bool get hasData => activeValues.isNotEmpty;
  int get dirtyCount => dirtyKeys.length;

  String get rawStatusJson {
    if (statusPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(statusPayload);
  }

  void requestStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Power-Status wird neu angefordert ...';
    lastTopic.value = 'll_power/set/renew/json';
    lastUpdated.value = DateTime.now();
    Get.find<MqttConnection>().requestLowLevelPowerSettings();
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = 'll_power/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final parsed = <String, double>{};
    for (final key in orderedKeys) {
      final value = _double(root[key]);
      if (value != null) {
        parsed[key] = value;
      }
    }

    if (parsed.isEmpty) {
      setError('Low-Level-Power-Status enthält keine unterstützten Zahlenwerte.', topic: topic);
      return;
    }

    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));
    activeValues
      ..clear()
      ..addAll(parsed);

    for (final key in orderedKeys) {
      final active = activeValues[key];
      if (active == null) {
        continue;
      }
      if (dirtyKeys.contains(key)) {
        final draft = _double(draftTexts[key]);
        if (draft != null && draft == active) {
          dirtyKeys.remove(key);
          draftTexts[key] = _displayNumber(active);
        }
      } else {
        draftTexts[key] = _displayNumber(active);
      }
    }
    draftTexts.removeWhere((key, value) => !orderedKeys.contains(key));
    dirtyKeys.removeWhere((key) => !orderedKeys.contains(key));

    waitingForResponse.value = false;
    lastStatusOk.value ??= true;
    if (lastStatus.value.isEmpty || lastStatus.value.contains('angefordert')) {
      lastStatus.value = 'Low-Level-Power-Status vom Backend empfangen.';
    }
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void setError(String message, {String topic = 'local/error'}) {
    waitingForResponse.value = false;
    lastStatusOk.value = false;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void setInfo(String message, {String topic = 'local/info'}) {
    lastStatusOk.value = null;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  String labelFor(String key) => meta[key]?['label'] ?? key;
  String unitFor(String key) => meta[key]?['unit'] ?? '';
  String descriptionFor(String key) => meta[key]?['description'] ?? '';
  String activeText(String key) => activeValues.containsKey(key) ? _displayNumber(activeValues[key]!) : '-';
  String draftText(String key) => draftTexts[key] ?? activeText(key);

  void updateDraftText(String key, String rawValue) {
    draftTexts[key] = rawValue;
    final parsed = _double(rawValue);
    final active = activeValues[key];
    if (parsed == null || active == null || parsed != active) {
      dirtyKeys.add(key);
    } else {
      dirtyKeys.remove(key);
    }
  }

  void resetDrafts() {
    for (final key in orderedKeys) {
      final active = activeValues[key];
      if (active != null) {
        draftTexts[key] = _displayNumber(active);
      }
      dirtyKeys.remove(key);
    }
    setInfo('Low-Level-Power-Entwürfe wurden zurückgesetzt.', topic: 'local/reset');
  }

  void applySessionChanges() {
    final payload = <String, dynamic>{};
    for (final key in orderedKeys) {
      if (!dirtyKeys.contains(key)) {
        continue;
      }
      final parsed = _double(draftTexts[key]);
      if (parsed == null) {
        setError('Der Wert für „${labelFor(key)}“ ist keine gültige JSON-Zahl.', topic: 'local/validation');
        return;
      }
      payload[key] = parsed;
    }

    if (payload.isEmpty) {
      setInfo('Es gibt keine geänderten Low-Level-Power-Werte.', topic: 'local/info');
      return;
    }

    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Power-Werte werden für die aktuelle Session gesendet ...';
    lastTopic.value = 'll_power/set/json';
    lastUpdated.value = DateTime.now();
    Get.find<MqttConnection>().publishLowLevelPowerSettings(payload);
  }

  double? _double(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim().replaceAll(',', '.') ?? '');
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }

  String _displayNumber(double value) {
    final text = value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}
