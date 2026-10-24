/// One reading of the battery / charger state.
class BatterySample {
  BatterySample({
    required this.time,
    required this.level,
    required this.isCharging,
    required this.status,
    this.currentMa,
    this.voltageV,
    this.temperatureC,
    this.plug = 'Unknown',
    this.health = 'Unknown',
    this.percentPerMin,
    this.rawCurrent,
    this.unit,
    this.signFlipped = false,
  });

  final DateTime time;

  /// Battery level 0-100 (or -1 if unknown).
  final int level;
  final bool isCharging;
  final String status;

  /// Signed current in mA; positive = flowing into the battery. Android only.
  final double? currentMa;
  final double? voltageV;
  final double? temperatureC;
  final String plug;
  final String health;

  /// Estimated charge rate in %/min (iOS fallback, derived from level changes).
  final double? percentPerMin;

  /// Diagnostics from the native side.
  final int? rawCurrent;
  final String? unit;
  final bool signFlipped;

  double? get currentA => currentMa == null ? null : currentMa! / 1000.0;

  /// Power in watts = V x A (signed, positive = charging).
  double? get watts {
    final v = voltageV, a = currentA;
    if (v == null || a == null) return null;
    return v * a;
  }

  bool get hasElectrical => currentMa != null && voltageV != null;

  factory BatterySample.fromAndroid(Map<dynamic, dynamic> m) {
    double? d(String k) => (m[k] as num?)?.toDouble();
    return BatterySample(
      time: DateTime.now(),
      level: (m['level'] as num?)?.toInt() ?? -1,
      isCharging: m['isCharging'] as bool? ?? false,
      status: m['status'] as String? ?? 'Unknown',
      currentMa: d('currentMa'),
      voltageV: d('voltageV'),
      temperatureC: d('temperatureC'),
      plug: m['plug'] as String? ?? 'Unknown',
      health: m['health'] as String? ?? 'Unknown',
      rawCurrent: (m['rawCurrent'] as num?)?.toInt(),
      unit: m['unit'] as String?,
      signFlipped: m['signFlipped'] as bool? ?? false,
    );
  }
}
