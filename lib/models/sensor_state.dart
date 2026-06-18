abstract class SensorState {
  final String sensorId;
  final String sensorName;
  final String unit;
  final String valueType;

  String label;
  String description;
  String group;
  int order;
  bool visible;
  bool expert;
  String valueTopic;

  SensorState(
    this.sensorId,
    this.sensorName,
    this.unit,
    this.valueType, {
    String? label,
    this.description = '',
    this.group = 'general',
    int? order,
    this.visible = true,
    this.expert = false,
    String? valueTopic,
  })  : label = label ?? sensorName,
        order = order ?? 999999,
        valueTopic = valueTopic ?? 'sensors/$sensorId/data';

  String get name => label.isNotEmpty ? label : sensorName;

  void applyMetadata(Map<String, dynamic> metadata) {
    label = _text(metadata['label'], fallback: label.isNotEmpty ? label : sensorName);
    description = _text(metadata['description'], fallback: description);
    group = _text(metadata['group'], fallback: group.isNotEmpty ? group : 'general');
    order = _int(metadata['order']) ?? order;
    visible = _bool(metadata['visible'], fallback: visible);
    expert = _bool(metadata['expert'], fallback: expert);
    valueTopic = _text(metadata['value_topic'], fallback: valueTopic);
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'on';
  }
}

class DoubleSensorState extends SensorState {
  double value = 0;
  final double minValue;
  final double maxValue;
  final bool hasMinMax;
  final double lowerCriticalValue;
  final bool hasCriticalLow;
  final double upperCriticalValue;
  final bool hasCriticalHigh;

  DoubleSensorState(
    String sensorId,
    String sensorName,
    String unit,
    this.minValue,
    this.maxValue,
    this.hasMinMax,
    this.lowerCriticalValue,
    this.hasCriticalLow,
    this.upperCriticalValue,
    this.hasCriticalHigh, {
    String? label,
    String description = '',
    String group = 'general',
    int? order,
    bool visible = true,
    bool expert = false,
    String? valueTopic,
  }) : super(
          sensorId,
          sensorName,
          unit,
          'DOUBLE',
          label: label,
          description: description,
          group: group,
          order: order,
          visible: visible,
          expert: expert,
          valueTopic: valueTopic,
        );
}

class StringSensorState extends SensorState {
  String value = '';

  StringSensorState(
    String sensorId,
    String sensorName,
    String unit, {
    String? label,
    String description = '',
    String group = 'general',
    int? order,
    bool visible = true,
    bool expert = false,
    String? valueTopic,
  }) : super(
          sensorId,
          sensorName,
          unit,
          'STRING',
          label: label,
          description: description,
          group: group,
          order: order,
          visible: visible,
          expert: expert,
          valueTopic: valueTopic,
        );
}
