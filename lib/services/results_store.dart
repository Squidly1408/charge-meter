import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A saved "Test this cable" result.
class CableResult {
  CableResult({
    required this.id,
    required this.name,
    required this.date,
    required this.durationSec,
    required this.samples,
    required this.plug,
    this.avgWatts,
    this.peakWatts,
    this.avgCurrentMa,
    this.avgVoltageV,
    this.avgTempC,
    this.percentPerMin,
  });

  final String id;
  final String name;
  final DateTime date;
  final int durationSec;
  final int samples;
  final String plug;
  final double? avgWatts;
  final double? peakWatts;
  final double? avgCurrentMa;
  final double? avgVoltageV;
  final double? avgTempC;

  /// iOS fallback metric.
  final double? percentPerMin;

  bool get isElectrical => avgWatts != null;

  /// Value used for ranking (watts on Android, %/min on iOS).
  double get score => avgWatts ?? percentPerMin ?? 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'durationSec': durationSec,
        'samples': samples,
        'plug': plug,
        'avgWatts': avgWatts,
        'peakWatts': peakWatts,
        'avgCurrentMa': avgCurrentMa,
        'avgVoltageV': avgVoltageV,
        'avgTempC': avgTempC,
        'percentPerMin': percentPerMin,
      };

  factory CableResult.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return CableResult(
      id: j['id'] as String,
      name: j['name'] as String,
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
      samples: (j['samples'] as num?)?.toInt() ?? 0,
      plug: j['plug'] as String? ?? 'Unknown',
      avgWatts: d('avgWatts'),
      peakWatts: d('peakWatts'),
      avgCurrentMa: d('avgCurrentMa'),
      avgVoltageV: d('avgVoltageV'),
      avgTempC: d('avgTempC'),
      percentPerMin: d('percentPerMin'),
    );
  }
}

/// Persists results locally with shared_preferences (JSON list).
class ResultsStore {
  static const _key = 'cable_results_v1';

  Future<List<CableResult>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final list = <CableResult>[];
    for (final s in raw) {
      try {
        list.add(CableResult.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt entries rather than failing the whole leaderboard.
      }
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  Future<void> _save(List<CableResult> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, items.map((r) => jsonEncode(r.toJson())).toList());
  }

  Future<void> add(CableResult r) async => _save([...await load(), r]);

  Future<void> remove(String id) async =>
      _save((await load()).where((r) => r.id != id).toList());

  Future<void> clear() async => _save(const []);
}
