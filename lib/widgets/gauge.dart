import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A 240-degree arc gauge with coloured zones and an animated value arc.
class ChargeGauge extends StatelessWidget {
  const ChargeGauge({
    super.key,
    required this.value,
    required this.max,
    required this.unit,
    required this.color,
    required this.zones,
    this.label,
    this.decimals = 1,
  });

  final double? value;
  final double max;
  final String unit;
  final String? label;
  final Color color;
  final int decimals;

  /// Zone end values (ascending) paired with colours, drawn as a thin track.
  final List<(double, Color)> zones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = (value ?? 0).clamp(0.0, max);
    return AspectRatio(
      aspectRatio: 1.25,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _GaugePainter(
            fraction: max == 0 ? 0 : animated / max,
            max: max,
            color: color,
            zones: zones,
            track: theme.colorScheme.surfaceContainerHighest,
            tickColor: theme.colorScheme.onSurfaceVariant,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value == null ? '--' : animated.toStringAsFixed(decimals),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(unit,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (label != null) ...[
                  const SizedBox(height: 8),
                  Text(label!,
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.max,
    required this.color,
    required this.zones,
    required this.track,
    required this.tickColor,
  });

  final double fraction;
  final double max;
  final Color color;
  final List<(double, Color)> zones;
  final Color track;
  final Color tickColor;

  static const _start = math.pi * 150 / 180; // 150 deg
  static const _sweep = math.pi * 240 / 180; // 240 deg

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.06;
    final radius = math.min(size.width / 2, size.height / 1.6) - stroke;
    final center = Offset(size.width / 2, radius + stroke);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, base);

    // Zone track just inside the main arc.
    final zoneRect = rect.deflate(stroke * 0.95);
    var from = 0.0;
    for (final (end, c) in zones) {
      final e = end.clamp(0.0, max);
      if (e <= from) continue;
      canvas.drawArc(
        zoneRect,
        _start + _sweep * from / max,
        _sweep * (e - from) / max,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.18
          ..color = c.withValues(alpha: 0.7),
      );
      from = e;
    }

    // Value arc with a soft gradient.
    if (fraction > 0.001) {
      final shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(0),
      ).createShader(rect);
      canvas.drawArc(
        rect,
        _start,
        _sweep * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    // Ticks + labels at 0, 25, 50, 75, 100 %.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final a = _start + _sweep * i / 4;
      final r = radius - stroke * 1.9;
      final label = (max * i / 4);
      tp.text = TextSpan(
        text: label >= 10 || label == 0
            ? label.toStringAsFixed(0)
            : label.toStringAsFixed(1),
        style: TextStyle(color: tickColor, fontSize: size.width * 0.035),
      );
      tp.layout();
      final pos = center + Offset(math.cos(a) * r, math.sin(a) * r);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.max != max ||
      old.track != track;
}
