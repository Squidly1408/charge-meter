import 'package:charge_meter/services/battery_sample.dart';
import 'package:charge_meter/services/rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('watts = V x A', () {
    final s = BatterySample.fromAndroid(
        {'currentMa': 2000.0, 'voltageV': 4.2, 'isCharging': true, 'level': 50});
    expect(s.watts, closeTo(8.4, 1e-9));
  });

  test('strength thresholds', () {
    expect(strengthFromWatts(3), ChargeStrength.slow);
    expect(strengthFromWatts(10), ChargeStrength.normal);
    expect(strengthFromWatts(18), ChargeStrength.fast);
    expect(strengthFromWatts(30), ChargeStrength.superFast);
    expect(strengthFromWatts(30, charging: false), ChargeStrength.none);
    expect(strengthFromPercentPerMin(1.5), ChargeStrength.fast);
  });
}
