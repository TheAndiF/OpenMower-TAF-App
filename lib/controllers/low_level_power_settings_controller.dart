import 'dart:async';
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

  static const Map<String, Map<String, String>> fallbackMeta = <String, Map<String, String>>{
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
  final settings = <String, Map<String, dynamic>>{}.obs;
  final activeValues = <String, double>{}.obs;
  final draftTexts = <String, String>{}.obs;
  final dirtyKeys = <String>{}.obs;
  final editorRevision = 0.obs;

  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final lastRemarks = <String>[].obs;

  Timer? _responseTimeout;
  int _responseWaitGeneration = 0;

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
    lastRemarks.clear();
    lastStatus.value = 'Low-Level-Board-Status wird neu angefordert ...';
    lastTopic.value = 'settings/ll_board/set/renew/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine Low-Level-Board-Antwort empfangen. Bitte MQTT-Topic settings/ll_board/json prüfen.',
    );
    Get.find<MqttConnection>().requestLowLevelPowerSettings();
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = 'settings/ll_board/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final rawSettings = root['settings'];
    final nextSettings = <String, Map<String, dynamic>>{};
    final parsed = <String, double>{};

    if (rawSettings is Map) {
      for (final key in orderedKeys) {
        final setting = rawSettings[key];
        if (setting is Map) {
          final normalized = Map<String, dynamic>.from(setting);
          nextSettings[key] = normalized;
          final active = _double(normalized['active'] ?? normalized['persistent'] ?? normalized['default']);
          if (active != null) {
            parsed[key] = active;
          }
        }
      }
    } else {
      // Limited legacy compatibility for old ll_power/json payloads.
      for (final key in orderedKeys) {
        final value = _double(root[key]);
        if (value != null) {
          parsed[key] = value;
          nextSettings[key] = <String, dynamic>{'active': value};
        }
      }
    }

    if (parsed.isEmpty) {
      setError('Low-Level-Board-Status enthält keine unterstützten Zahlenwerte.', topic: topic);
      return;
    }

    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));
    settings
      ..clear()
      ..addAll(nextSettings);
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
    editorRevision.value++;

    _clearResponseTimeout();
    waitingForResponse.value = false;
    lastStatusOk.value ??= true;
    if (lastStatus.value.isEmpty || lastStatus.value.contains('angefordert')) {
      lastStatus.value = 'Low-Level-Board-Status vom Backend empfangen.';
    }
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void setValidation(Map<String, dynamic> payload, {String topic = 'settings/ll_board/validation/json'}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    final valid = _boolOrNull(root['valid']);
    final mode = root['mode']?.toString() ?? root['scope']?.toString() ?? '';
    final accepted = _acceptedKeys(root['accepted'] ?? root['applied']);
    final remarks = <String>[
      ..._stringList(root['remarks']),
      ..._rejectedRemarks(root['rejected']),
    ];

    lastRemarks.assignAll(remarks);
    lastStatusOk.value = valid;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _clearResponseTimeout();
    waitingForResponse.value = false;

    for (final key in accepted) {
      dirtyKeys.remove(key);
    }

    if (valid == true) {
      if (mode == 'persistent') {
        lastStatus.value = 'Low-Level-Board-Werte wurden dauerhaft gespeichert.';
      } else if (mode == 'session') {
        lastStatus.value = 'Low-Level-Board-Werte wurden für die aktuelle Session angewendet.';
      } else {
        lastStatus.value = 'Low-Level-Board-Änderung wurde bestätigt.';
      }
    } else if (valid == false) {
      lastStatus.value = 'Low-Level-Board-Änderung wurde teilweise oder vollständig abgelehnt.';
    } else {
      lastStatus.value = 'Low-Level-Board-Validierungsantwort empfangen.';
    }
  }

  void setError(String message, {String topic = 'local/error'}) {
    _clearResponseTimeout();
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

  String labelFor(String key) => settings[key]?['label']?.toString() ?? fallbackMeta[key]?['label'] ?? key;
  String unitFor(String key) => settings[key]?['unit']?.toString() ?? fallbackMeta[key]?['unit'] ?? '';
  String descriptionFor(String key) => settings[key]?['description']?.toString() ?? fallbackMeta[key]?['description'] ?? '';
  String activeText(String key) => activeValues.containsKey(key) ? _displayNumber(activeValues[key]!) : '-';
  String draftText(String key) => draftTexts[key] ?? activeText(key);
  String rangeText(String key) {
    final setting = settings[key];
    final min = setting?['min'];
    final max = setting?['max'];
    if (min == null && max == null) {
      return '';
    }
    if (min != null && max != null) {
      return 'Erlaubt: ${_displayAny(min)} bis ${_displayAny(max)}';
    }
    if (min != null) {
      return 'Mindestens ${_displayAny(min)}';
    }
    return 'Maximal ${_displayAny(max)}';
  }

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
    editorRevision.value++;
    setInfo('Low-Level-Board-Entwürfe wurden zurückgesetzt.', topic: 'local/reset');
  }

  Map<String, dynamic>? _payloadFromDrafts() {
    final payload = <String, dynamic>{};
    for (final key in orderedKeys) {
      if (!dirtyKeys.contains(key)) {
        continue;
      }
      final parsed = _double(draftTexts[key]);
      if (parsed == null) {
        setError('Der Wert für „${labelFor(key)}“ ist keine gültige JSON-Zahl.', topic: 'local/validation');
        return null;
      }
      final min = _double(settings[key]?['min']);
      final max = _double(settings[key]?['max']);
      if ((min != null && parsed < min) || (max != null && parsed > max)) {
        setError('Der Wert für „${labelFor(key)}“ liegt außerhalb des erlaubten Bereichs.', topic: 'local/validation');
        return null;
      }
      payload[key] = parsed;
    }
    if (payload.isEmpty) {
      setInfo('Es gibt keine geänderten Low-Level-Board-Werte.', topic: 'local/info');
      return null;
    }
    return payload;
  }

  void applySessionChanges() {
    final payload = _payloadFromDrafts();
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Board-Werte werden für die aktuelle Session gesendet ...';
    lastTopic.value = 'settings/ll_board/set/session/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine Backend-Bestätigung für die Low-Level-Board-Sessionänderung empfangen.',
    );
    Get.find<MqttConnection>().publishLowLevelPowerSessionSettings(payload);
  }

  void savePersistentChanges() {
    final payload = _payloadFromDrafts();
    if (payload == null) {
      return;
    }
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'Low-Level-Board-Werte werden dauerhaft gespeichert ...';
    lastTopic.value = 'settings/ll_board/set/persistent/json';
    lastUpdated.value = DateTime.now();
    _armResponseTimeout(
      'Keine Backend-Bestätigung für das dauerhafte Speichern der Low-Level-Board-Werte empfangen.',
    );
    Get.find<MqttConnection>().publishLowLevelPowerPersistentSettings(payload);
  }

  void _armResponseTimeout(String timeoutMessage) {
    _responseTimeout?.cancel();
    final generation = ++_responseWaitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _responseWaitGeneration || !waitingForResponse.value) {
        return;
      }
      waitingForResponse.value = false;
      lastStatusOk.value = null;
      lastStatus.value = timeoutMessage;
      lastUpdated.value = DateTime.now();
    });
  }

  void _clearResponseTimeout() {
    _responseWaitGeneration++;
    _responseTimeout?.cancel();
    _responseTimeout = null;
  }

  @override
  void onClose() {
    _clearResponseTimeout();
    super.onClose();
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

  bool? _boolOrNull(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  List<String> _acceptedKeys(dynamic raw) {
    if (raw is Map) {
      return raw.keys.map((key) => key.toString()).toList();
    }
    if (raw is List) {
      return raw.map((key) => key.toString()).toList();
    }
    return const <String>[];
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    if (raw == null) {
      return const <String>[];
    }
    return <String>[raw.toString()];
  }

  List<String> _rejectedRemarks(dynamic raw) {
    if (raw is Map) {
      return raw.entries.map((entry) => '${entry.key}: ${entry.value}').toList();
    }
    if (raw is! List) {
      return const <String>[];
    }
    final remarks = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final key = item['key']?.toString() ?? 'unbekannt';
        final reason = item['reason']?.toString() ?? 'abgelehnt';
        remarks.add('$key: $reason');
      } else {
        remarks.add(item.toString());
      }
    }
    return remarks;
  }

  String _displayNumber(double value) {
    final text = value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  String _displayAny(dynamic value) {
    final number = _double(value);
    return number == null ? value.toString() : _displayNumber(number);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}
