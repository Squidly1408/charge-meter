import 'dart:async';

import 'package:flutter/material.dart';

import '../services/battery_monitor.dart';
import '../services/battery_sample.dart';
import '../services/rating.dart';
import '../services/results_store.dart';
import '../widgets/common.dart';

/// "Test this cable": averages readings over 30-60 s and saves the result.
class TestScreen extends StatefulWidget {
  const TestScreen({
    super.key,
    required this.monitor,
    required this.store,
    required this.onSaved,
  });

  final BatteryMonitor monitor;
  final ResultsStore store;
  final VoidCallback onSaved;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

enum _Phase { idle, running, done }

class _TestScreenState extends State<TestScreen> {
  /// Seconds ignored at the start while the charger negotiates its voltage.
  static const _warmUp = 3;

  final _name = TextEditingController();
  late int _duration = BatteryMonitor.isAndroid ? 45 : 180;
  _Phase _phase = _Phase.idle;
  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsed = 0;
  final List<BatterySample> _samples = [];
  BatterySample? _first;
  CableResult? _result;

  List<int> get _durations =>
      BatteryMonitor.isAndroid ? const [30, 45, 60] : const [60, 180, 300];

  @override
  void initState() {
    super.initState();
    widget.monitor.addListener(_onSample);
  }

  @override
  void dispose() {
    widget.monitor.removeListener(_onSample);
    _ticker?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _onSample() {
    if (_phase != _Phase.running) return;
    final s = widget.monitor.latest;
    if (s == null) return;
    _first ??= s;
    if (_elapsed >= _warmUp) _samples.add(s);
  }

  void _start() {
    FocusScope.of(context).unfocus();
    final s = widget.monitor.latest;
    if (s != null && !s.isCharging) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The phone is not charging - plug the cable in first.')));
      return;
    }
    setState(() {
      _phase = _Phase.running;
      _samples.clear();
      _first = null;
      _result = null;
      _elapsed = 0;
      _startedAt = DateTime.now();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed =
          DateTime.now().difference(_startedAt!).inSeconds);
      if (_elapsed >= _duration) _finish();
    });
  }

  void _cancel() {
    _ticker?.cancel();
    setState(() => _phase = _Phase.idle);
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    final name = _name.text.trim().isEmpty
        ? 'Cable ${DateTime.now().month}/${DateTime.now().day}'
        : _name.text.trim();
    final charging = _samples.where((s) => s.isCharging).toList();

    double? avg(Iterable<double?> xs) {
      final v = xs.whereType<double>().toList();
      if (v.isEmpty) return null;
      return v.reduce((a, b) => a + b) / v.length;
    }

    double? ppm;
    if (!BatteryMonitor.isAndroid && _first != null && charging.isNotEmpty) {
      final last = charging.last;
      final minutes =
          last.time.difference(_first!.time).inMilliseconds / 60000.0;
      final delta = last.level - _first!.level;
      // With whole-percent levels, 0 change means "too short to tell".
      ppm = (minutes > 0 && delta > 0) ? delta / minutes : null;
      ppm ??= widget.monitor.percentPerMin;
    }

    final watts = charging.map((s) => s.watts).whereType<double>().toList();
    final result = CableResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      date: DateTime.now(),
      durationSec: _duration,
      samples: charging.length,
      plug: charging.isNotEmpty ? charging.last.plug : 'Unknown',
      avgWatts: avg(watts),
      peakWatts: watts.isEmpty ? null : watts.reduce((a, b) => a > b ? a : b),
      avgCurrentMa: avg(charging.map((s) => s.currentMa)),
      avgVoltageV: avg(charging.map((s) => s.voltageV)),
      avgTempC: avg(charging.map((s) => s.temperatureC)),
      percentPerMin: ppm,
    );

    if (charging.isNotEmpty) {
      await widget.store.add(result);
      widget.onSaved();
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.done;
      _result = charging.isEmpty ? null : result;
    });
    if (charging.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No charging data recorded - result not saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _phase == _Phase.running;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Test this cable', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Name the cable or charger, keep the screen on and avoid heavy use '
          'during the test. The first $_warmUp s are ignored while the charger '
          'negotiates.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (!BatteryMonitor.isAndroid) ...[
          const IosLimitationCard(),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _name,
          enabled: !running,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Cable / charger name',
            hintText: 'e.g. Anker 30W + braided USB-C',
            prefixIcon: Icon(Icons.cable_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Duration', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (final d in _durations)
              ButtonSegment(
                  value: d, label: Text(d < 120 ? '$d s' : '${d ~/ 60} min')),
          ],
          selected: {_duration},
          onSelectionChanged:
              running ? null : (v) => setState(() => _duration = v.first),
        ),
        const SizedBox(height: 24),
        if (running) _buildProgress(theme) else _buildStartButton(),
        if (_phase == _Phase.done && _result != null) ...[
          const SizedBox(height: 24),
          _ResultCard(result: _result!),
        ],
      ],
    );
  }

  Widget _buildStartButton() => FilledButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(_phase == _Phase.done ? 'Run again' : 'Start test'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      );

  Widget _buildProgress(ThemeData theme) {
    final live = _samples.map((s) => s.watts).whereType<double>().toList();
    final runningAvg =
        live.isEmpty ? null : live.reduce((a, b) => a + b) / live.length;
    final remaining = (_duration - _elapsed).clamp(0, _duration);
    return Column(children: [
      SizedBox(
        width: 180,
        height: 180,
        child: Stack(fit: StackFit.expand, children: [
          CircularProgressIndicator(
            value: _elapsed / _duration,
            strokeWidth: 12,
            strokeCap: StrokeCap.round,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${remaining}s',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                _elapsed < _warmUp
                    ? 'warming up'
                    : runningAvg != null
                        ? 'avg ${runningAvg.toStringAsFixed(1)} W'
                        : 'measuring',
                style: theme.textTheme.bodyMedium,
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _cancel,
        icon: const Icon(Icons.stop_rounded),
        label: const Text('Cancel'),
      ),
    ]);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final CableResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = result.isElectrical
        ? strengthFromWatts(result.avgWatts)
        : strengthFromPercentPerMin(result.percentPerMin);
    String f(double? v, int d) => v == null ? '--' : v.toStringAsFixed(d);
    return Card(
      elevation: 0,
      color: strength.color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child:
                    Text(result.name, style: theme.textTheme.titleLarge)),
            StrengthChip(strength: strength),
          ]),
          const SizedBox(height: 12),
          if (result.isElectrical) ...[
            Text('${f(result.avgWatts, 1)} W average',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                'Peak ${f(result.peakWatts, 1)} W - ${f(result.avgCurrentMa, 0)} mA '
                'at ${f(result.avgVoltageV, 2)} V - ${f(result.avgTempC, 1)} C - '
                '${result.plug}'),
          ] else ...[
            Text(
                result.percentPerMin == null
                    ? 'Too short to measure'
                    : '${f(result.percentPerMin, 2)} %/min',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Estimated from battery % change. Try a longer test '
                'if the level did not move.'),
          ],
          const SizedBox(height: 8),
          Text('Saved to the leaderboard.',
              style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }
}
