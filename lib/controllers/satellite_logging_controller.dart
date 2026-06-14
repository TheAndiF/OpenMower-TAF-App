import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

class SatelliteLoggingController extends GetxController {
  final statusPayload = <String, dynamic>{}.obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final lastRemarks = <String>[].obs;
  final waitingForResponse = false.obs;

  Timer? _responseTimeout;
  int _waitGeneration = 0;

  bool get hasData => statusPayload.isNotEmpty;

  String get rawStatusJson {
    if (statusPayload.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(statusPayload);
  }

  bool get running => _bool(statusPayload['running'] ?? statusPayload['active']);
  bool get armed => _bool(statusPayload['armed']);
  String get mode => _text(statusPayload['mode']);
  String get trigger => _text(statusPayload['trigger']);
  String get currentAreaId => _text(statusPayload['current_area_id']);
  String get errorText => _text(statusPayload['error']);

  void requestStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastRemarks.clear();
    lastStatus.value = 'Satellite-Logging-Status wird neu angefordert ...';
    lastTopic.value = MqttConnection.mowerLogicSatelliteLoggingRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine Satellite-Logging-Antwort empfangen. Bitte Topic ${MqttConnection.mowerLogicSatelliteLoggingJsonTopic} prüfen.');
    Get.find<MqttConnection>().requestMowerLogicSatelliteLoggingStatus();
  }

  void sendControl(Map<String, dynamic> payload) {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastRemarks.clear();
    lastStatus.value = 'Satellite-Logging-Control wird gesendet ...';
    lastTopic.value = MqttConnection.mowerLogicSatelliteLoggingControlJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine Satellite-Logging-Rückmeldung empfangen. Bitte Status neu laden.');
    Get.find<MqttConnection>().publishMowerLogicSatelliteLoggingControl(payload);
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = MqttConnection.mowerLogicSatelliteLoggingJsonTopic}) {
    final root = payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
    statusPayload
      ..clear()
      ..addAll(_deepCopy(root));
    lastRemarks.assignAll(_stringList(root['remarks']));
    final error = errorText;
    lastStatusOk.value = error.isEmpty ? true : false;
    lastStatus.value = error.isEmpty ? 'Satellite-Logging-Status empfangen.' : 'Satellite-Logging meldet Fehler: $error';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _clearResponseTimeout();
    waitingForResponse.value = false;
  }

  void setError(String message, {String topic = 'local/error'}) {
    _clearResponseTimeout();
    waitingForResponse.value = false;
    lastStatusOk.value = false;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void _armResponseTimeout(String message) {
    _responseTimeout?.cancel();
    final generation = ++_waitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _waitGeneration) {
        return;
      }
      waitingForResponse.value = false;
      lastStatusOk.value = null;
      lastStatus.value = message;
      lastUpdated.value = DateTime.now();
    });
  }

  void _clearResponseTimeout() {
    _responseTimeout?.cancel();
    _responseTimeout = null;
    _waitGeneration++;
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    if (raw == null) {
      return const <String>[];
    }
    final text = raw.toString();
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  String _text(dynamic value) => value?.toString() ?? '';

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on';
  }
}
