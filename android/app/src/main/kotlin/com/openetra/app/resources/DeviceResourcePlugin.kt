package com.openetra.app.resources

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class DeviceResourcePlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.openetra.app/resources")
    private val worker = Executors.newSingleThreadExecutor { r ->
        Thread(r, "OpenetraResourceWorker").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ttsInitLatch = CountDownLatch(1)

    @Volatile
    private var ttsReady = false

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status ->
        ttsReady = status == TextToSpeech.SUCCESS
        ttsInitLatch.countDown()
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getTelemetry" -> result.success(readTelemetry())
            "checkOfflineVoices" -> {
                val locales = call.argument<List<String>>("locales") ?: emptyList()
                worker.execute {
                    val map = checkOfflineVoices(locales)
                    mainHandler.post { result.success(map) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun readTelemetry(): Map<String, Any> {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val batteryPct = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?.takeIf { it in 0..100 } ?: 100
        val charging = bm?.isCharging ?: false

        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val thermalLevel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && pm != null) {
            pm.currentThermalStatus
        } else {
            0
        }

        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memInfo)
        val availMb = (memInfo.availMem / (1024L * 1024L)).toInt()

        return mapOf(
            "batteryPercent" to batteryPct,
            "isCharging" to charging,
            "thermalLevel" to thermalLevel,
            "availableRamMb" to availMb,
            "isLowMemory" to memInfo.lowMemory
        )
    }

    private fun checkOfflineVoices(locales: List<String>): Map<String, Boolean> {
        try {
            ttsInitLatch.await(1500, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
        }
        if (!ttsReady) {
            return locales.associateWith { false }
        }
        val voices = try {
            tts.voices
        } catch (_: Throwable) {
            null
        } ?: return locales.associateWith { false }

        val out = mutableMapOf<String, Boolean>()
        for (tag in locales) {
            val target = Locale.forLanguageTag(tag)
            val found = voices.any { voice ->
                val sameLang = voice.locale.language.equals(target.language, ignoreCase = true)
                val sameCountry = target.country.isEmpty() ||
                    voice.locale.country.isEmpty() ||
                    voice.locale.country.equals(target.country, ignoreCase = true)
                val installed = !voice.features.contains(
                    TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED
                )
                sameLang && sameCountry && !voice.isNetworkConnectionRequired && installed
            }
            out[tag] = found
        }
        return out
    }

    fun release() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
        try {
            tts.shutdown()
        } catch (_: Throwable) {
        }
    }
}
