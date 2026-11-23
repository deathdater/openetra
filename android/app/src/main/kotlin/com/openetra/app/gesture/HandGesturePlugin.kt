package com.openetra.app.gesture

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Offline hand landmark inference plugin (`com.openetra.app/gesture`) running
 * Apache-2.0 MediaPipe `hand_landmarks_detector.tflite` via Openetra's bundled
 * LiteRT 1.4.2 XNNPACK runtime.
 *
 * Input:  `input_1` [1, 224, 224, 3] FLOAT32 RGB in [0.0, 1.0].
 * Output:
 *   0 (`Identity`):   [1, 63] FLOAT32 (21 image landmarks x,y,z scaled 0..224)
 *   1 (`Identity_1`): [1, 1]  FLOAT32 (hand presence probability)
 *   2 (`Identity_2`): [1, 1]  FLOAT32 (handedness probability)
 *   3 (`Identity_3`): [1, 63] FLOAT32 (21 world landmarks)
 *
 * Raw camera frames and video are NEVER persisted to disk.
 */
class HandGesturePlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val ASSET_PATH = "assets/models/gesture/hand_landmarks_detector.tflite"
        const val EXPECTED_SHA256 =
            "6acda74af3fbf40e68265c20c7394b2bad81a16a481dcd79ad7a081887c3d6b9"
        const val INPUT_SIZE = 224
        const val LANDMARK_VALUES = 63

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

        private fun resolveAssetKey(): String {
            return try {
                FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(ASSET_PATH)
            } catch (_: Throwable) {
                "flutter_assets/$ASSET_PATH"
            }
        }

        fun ensureModelFile(context: Context): File {
            val dir = File(context.filesDir, "models/gesture")
            if (!dir.exists()) dir.mkdirs()
            val outFile = File(dir, "hand_landmarks_detector.tflite")
            if (outFile.exists() && sha256(outFile) == EXPECTED_SHA256) {
                return outFile
            }
            val assetKey = resolveAssetKey()
            val candidates = listOf(assetKey, "flutter_assets/$ASSET_PATH", ASSET_PATH).distinct()
            var copied = false
            var lastError: Throwable? = null
            for (cand in candidates) {
                try {
                    context.assets.open(cand).use { input ->
                        FileOutputStream(outFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    copied = true
                    break
                } catch (e: Throwable) {
                    lastError = e
                }
            }
            if (!copied) {
                throw IllegalStateException(
                    "Hand landmark model asset not found: ${lastError?.message}"
                )
            }
            val actual = sha256(outFile)
            if (actual != EXPECTED_SHA256) {
                outFile.delete()
                throw SecurityException(
                    "Hand landmark model SHA-256 mismatch: expected=$EXPECTED_SHA256 actual=$actual"
                )
            }
            return outFile
        }

        fun createInterpreter(modelFile: File, threads: Int = 2): Interpreter {
            val opts = Interpreter.Options().apply {
                setNumThreads(threads.coerceIn(1, 4))
                setUseXNNPACK(true)
            }
            return Interpreter(modelFile, opts)
        }

        fun runInferenceOnRgb(
            interpreter: Interpreter,
            rgbBytes: ByteArray,
            width: Int,
            height: Int
        ): Map<String, Any> {
            require(width > 0 && height > 0) { "Invalid frame dimensions" }
            require(rgbBytes.size >= width * height * 3) { "RGB buffer too small" }

            val t0 = SystemClock.elapsedRealtime()
            val inputBuffer = ByteBuffer.allocateDirect(INPUT_SIZE * INPUT_SIZE * 3 * 4)
                .order(ByteOrder.nativeOrder())

            val xScale = width.toFloat() / INPUT_SIZE.toFloat()
            val yScale = height.toFloat() / INPUT_SIZE.toFloat()
            for (dy in 0 until INPUT_SIZE) {
                val sy = (dy * yScale).toInt().coerceIn(0, height - 1)
                val rowOffset = sy * width * 3
                for (dx in 0 until INPUT_SIZE) {
                    val sx = (dx * xScale).toInt().coerceIn(0, width - 1)
                    val idx = rowOffset + sx * 3
                    val r = (rgbBytes[idx].toInt() and 0xFF) / 255.0f
                    val g = (rgbBytes[idx + 1].toInt() and 0xFF) / 255.0f
                    val b = (rgbBytes[idx + 2].toInt() and 0xFF) / 255.0f
                    inputBuffer.putFloat(r)
                    inputBuffer.putFloat(g)
                    inputBuffer.putFloat(b)
                }
            }
            inputBuffer.rewind()

            val imageLandmarks = Array(1) { FloatArray(LANDMARK_VALUES) }
            val presence = Array(1) { FloatArray(1) }
            val handedness = Array(1) { FloatArray(1) }
            val worldLandmarks = Array(1) { FloatArray(LANDMARK_VALUES) }

            val outputs = hashMapOf<Int, Any>(
                0 to imageLandmarks,
                1 to presence,
                2 to handedness,
                3 to worldLandmarks
            )
            interpreter.runForMultipleInputsOutputs(arrayOf(inputBuffer), outputs)

            val elapsedMs = (SystemClock.elapsedRealtime() - t0).toInt()
            val normalized = List(LANDMARK_VALUES) { i ->
                (imageLandmarks[0][i] / INPUT_SIZE.toFloat()).toDouble()
            }
            return mapOf(
                "landmarks" to normalized,
                "handPresenceScore" to presence[0][0].toDouble(),
                "handednessScore" to handedness[0][0].toDouble(),
                "inferenceMs" to elapsedMs
            )
        }
    }

    private val channel = MethodChannel(messenger, "com.openetra.app/gesture")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "OpenetraGestureWorker").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var interpreter: Interpreter? = null

    @Volatile
    private var lastLoadMs: Int = 0

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                result.success(
                    mapOf(
                        "modelLoaded" to (interpreter != null),
                        "expectedSha256" to EXPECTED_SHA256,
                        "lastLoadMs" to lastLoadMs
                    )
                )
            }

            "loadModel" -> {
                val threads = call.argument<Int>("threads") ?: 2
                worker.execute {
                    try {
                        val t0 = SystemClock.elapsedRealtime()
                        if (interpreter == null) {
                            val file = ensureModelFile(context)
                            interpreter = createInterpreter(file, threads)
                        }
                        lastLoadMs = (SystemClock.elapsedRealtime() - t0).toInt()
                        mainHandler.post {
                            result.success(
                                mapOf(
                                    "loaded" to true,
                                    "loadMs" to lastLoadMs
                                )
                            )
                        }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error("GESTURE_LOAD_FAILED", e.message ?: "Load failed", null)
                        }
                    }
                }
            }

            "unloadModel" -> {
                worker.execute {
                    interpreter?.close()
                    interpreter = null
                    mainHandler.post { result.success(mapOf("unloaded" to true)) }
                }
            }

            "extractLandmarksRgb" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "rgbBytes, width, and height required", null)
                    return
                }
                worker.execute {
                    try {
                        var interp = interpreter
                        if (interp == null) {
                            val file = ensureModelFile(context)
                            interp = createInterpreter(file, 2)
                            interpreter = interp
                        }
                        val out = runInferenceOnRgb(interp, rgb, width, height)
                        mainHandler.post { result.success(out) }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error(
                                "GESTURE_INFERENCE_FAILED",
                                e.message ?: "Inference failed",
                                null
                            )
                        }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
        worker.execute {
            interpreter?.close()
            interpreter = null
        }
        worker.shutdown()
    }
}
