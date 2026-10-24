import 'package:flutter/material.dart';

import '../services/rating.dart';

/// Small labelled metric tile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit = '',
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                if (unit.isNotEmpty)
                  TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured pill showing the strength rating.
class StrengthChip extends StatelessWidget {
  const StrengthChip({super.key, required this.strength});
  final ChargeStrength strength;

  @override
  Widget build(BuildContext context) {
    final c = strength.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(strength.icon, size: 16, color: c),
        const SizedBox(width: 6),
        Text(strength.label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Explains the iOS limitation. Shown wherever real V/A would appear.
class IosLimitationCard extends StatelessWidget {
  const IosLimitationCard({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded,
              color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              compact
                  ? 'Estimate only: iOS does not expose current or voltage, so speed is measured as % per minute.'
                  : 'iOS does not let apps read charging current or voltage. '
                      'Charge Meter therefore measures how fast the battery '
                      'percentage rises (% per minute). iOS only reports whole '
                      'percents, so readings need a few minutes to settle and '
                      'slow down above ~80% when iOS tapers charging. Use the '
                      'same starting level when comparing cables.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        ]),
      ),
    );
  }
}
