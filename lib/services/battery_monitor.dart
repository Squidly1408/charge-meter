import 'dart:async';
import 'dart:collection';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'battery_sample.dart';
import 'rating.dart';

/// Polls the battery once per second and keeps a rolling history.
///
/// * Android: real current/voltage via the `charge_meter/battery` channel.
/// * Everything else (iOS): battery_plus level + state, with a %/min estimate.
class BatteryMonitor extends ChangeNotifier {
  BatteryMonitor({this.historyLength = 120});

  static const _channel = MethodChannel('charge_meter/battery');

  final int historyLength;
  final Battery _battery = Battery();
  final ListQueue<BatterySample> _history = ListQueue();

  /// (time, level) points used for the %/min estimate on iOS.
  final List<(DateTime, int)> _levelLog = [];

  Timer? _timer;
  BatterySample? latest;
  String? error;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True when the platform exposes real current and voltage.
  bool get supportsElectrical => isAndroid && (latest?.hasElectrical ?? true);

  List<BatterySample> get history => List.unmodifiable(_history);

  ChargeStrength get strength {
    final s = latest;
    if (s == null) return ChargeStrength.none;
    if (s.hasElectrical) {
      return strengthFromWatts(s.watts, charging: s.isCharging);
    }
    return strengthFromPercentPerMin(s.percentPerMin, charging: s.isCharging);
  }

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    _poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final sample = isAndroid ? await _readAndroid() : await _readFallback();
      latest = sample;
      error = null;
      _history.addLast(sample);
      while (_history.length > historyLength) {
        _history.removeFirst();
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<BatterySample> _readAndroid() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('read');
    return BatterySample.fromAndroid(m ?? const {});
  }

  Future<BatterySample> _readFallback() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    final now = DateTime.now();
    final charging =
        state == BatteryState.charging || state == BatteryState.full;

    // Restart the log if the charging state flips, so the slope stays honest.
    final wasCharging = latest?.isCharging;
    if (wasCharging != null && wasCharging != charging) _levelLog.clear();
    if (_levelLog.isEmpty || _levelLog.last.$2 != level) {
      _levelLog.add((now, level));
    }
    // Keep roughly 15 minutes of level changes.
    _levelLog.removeWhere((e) => now.difference(e.$1).inMinutes > 15);

    return BatterySample(
      time: now,
      level: level,
      isCharging: charging,
      status: switch (state) {
        BatteryState.charging => 'Charging',
        BatteryState.full => 'Full',
        BatteryState.discharging => 'Discharging',
        BatteryState.connectedNotCharging => 'Not charging',
        BatteryState.unknown => 'Unknown',
      },
      plug: charging ? 'Connected' : 'Unplugged',
      percentPerMin: _estimatePercentPerMin(now),
    );
  }

  /// Slope between the first observed level change and now. iOS only reports
  /// whole percents, so this needs at least two level changes (often 1-3 min).
  double? _estimatePercentPerMin(DateTime now) {
    if (_levelLog.length < 2) return null;
    final first = _levelLog.first, last = _levelLog.last;
    final minutes = last.$1.difference(first.$1).inMilliseconds / 60000.0;
    if (minutes <= 0) return null;
    return (last.$2 - first.$2) / minutes;
  }

  /// Rolling %/min based on the full level log, exposed for the test mode.
  double? get percentPerMin => latest?.percentPerMin;
}
