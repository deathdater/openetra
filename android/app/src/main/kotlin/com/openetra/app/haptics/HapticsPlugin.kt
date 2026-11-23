package com.openetra.app.haptics

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HapticsPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.openetra.app/haptics")

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "vibratePattern") {
            val pattern = call.argument<String>("pattern") ?: "confirm"
            trigger(pattern)
            result.success(null)
        } else {
            result.notImplemented()
        }
    }

    private fun trigger(pattern: String) {
        try {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                    ?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (vibrator == null || !vibrator.hasVibrator()) return

            val effect = when (pattern) {
                "confirm" -> VibrationEffect.createOneShot(40, 140)
                "caution" -> VibrationEffect.createWaveform(longArrayOf(0, 60, 70, 60), -1)
                "warning" -> VibrationEffect.createWaveform(longArrayOf(0, 90, 70, 90, 70, 90), -1)
                "critical" -> VibrationEffect.createWaveform(longArrayOf(0, 140, 60, 140, 60, 140, 60, 140), -1)
                "degraded" -> VibrationEffect.createWaveform(longArrayOf(0, 200, 100, 60), -1)
                "dialFocusTick" -> VibrationEffect.createOneShot(18, 85)
                "dialSelect" -> VibrationEffect.createWaveform(longArrayOf(0, 28, 40, 28), intArrayOf(0, 150, 0, 180), -1)
                "dialSubmenuEnter" -> VibrationEffect.createWaveform(longArrayOf(0, 24, 36, 48), intArrayOf(0, 110, 0, 200), -1)
                "dialNavigateBack" -> VibrationEffect.createWaveform(longArrayOf(0, 48, 36, 24), intArrayOf(0, 190, 0, 100), -1)
                "dialExitWarn" -> VibrationEffect.createOneShot(110, 175)
                "dialOpStart" -> VibrationEffect.createOneShot(45, 160)
                "dialOpComplete" -> VibrationEffect.createWaveform(longArrayOf(0, 25, 45, 25, 45, 25), intArrayOf(0, 140, 0, 160, 0, 180), -1)
                "dialOpError" -> VibrationEffect.createWaveform(longArrayOf(0, 120, 80, 120), intArrayOf(0, 220, 0, 220), -1)
                else -> VibrationEffect.createOneShot(35, 120)
            }
            vibrator.vibrate(effect)
        } catch (_: Throwable) {
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
    }
}
