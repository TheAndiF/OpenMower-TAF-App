import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:open_mower_app/io/mqtt_connection.dart';

/// Controller for the canonical, legacy-free GPS logging API.
///
/// Runtime state comes only from gps_state/logging/status/json. The last
/// completed session is kept separately because the live status can return to
/// idle while the last result must remain visible.
class SatelliteLoggingController extends GetxController {
  final statusPayload = <String, dynamic>{}.obs;
  final lastPayload = <String, dynamic>{}.obs;
  final validationPayload = <String, dynamic>{}.obs;
  final lastStatus = ''.obs;
  final lastTopic = ''.obs;
  final lastStatusOk = RxnBool();
  final lastUpdated = Rxn<DateTime>();
  final waitingForResponse = false.obs;
  final commandPending = false.obs;

  Timer? _responseTimeout;
  int _waitGeneration = 0;

  bool get hasData => statusPayload.isNotEmpty;
  bool get hasValidV2Status =>
      _text(statusPayload['schema']) == 'openmower.gps_state.logging.v2';
  Map<String, dynamic> get runtime => _map(statusPayload['runtime']);
  Map<String, dynamic> get request => _map(statusPayload['request']);
  Map<String, dynamic> get storage => _map(statusPayload['storage']);
  Map<String, dynamic> get implementation => _map(statusPayload['implementation']);

  bool get running => _bool(runtime['running']);
  bool get armed => _bool(runtime['armed']);
  bool get requestActive => _bool(runtime['request_active']);
  String get state => _text(runtime['state'] ?? statusPayload['status']);
  String get summary => _text(statusPayload['summary']);
  String get errorText => _text(statusPayload['error']);
  String get severity => _text(statusPayload['severity']);
  String get scriptPath => _text(implementation['script_path']);
  String get mode => _text(request['mode']);
  String get trigger => _text(request['trigger']);
  String get currentAreaId => _text(request['target_area_id']);

  String get rawStatusJson => _pretty(statusPayload);
  String get rawLastJson => _pretty(lastPayload);

  void requestStatus() {
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'GPS-Logging-Status wird neu angefordert ...';
    lastTopic.value = MqttConnection.gpsStateLoggingRenewJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine GPS-Logging-Antwort empfangen. Bitte Status- und Last-Topic prüfen.');
    Get.find<MqttConnection>().requestGpsStateLoggingStatus();
  }

  void sendControl(Map<String, dynamic> payload) {
    commandPending.value = true;
    waitingForResponse.value = true;
    lastStatusOk.value = null;
    lastStatus.value = 'GPS-Logging-Befehl wird gesendet ...';
    lastTopic.value = MqttConnection.gpsStateLoggingControlJsonTopic;
    lastUpdated.value = DateTime.now();
    _armResponseTimeout('Keine bestätigte GPS-Logging-Rückmeldung empfangen. Bitte Status neu laden.');
    Get.find<MqttConnection>().publishGpsStateLoggingControl(payload);
  }

  void setStatusPayload(Map<String, dynamic> payload, {String topic = MqttConnection.gpsStateLoggingStatusJsonTopic}) {
    final root = _root(payload);
    statusPayload.assignAll(_deepCopy(root));
    final schema = _text(root['schema']);
    final error = errorText;
    final validSchema = schema == 'openmower.gps_state.logging.v2';
    lastStatusOk.value = validSchema && error.isEmpty;
    lastStatus.value = !validSchema
        ? 'Unerwartetes GPS-Logging-Schema: ${schema.isEmpty ? '(leer)' : schema}'
        : error.isNotEmpty
            ? 'GPS-Logging meldet Fehler: $error'
            : (summary.isNotEmpty ? summary : 'GPS-Logging-Status empfangen.');
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    commandPending.value = false;
    _finishWait();
  }

  void setLastPayload(Map<String, dynamic> payload, {String topic = MqttConnection.gpsStateLoggingLastJsonTopic}) {
    lastPayload.assignAll(_deepCopy(_root(payload)));
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    _finishWait();
  }

  void setValidationPayload(Map<String, dynamic> payload, {String topic = MqttConnection.gpsStateLoggingValidationJsonTopic}) {
    final root = _root(payload);
    validationPayload.assignAll(_deepCopy(root));
    final valid = root['valid'] == true;
    final status = _text(root['status']);
    lastStatusOk.value = valid;
    lastStatus.value = valid ? 'GPS-Logging-Befehl $status.' : 'GPS-Logging-Befehl abgewiesen.';
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
    if (!valid) commandPending.value = false;
  }

  void setError(String message, {String topic = 'local/error'}) {
    _responseTimeout?.cancel();
    waitingForResponse.value = false;
    commandPending.value = false;
    lastStatusOk.value = false;
    lastStatus.value = message;
    lastTopic.value = topic;
    lastUpdated.value = DateTime.now();
  }

  void _finishWait() {
    _responseTimeout?.cancel();
    _responseTimeout = null;
    _waitGeneration++;
    waitingForResponse.value = false;
  }

  void _armResponseTimeout(String message) {
    _responseTimeout?.cancel();
    final generation = ++_waitGeneration;
    _responseTimeout = Timer(const Duration(seconds: 8), () {
      if (generation != _waitGeneration) return;
      waitingForResponse.value = false;
      commandPending.value = false;
      lastStatusOk.value = null;
      lastStatus.value = message;
      lastUpdated.value = DateTime.now();
    });
  }

  Map<String, dynamic> _root(Map<String, dynamic> payload) =>
      payload['d'] is Map ? Map<String, dynamic>.from(payload['d'] as Map) : payload;
  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) => jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  String _pretty(Map<String, dynamic> value) => value.isEmpty ? '{}' : const JsonEncoder.withIndent('  ').convert(value);
  String _text(dynamic value) => value?.toString() ?? '';
  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on';
  }
}
