import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/battery_sample.dart';

enum ChartMetric { watts, current, voltage, level }

extension ChartMetricX on ChartMetric {
  String get label => switch (this) {
        ChartMetric.watts => 'W',
        ChartMetric.current => 'mA',
        ChartMetric.voltage => 'V',
        ChartMetric.level => '%',
      };

  double? of(BatterySample s) => switch (this) {
        ChartMetric.watts => s.watts,
        ChartMetric.current => s.currentMa,
        ChartMetric.voltage => s.voltageV,
        ChartMetric.level => s.level >= 0 ? s.level.toDouble() : null,
      };
}

/// Rolling line chart of the last N seconds.
class LiveChart extends StatelessWidget {
  const LiveChart({
    super.key,
    required this.samples,
    required this.metric,
    required this.color,
    this.windowSeconds = 120,
  });

  final List<BatterySample> samples;
  final ChartMetric metric;
  final Color color;
  final int windowSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = samples.isEmpty ? DateTime.now() : samples.last.time;
    final spots = <FlSpot>[];
    for (final s in samples) {
      final v = metric.of(s);
      if (v == null) continue;
      final x = -now.difference(s.time).inMilliseconds / 1000.0;
      if (x < -windowSeconds) continue;
      spots.add(FlSpot(x, v));
    }

    if (spots.length < 2) {
      return Center(
        child: Text('Collecting data...',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }

    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15).clamp(0.05, double.infinity);
    minY -= pad;
    maxY += pad;
    if (metric != ChartMetric.current && metric != ChartMetric.watts) {
      // Voltage/level never go negative.
      if (minY < 0) minY = 0;
    }

    final labelStyle = TextStyle(color: scheme.onSurfaceVariant, fontSize: 11);
    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: -windowSeconds.toDouble(),
        maxX: 0,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) {
                if (v == meta.min || v == meta.max) {
                  return const SizedBox.shrink();
                }
                final text = v.abs() >= 100
                    ? v.toStringAsFixed(0)
                    : v.toStringAsFixed(1);
                return Text(text, style: labelStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 30,
              getTitlesWidget: (v, meta) =>
                  Text(v == 0 ? 'now' : '${v.toInt()}s', style: labelStyle),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
