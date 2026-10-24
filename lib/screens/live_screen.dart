import 'package:flutter/material.dart';

import '../services/battery_monitor.dart';
import '../services/rating.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';
import '../widgets/live_chart.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.monitor});
  final BatteryMonitor monitor;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  ChartMetric _metric = ChartMetric.watts;

  static const _wattZones = [
    (7.5, Color(0xFFE5484D)),
    (15.0, Color(0xFFF5A524)),
    (25.0, Color(0xFF30A46C)),
    (999.0, Color(0xFF3E8EF7)),
  ];
  static const _ppmZones = [
    (0.6, Color(0xFFE5484D)),
    (1.2, Color(0xFFF5A524)),
    (2.0, Color(0xFF30A46C)),
    (99.0, Color(0xFF3E8EF7)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.monitor,
      builder: (context, _) {
        final m = widget.monitor;
        final s = m.latest;
        final electrical = m.supportsElectrical;
        final strength = m.strength;
        final metric = electrical ? _metric : ChartMetric.level;

        String fmt(double? v, int d) => v == null ? '--' : v.toStringAsFixed(d);

        // Gauge scale grows for high-power chargers.
        final watts = s?.watts;
        final gaugeMax = electrical
            ? ((watts ?? 0) > 40 ? ((watts! / 20).ceil() * 20).toDouble() : 40.0)
            : 3.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (m.error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Could not read battery: ${m.error}'),
                ),
              ),
            if (!electrical) const IosLimitationCard(compact: true),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StrengthChip(strength: strength),
                      Text(
                        s == null ? '' : '${s.plug} - ${s.status}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ChargeGauge(
                    value: electrical
                        ? watts?.clamp(0, double.infinity)
                        : s?.percentPerMin?.clamp(0, double.infinity),
                    max: gaugeMax,
                    unit: electrical ? 'watts' : '% per min (est.)',
                    color: strength.color,
                    zones: electrical ? _wattZones : _ppmZones,
                    decimals: electrical ? 1 : 2,
                  ),
                  Text(strength.description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.9,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                if (electrical) ...[
                  StatTile(
                      icon: Icons.electric_meter_rounded,
                      label: 'Current',
                      value: fmt(s?.currentMa, 0),
                      unit: 'mA'),
                  StatTile(
                      icon: Icons.bolt_rounded,
                      label: 'Voltage',
                      value: fmt(s?.voltageV, 2),
                      unit: 'V'),
                  StatTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Temperature',
                      value: fmt(s?.temperatureC, 1),
                      unit: 'C'),
                  StatTile(
                      icon: Icons.favorite_rounded,
                      label: 'Health',
                      value: s?.health ?? '--'),
                ] else ...[
                  StatTile(
                      icon: Icons.speed_rounded,
                      label: 'Rate (est.)',
                      value: fmt(s?.percentPerMin, 2),
                      unit: '%/min'),
                  StatTile(
                      icon: Icons.timer_outlined,
                      label: 'Time to full',
                      value: _timeToFull(s?.level, s?.percentPerMin)),
                ],
                StatTile(
                    icon: Icons.battery_std_rounded,
                    label: 'Level',
                    value: s == null || s.level < 0 ? '--' : '${s.level}',
                    unit: '%'),
                StatTile(
                    icon: Icons.power_rounded,
                    label: 'Source',
                    value: s?.plug ?? '--'),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Live (2 min)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (electrical)
                        SegmentedButton<ChartMetric>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                          segments: const [
                            ButtonSegment(
                                value: ChartMetric.watts, label: Text('W')),
                            ButtonSegment(
                                value: ChartMetric.current, label: Text('mA')),
                            ButtonSegment(
                                value: ChartMetric.voltage, label: Text('V')),
                          ],
                          selected: {_metric},
                          onSelectionChanged: (v) =>
                              setState(() => _metric = v.first),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: LiveChart(
                        samples: m.history,
                        metric: metric,
                        color: strength == ChargeStrength.none
                            ? Theme.of(context).colorScheme.primary
                            : strength.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (electrical && s?.rawCurrent != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Raw CURRENT_NOW: ${s!.rawCurrent} (unit: ${s.unit}'
                  '${s.signFlipped ? ', sign corrected' : ''})',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }

  String _timeToFull(int? level, double? ppm) {
    if (level == null || ppm == null || ppm <= 0 || level < 0) return '--';
    final mins = ((100 - level) / ppm).round();
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h ${mins % 60}m';
  }
}
