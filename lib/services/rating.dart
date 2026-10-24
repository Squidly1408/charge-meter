import 'package:flutter/material.dart';

enum ChargeStrength { none, slow, normal, fast, superFast }

extension ChargeStrengthX on ChargeStrength {
  String get label => switch (this) {
        ChargeStrength.none => 'Not charging',
        ChargeStrength.slow => 'Slow',
        ChargeStrength.normal => 'Normal',
        ChargeStrength.fast => 'Fast',
        ChargeStrength.superFast => 'Super fast',
      };

  String get description => switch (this) {
        ChargeStrength.none => 'Plug in a cable or charger to start measuring.',
        ChargeStrength.slow =>
          'Under 7.5 W: typical of PC USB ports or worn cables.',
        ChargeStrength.normal => '7.5 to 15 W: a standard 5 V adapter.',
        ChargeStrength.fast => '15 to 25 W: Quick Charge / USB-PD fast charging.',
        ChargeStrength.superFast => '25 W and up: high-power PD / PPS charging.',
      };

  Color get color => switch (this) {
        ChargeStrength.none => Colors.grey,
        ChargeStrength.slow => const Color(0xFFE5484D),
        ChargeStrength.normal => const Color(0xFFF5A524),
        ChargeStrength.fast => const Color(0xFF30A46C),
        ChargeStrength.superFast => const Color(0xFF3E8EF7),
      };

  IconData get icon => switch (this) {
        ChargeStrength.none => Icons.power_off_rounded,
        ChargeStrength.slow => Icons.battery_charging_full_rounded,
        ChargeStrength.normal => Icons.battery_charging_full_rounded,
        ChargeStrength.fast => Icons.bolt_rounded,
        ChargeStrength.superFast => Icons.electric_bolt_rounded,
      };
}

/// Rating from real power (Android).
ChargeStrength strengthFromWatts(double? watts, {bool charging = true}) {
  if (!charging || watts == null || watts <= 0.05) return ChargeStrength.none;
  if (watts < 7.5) return ChargeStrength.slow;
  if (watts < 15) return ChargeStrength.normal;
  if (watts < 25) return ChargeStrength.fast;
  return ChargeStrength.superFast;
}

/// Rough rating from %/min (iOS fallback). Assumes a ~12-15 Wh phone battery,
/// so 1 %/min is very roughly 8-9 W into the cell. Treat as an estimate only.
ChargeStrength strengthFromPercentPerMin(double? ppm, {bool charging = true}) {
  if (!charging || ppm == null || ppm <= 0) return ChargeStrength.none;
  if (ppm < 0.6) return ChargeStrength.slow;
  if (ppm < 1.2) return ChargeStrength.normal;
  if (ppm < 2.0) return ChargeStrength.fast;
  return ChargeStrength.superFast;
}
