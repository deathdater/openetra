package com.openetra.app.speech

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineNemoEncDecCtcModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.SileroVadModelConfig
import com.k2fsa.sherpa.onnx.Vad
import com.k2fsa.sherpa.onnx.VadModelConfig
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.min

class OfflineSpeechPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val SILERO_VAD_SHA256 =
            "c36d490aff5ab924ca6c7aeec4d8f6bd3d22db6fa17611b9c5b17eae58ac3a20"

        fun provisionSileroVad(context: Context): File {
            val vadDir = File(context.filesDir, "models/vad")
            vadDir.mkdirs()
            val outFile = File(vadDir, "silero_vad.int8.onnx")
            if (outFile.exists() && outFile.length() > 0L && sha256(outFile) == SILERO_VAD_SHA256) {
                return outFile
            }
            val lookupKey = runCatching {
                FlutterInjector.instance().flutterLoader()
                    .getLookupKeyForAsset("assets/models/vad/silero_vad.int8.onnx")
            }.getOrElse { "flutter_assets/assets/models/vad/silero_vad.int8.onnx" }
            val tmpFile = File(vadDir, "silero_vad.int8.onnx.tmp")
            val digest = MessageDigest.getInstance("SHA-256")
            val buf = ByteArray(32 * 1024)
            context.assets.open(lookupKey).use { input ->
                FileOutputStream(tmpFile).use { out ->
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        digest.update(buf, 0, n)
                        out.write(buf, 0, n)
                    }
                }
            }
            val actual = digest.digest().joinToString("") { "%02x".format(it) }
            if (actual != SILERO_VAD_SHA256) {
                tmpFile.delete()
                throw SecurityException("Silero VAD checksum mismatch: expected $SILERO_VAD_SHA256, got $actual")
            }
            if (outFile.exists()) outFile.delete()
            if (!tmpFile.renameTo(outFile)) {
                throw IllegalStateException("Failed saving silero_vad.int8.onnx")
            }
            return outFile
        }

        fun createVad(vadFile: File): Vad {
            val cfg = VadModelConfig(
                sileroVadModelConfig = SileroVadModelConfig(
                    model = vadFile.absolutePath,
                    threshold = 0.5f,
                    minSilenceDuration = 0.4f,
                    minSpeechDuration = 0.2f,
                    windowSize = 512,
                    maxSpeechDuration = 10.0f
                ),
                sampleRate = 16000,
                numThreads = 1,
                provider = "cpu",
                debug = false
            )
            return Vad(null, cfg)
        }

        fun runVadOnSamples(vad: Vad, samples: FloatArray): Map<String, Any> {
            vad.reset()
            val t0 = SystemClock.elapsedRealtime()
            val segments = mutableListOf<FloatArray>()
            var offset = 0
            while (offset < samples.size) {
                val end = min(offset + 512, samples.size)
                val chunk = FloatArray(512)
                System.arraycopy(samples, offset, chunk, 0, end - offset)
                vad.acceptWaveform(chunk)
                while (!vad.empty()) {
                    segments.add(vad.front().samples)
                    vad.pop()
                }
                offset += 512
            }
            vad.flush()
            while (!vad.empty()) {
                segments.add(vad.front().samples)
                vad.pop()
            }
            val ms = (SystemClock.elapsedRealtime() - t0).toInt()
            val totalSpeechSamples = segments.sumOf { it.size }
            return mapOf(
                "speechDetected" to (segments.isNotEmpty() || vad.isSpeechDetected()),
                "segmentCount" to segments.size,
                "speechSampleCount" to totalSpeechSamples,
                "vadMs" to ms,
                "segments" to segments
            )
        }

        fun sha256(file: File): String {
            val digest = MessageDigest.getInstance("SHA-256")
            val buf = ByteArray(64 * 1024)
            FileInputStream(file).use { input ->
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    digest.update(buf, 0, n)
                }
            }
            return digest.digest().joinToString("") { "%02x".format(it) }
        }
    }

    private val channel = MethodChannel(messenger, "com.openetra.app/speech")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "OpenetraSpeechWorker").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    private var vad: Vad? = null
    private val recognizers = mutableMapOf<String, OfflineRecognizer>()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initVad" -> {
                runOnWorker(result) {
                    ensureVadInitialized()
                    mapOf("vadInitialized" to true)
                }
            }

            "status" -> {
                val locale = call.argument<String>("locale") ?: "en-IN"
                runOnWorker(result) {
                    val hasAsrPack = recognizers.containsKey(locale)
                    val hasOnDeviceOs = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
                    mapOf(
                        "vadReady" to (vad != null),
                        "asrPackLoaded" to hasAsrPack,
                        "osOnDeviceSpeechAvailable" to hasOnDeviceOs
                    )
                }
            }

            "detectSpeechSegments" -> {
                val raw = call.argument<List<Double>>("samples")
                if (raw == null) {
                    result.error("INVALID_ARGS", "samples required", null)
                    return
                }
                val floats = FloatArray(raw.size) { raw[it].toFloat() }
                runOnWorker(result) {
                    val activeVad = ensureVadInitialized()
                    val summary = runVadOnSamples(activeVad, floats)
                    mapOf(
                        "speechDetected" to summary["speechDetected"],
                        "segmentCount" to summary["segmentCount"],
                        "speechSampleCount" to summary["speechSampleCount"],
                        "vadMs" to summary["vadMs"]
                    )
                }
            }

            "loadAsrPack" -> {
                val locale = call.argument<String>("locale") ?: "hi-IN"
                val modelPath = call.argument<String>("modelPath")
                val tokensPath = call.argument<String>("tokensPath")
                val expectedSha = call.argument<String>("expectedSha256")
                if (modelPath.isNullOrBlank() || tokensPath.isNullOrBlank() || expectedSha.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "modelPath, tokensPath, and expectedSha256 required", null)
                    return
                }
                runOnWorker(result) {
                    val modelFile = File(modelPath)
                    val tokensFile = File(tokensPath)
                    if (!modelFile.exists() || !tokensFile.exists()) {
                        throw IllegalStateException("ASR model or tokens missing")
                    }
                    val actual = sha256(modelFile)
                    if (actual != expectedSha.trim().lowercase()) {
                        throw SecurityException("ASR pack SHA-256 mismatch")
                    }
                    val cfg = OfflineRecognizerConfig(
                        modelConfig = OfflineModelConfig(
                            nemo = OfflineNemoEncDecCtcModelConfig(model = modelFile.absolutePath),
                            tokens = tokensFile.absolutePath,
                            numThreads = 2,
                            debug = false,
                            provider = "cpu"
                        )
                    )
                    recognizers[locale]?.release()
                    recognizers[locale] = OfflineRecognizer(null, cfg)
                    mapOf("loaded" to true, "locale" to locale)
                }
            }

            "transcribePcm16k" -> {
                val raw = call.argument<List<Double>>("samples")
                val locale = call.argument<String>("locale") ?: "hi-IN"
                if (raw == null) {
                    result.error("INVALID_ARGS", "samples required", null)
                    return
                }
                val floats = FloatArray(raw.size) { raw[it].toFloat() }
                runOnWorker(result) {
                    transcribeWithLoadedPack(floats, locale)
                }
            }

            "recordAndRecognizeOffline" -> {
                val locale = call.argument<String>("locale") ?: "en-IN"
                val maxDurationMs = call.argument<Int>("maxDurationMs") ?: 4000
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    result.error("MIC_PERMISSION", "Microphone permission has not been granted", null)
                    return
                }
                runOnWorker(result) {
                    if (recognizers.containsKey(locale)) {
                        val samples = recordAudio16k(maxDurationMs.coerceIn(1000, 8000))
                        transcribeWithLoadedPack(samples, locale)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
                    ) {
                        recognizeViaAndroidOnDevice(locale)
                    } else {
                        throw IllegalStateException(
                            "ASR_PACK_NOT_INSTALLED: No offline IndicConformer pack or on-device OS speech pack is installed for $locale."
                        )
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun ensureVadInitialized(): Vad {
        val current = vad
        if (current != null) return current
        val vadFile = provisionSileroVad(context)
        val created = createVad(vadFile)
        vad = created
        return created
    }

    private fun transcribeWithLoadedPack(samples: FloatArray, locale: String): Map<String, Any> {
        val recognizer = recognizers[locale]
            ?: throw IllegalStateException("ASR_PACK_NOT_INSTALLED: Offline ASR pack not loaded for $locale")
        val activeVad = ensureVadInitialized()
        val vadRes = runVadOnSamples(activeVad, samples)
        @Suppress("UNCHECKED_CAST")
        val segments = vadRes["segments"] as? List<FloatArray> ?: emptyList()
        val audioForDecode = if (segments.isNotEmpty()) {
            val total = segments.sumOf { it.size }
            FloatArray(total).also { dst ->
                var pos = 0
                for (seg in segments) {
                    System.arraycopy(seg, 0, dst, pos, seg.size)
                    pos += seg.size
                }
            }
        } else {
            samples
        }

        val t0 = SystemClock.elapsedRealtime()
        val stream = recognizer.createStream()
        return try {
            stream.acceptWaveform(audioForDecode, 16000)
            recognizer.decode(stream)
            val text = recognizer.getResult(stream).text.trim()
            val ms = (SystemClock.elapsedRealtime() - t0).toInt()
            mapOf(
                "transcript" to text,
                "locale" to locale,
                "engine" to "sherpa-onnx-indicconformer",
                "inferenceMs" to ms,
                "vadMs" to (vadRes["vadMs"] ?: 0)
            )
        } finally {
            stream.release()
        }
    }

    private fun recordAudio16k(maxDurationMs: Int): FloatArray {
        val minBuf = AudioRecord.getMinBufferSize(
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(3200)
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuf
        )
        val totalSamples = (16000 * maxDurationMs) / 1000
        val out = FloatArray(totalSamples)
        val buf = ShortArray(1024)
        var captured = 0
        try {
            recorder.startRecording()
            while (captured < totalSamples) {
                val read = recorder.read(buf, 0, min(buf.size, totalSamples - captured))
                if (read <= 0) break
                for (i in 0 until read) {
                    out[captured++] = buf[i] / 32768.0f
                }
            }
        } finally {
            try {
                recorder.stop()
            } catch (_: Throwable) {
            }
            recorder.release()
        }
        return if (captured == totalSamples) out else out.copyOf(captured)
    }

    private fun recognizeViaAndroidOnDevice(locale: String): Map<String, Any> {
        val latch = CountDownLatch(1)
        var transcript: String? = null
        var errorCode: Int? = null

        mainHandler.post {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                latch.countDown()
                return@post
            }
            val sr = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            sr.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onPartialResults(partialResults: Bundle?) = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit
                override fun onError(error: Int) {
                    errorCode = error
                    sr.destroy()
                    latch.countDown()
                }

                override fun onResults(results: Bundle?) {
                    val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    transcript = list?.firstOrNull()
                    sr.destroy()
                    latch.countDown()
                }
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
            sr.startListening(intent)
        }

        latch.await(6000, TimeUnit.MILLISECONDS)
        if (transcript.isNullOrBlank()) {
            throw IllegalStateException("On-device speech recognizer returned no speech (code=$errorCode)")
        }
        return mapOf(
            "transcript" to transcript!!,
            "locale" to locale,
            "engine" to "android-ondevice-speech",
            "inferenceMs" to 0
        )
    }

    private fun runOnWorker(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("INTEGRITY_ERROR", e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("SPEECH_ERROR", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
        worker.execute {
            try {
                vad?.release()
            } catch (_: Throwable) {
            }
            recognizers.values.forEach {
                try {
                    it.release()
                } catch (_: Throwable) {
                }
            }
            recognizers.clear()
        }
        worker.shutdown()
    }
}
