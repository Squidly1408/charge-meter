package com.example.charge_meter

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import kotlin.math.abs

/**
 * Reads real battery telemetry:
 *  - instantaneous current from BatteryManager.BATTERY_PROPERTY_CURRENT_NOW
 *  - voltage / temperature / plug / health / level / status from the sticky
 *    ACTION_BATTERY_CHANGED intent (no receiver registration needed).
 *
 * CURRENT_NOW is specified as microamps with "positive = charging", but many
 * vendors report milliamps and/or flip the sign. We normalise to signed mA
 * where positive always means "current flowing into the battery".
 */
class BatteryReader(private val context: Context) {

    companion object {
        const val CHANNEL = "charge_meter/battery"

        /**
         * Below this magnitude a raw value is assumed to already be in mA.
         * Phone currents are ~10 mA..15 A; in µA that is 10_000..15_000_000,
         * while in mA it is 10..15_000. Values between are ambiguous, so we
         * use the device's history to make the call sticky (see [unitIsMicro]).
         */
        private const val MICRO_THRESHOLD = 20_000L
    }

    private val batteryManager =
        context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager

    /** null = undecided; once a clearly µA-sized value is seen we lock to µA. */
    private var unitIsMicro: Boolean? = null

    fun read(): Map<String, Any?> {
        val intent: Intent? = context.registerReceiver(
            null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )

        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val health = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
        val levelRaw = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val voltageRaw = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1
        val tempRaw = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
            ?: Int.MIN_VALUE
        val technology = intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)

        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL && plugged != 0

        // ---- Current ------------------------------------------------------
        val rawCurrent = batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        // Long.MIN_VALUE (or 0 on some devices) means "not supported".
        val currentSupported = rawCurrent != Long.MIN_VALUE && rawCurrent != Int.MIN_VALUE.toLong()
        var currentMa: Double? = null
        var signFlipped = false
        if (currentSupported && rawCurrent != 0L) {
            val mag = abs(rawCurrent)
            if (mag >= MICRO_THRESHOLD) unitIsMicro = true
            val micro = unitIsMicro ?: (mag >= MICRO_THRESHOLD)
            var ma = if (micro) rawCurrent / 1000.0 else rawCurrent.toDouble()

            // Sign heuristic: use plug/charging status as ground truth.
            if (plugged != 0 && status == BatteryManager.BATTERY_STATUS_CHARGING && ma < 0) {
                ma = -ma; signFlipped = true
            } else if (plugged == 0 && ma > 0) {
                ma = -ma; signFlipped = true
            }
            currentMa = ma
        } else if (currentSupported) {
            currentMa = 0.0
        }

        // ---- Voltage (mV per spec; a few devices report V or µV) -----------
        val voltageV: Double? = when {
            voltageRaw <= 0 -> null
            voltageRaw < 100 -> voltageRaw.toDouble()               // already volts
            voltageRaw > 100_000 -> voltageRaw / 1_000_000.0        // µV
            else -> voltageRaw / 1000.0                              // mV
        }

        val chargeCounter = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val chargeTimeRemaining = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            batteryManager.computeChargeTimeRemaining()
        } else -1L

        return mapOf(
            "currentMa" to currentMa,
            "rawCurrent" to if (currentSupported) rawCurrent else null,
            "unit" to when (unitIsMicro) { true -> "uA"; false -> "mA"; null -> "auto" },
            "signFlipped" to signFlipped,
            "voltageV" to voltageV,
            "temperatureC" to if (tempRaw == Int.MIN_VALUE) null else tempRaw / 10.0,
            "level" to if (levelRaw >= 0 && scale > 0) levelRaw * 100 / scale else -1,
            "plug" to plugName(plugged),
            "status" to statusName(status),
            "health" to healthName(health),
            "isCharging" to isCharging,
            "technology" to technology,
            "chargeCounterUah" to if (chargeCounter == Int.MIN_VALUE) null else chargeCounter,
            "chargeTimeRemainingMs" to chargeTimeRemaining,
        )
    }

    private fun plugName(p: Int): String = when (p) {
        BatteryManager.BATTERY_PLUGGED_AC -> "AC"
        BatteryManager.BATTERY_PLUGGED_USB -> "USB"
        BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless"
        8 /* BATTERY_PLUGGED_DOCK, API 33 */ -> "Dock"
        0 -> "Unplugged"
        else -> "Other"
    }

    private fun statusName(s: Int): String = when (s) {
        BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
        BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
        BatteryManager.BATTERY_STATUS_FULL -> "Full"
        BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not charging"
        else -> "Unknown"
    }

    private fun healthName(h: Int): String = when (h) {
        BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
        BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
        BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
        BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over voltage"
        BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Failure"
        BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
        else -> "Unknown"
    }
}
