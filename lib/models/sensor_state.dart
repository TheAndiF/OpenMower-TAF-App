abstract class SensorState {
  final String name;
  final String unit;
  final String valueType;

  SensorState(this.name, this.unit, this.valueType);
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
    String name,
    String unit,
    this.minValue,
    this.maxValue,
    this.hasMinMax,
    this.lowerCriticalValue,
    this.hasCriticalLow,
    this.upperCriticalValue,
    this.hasCriticalHigh,
  ) : super(name, unit, 'DOUBLE');
}

class StringSensorState extends SensorState {
  String value = '';

  StringSensorState(String name, String unit) : super(name, unit, 'STRING');
}
