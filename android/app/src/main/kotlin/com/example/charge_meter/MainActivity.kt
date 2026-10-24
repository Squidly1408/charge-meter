package com.example.charge_meter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val reader = BatteryReader(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BatteryReader.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> try {
                        result.success(reader.read())
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
