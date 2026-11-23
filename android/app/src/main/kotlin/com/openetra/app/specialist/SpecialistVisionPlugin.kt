package com.openetra.app.specialist

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.openetra.app.ocr.IndicOcrPlugin
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class SpecialistVisionPlugin(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger
) : io.flutter.plugin.common.MethodChannel.MethodCallHandler {

    companion object {
        const val EMBEDDING_MODEL_ID = "openetra-hsv-edge-embed96"
        const val EMBEDDING_DIM = 96

        fun scanBarcodeBitmap(bitmap: Bitmap): Map<String, Any> {
            val scanner = BarcodeScanning.getClient()
            return try {
                val t0 = SystemClock.elapsedRealtime()
                val barcodes = Tasks.await(scanner.process(InputImage.fromBitmap(bitmap, 0)))
                val ms = (SystemClock.elapsedRealtime() - t0).toInt()
                val list = barcodes.mapNotNull { b ->
                    val raw = b.rawValue ?: return@mapNotNull null
                    mapOf("rawValue" to raw, "format" to b.format)
                }
                mapOf("barcodes" to list, "scanMs" to ms)
            } finally {
                scanner.close()
            }
        }

        /**
         * Computes a fast L2-normalized 96-dimensional visual appearance descriptor
         * inside the normalized [0..1000] crop:
         * - 48 HSV color distribution bins (16 hue x 3 saturation/value tiers)
         * - 32 spatial 4x4 grid mean + contrast luminance features
         * - 16 gradient edge orientation histogram bins
         */
        fun computeCropDescriptor96(
            rgb: ByteArray,
            width: Int,
            height: Int,
            x1Norm: Int,
            y1Norm: Int,
            x2Norm: Int,
            y2Norm: Int
        ): FloatArray {
            require(width > 0 && height > 0) { "Invalid image dimensions" }
            require(rgb.size == width * height * 3) { "RGB length mismatch" }

            val px1 = ((min(x1Norm, x2Norm).coerceIn(0, 1000) * width) / 1000).coerceIn(0, width - 1)
            val py1 = ((min(y1Norm, y2Norm).coerceIn(0, 1000) * height) / 1000).coerceIn(0, height - 1)
            val px2 = ((max(x1Norm, x2Norm).coerceIn(0, 1000) * width) / 1000).coerceIn(px1 + 1, width)
            val py2 = ((max(y1Norm, y2Norm).coerceIn(0, 1000) * height) / 1000).coerceIn(py1 + 1, height)

            val cw = max(1, px2 - px1)
            val ch = max(1, py2 - py1)
            val step = max(1, max(cw, ch) / 64)

            val vec = FloatArray(EMBEDDING_DIM)
            val hsv = FloatArray(3)
            val cellSum = FloatArray(16)
            val cellSq = FloatArray(16)
            val cellCnt = IntArray(16)
            var totalSamples = 0

            var y = py1
            while (y < py2) {
                val cellY = min(3, ((y - py1) * 4) / ch)
                var x = px1
                while (x < px2) {
                    val idx = (y * width + x) * 3
                    val r = rgb[idx].toInt() and 0xFF
                    val g = rgb[idx + 1].toInt() and 0xFF
                    val b = rgb[idx + 2].toInt() and 0xFF

                    Color.RGBToHSV(r, g, b, hsv)
                    val hBin = min(15, ((hsv[0] / 360.0f) * 16.0f).toInt().coerceAtLeast(0))
                    val svTier = when {
                        hsv[2] < 0.25f -> 0
                        hsv[1] < 0.25f -> 1
                        else -> 2
                    }
                    vec[hBin * 3 + svTier] += 1.0f

                    val luma = (0.299f * r + 0.587f * g + 0.114f * b) / 255.0f
                    val cellX = min(3, ((x - px1) * 4) / cw)
                    val cellIdx = cellY * 4 + cellX
                    cellSum[cellIdx] += luma
                    cellSq[cellIdx] += luma * luma
                    cellCnt[cellIdx]++

                    if (x + step < px2 && y + step < py2) {
                        val rightIdx = (y * width + (x + step)) * 3
                        val downIdx = ((y + step) * width + x) * 3
                        val lRight = (0.299f * (rgb[rightIdx].toInt() and 0xFF) +
                            0.587f * (rgb[rightIdx + 1].toInt() and 0xFF) +
                            0.114f * (rgb[rightIdx + 2].toInt() and 0xFF)) / 255.0f
                        val lDown = (0.299f * (rgb[downIdx].toInt() and 0xFF) +
                            0.587f * (rgb[downIdx + 1].toInt() and 0xFF) +
                            0.114f * (rgb[downIdx + 2].toInt() and 0xFF)) / 255.0f
                        val gx = lRight - luma
                        val gy = lDown - luma
                        val mag = sqrt(gx * gx + gy * gy)
                        if (mag > 0.02f) {
                            var angle = atan2(gy, gx) + Math.PI.toFloat()
                            if (angle < 0f) angle = 0f
                            val eBin = min(15, ((angle / (2.0f * Math.PI.toFloat())) * 16.0f).toInt())
                            vec[80 + eBin] += mag
                        }
                    }

                    totalSamples++
                    x += step
                }
                y += step
            }

            if (totalSamples > 0) {
                for (i in 0 until 48) {
                    vec[i] /= totalSamples.toFloat()
                }
            }
            for (c in 0 until 16) {
                val n = max(1, cellCnt[c]).toFloat()
                val mean = cellSum[c] / n
                val varVal = max(0f, (cellSq[c] / n) - (mean * mean))
                vec[48 + c] = mean
                vec[64 + c] = sqrt(varVal)
            }

            var normSq = 0.0f
            for (v in vec) normSq += v * v
            val norm = sqrt(normSq)
            if (norm > 1e-6f) {
                for (i in vec.indices) vec[i] /= norm
            }
            return vec
        }

        private fun sha256(file: File): String {
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

    private val channel = io.flutter.plugin.common.MethodChannel(messenger, "com.openetra.app/specialist")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "OpenetraSpecialistWorker").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currencyInterpreter: Interpreter? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        when (call.method) {
            "status" -> {
                result.success(
                    mapOf(
                        "barcodeAvailable" to true,
                        "embeddingAvailable" to true,
                        "litertAvailable" to true,
                        "currencyModelLoaded" to (currencyInterpreter != null)
                    )
                )
            }

            "scanBarcodeRgb" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "rgbBytes, width, and height required", null)
                    return
                }
                runOnWorker(result) {
                    val bmp = IndicOcrPlugin.rgbToBitmap(rgb, width, height)
                    try {
                        scanBarcodeBitmap(bmp)
                    } finally {
                        bmp.recycle()
                    }
                }
            }

            "computeCropEmbeddingRgb" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val x1 = call.argument<Int>("x1") ?: 0
                val y1 = call.argument<Int>("y1") ?: 0
                val x2 = call.argument<Int>("x2") ?: 1000
                val y2 = call.argument<Int>("y2") ?: 1000
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "rgbBytes, width, and height required", null)
                    return
                }
                runOnWorker(result) {
                    val t0 = SystemClock.elapsedRealtime()
                    val vec = computeCropDescriptor96(rgb, width, height, x1, y1, x2, y2)
                    val ms = (SystemClock.elapsedRealtime() - t0).toInt()
                    mapOf(
                        "embedding" to vec.map { it.toDouble() },
                        "dimension" to EMBEDDING_DIM,
                        "modelId" to EMBEDDING_MODEL_ID,
                        "elapsedMs" to ms
                    )
                }
            }

            "loadCurrencyModel" -> {
                val path = call.argument<String>("path")
                val expectedSha = call.argument<String>("expectedSha256")
                if (path.isNullOrBlank() || expectedSha.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "path and expectedSha256 required", null)
                    return
                }
                runOnWorker(result) {
                    val file = File(path)
                    if (!file.exists()) {
                        throw IllegalStateException("Currency LiteRT model missing at $path")
                    }
                    val actual = sha256(file)
                    if (actual != expectedSha.trim().lowercase()) {
                        throw SecurityException("Currency LiteRT model checksum mismatch")
                    }
                    currencyInterpreter?.close()
                    val opts = Interpreter.Options().setNumThreads(2).setUseXNNPACK(true)
                    currencyInterpreter = Interpreter(file, opts)
                    mapOf("loaded" to true)
                }
            }

            "classifyCurrencyRgb" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "rgbBytes, width, and height required", null)
                    return
                }
                val interp = currencyInterpreter
                if (interp == null) {
                    result.success(mapOf("available" to false))
                    return
                }
                runOnWorker(result) {
                    runCurrencyInterpreter(interp, rgb, width, height)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun runCurrencyInterpreter(
        interp: Interpreter,
        rgb: ByteArray,
        width: Int,
        height: Int
    ): Map<String, Any> {
        val bmp = IndicOcrPlugin.rgbToBitmap(rgb, width, height)
        val scaled = Bitmap.createScaledBitmap(bmp, 224, 224, true)
        if (scaled != bmp) bmp.recycle()

        val pixels = IntArray(224 * 224)
        scaled.getPixels(pixels, 0, 224, 0, 0, 224, 224)
        scaled.recycle()

        val inTensor = interp.getInputTensor(0)
        val isUint8 = inTensor.dataType() == DataType.UINT8
        val inputBuf = ByteBuffer.allocateDirect(
            if (isUint8) 224 * 224 * 3 else 224 * 224 * 3 * 4
        ).order(ByteOrder.nativeOrder())

        for (px in pixels) {
            val r = (px shr 16) and 0xFF
            val g = (px shr 8) and 0xFF
            val b = px and 0xFF
            if (isUint8) {
                inputBuf.put(r.toByte())
                inputBuf.put(g.toByte())
                inputBuf.put(b.toByte())
            } else {
                inputBuf.putFloat(r / 255.0f)
                inputBuf.putFloat(g / 255.0f)
                inputBuf.putFloat(b / 255.0f)
            }
        }
        inputBuf.rewind()

        val outCount = interp.getOutputTensor(0).shape().last().coerceAtLeast(6)
        val outBuf = Array(1) { FloatArray(outCount) }
        val t0 = SystemClock.elapsedRealtime()
        interp.run(inputBuf, outBuf)
        val ms = (SystemClock.elapsedRealtime() - t0).toInt()

        val denoms = listOf("10", "20", "50", "100", "200", "500")
        val scores = mutableMapOf<String, Double>()
        for (i in denoms.indices) {
            if (i < outBuf[0].size) {
                scores[denoms[i]] = outBuf[0][i].toDouble()
            }
        }
        return mapOf(
            "available" to true,
            "scores" to scores,
            "inferenceMs" to ms
        )
    }

    private fun runOnWorker(
        result: io.flutter.plugin.common.MethodChannel.Result,
        block: () -> Any?
    ) {
        worker.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("INTEGRITY_ERROR", e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("SPECIALIST_ERROR", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
        worker.execute {
            try {
                currencyInterpreter?.close()
            } catch (_: Throwable) {
            }
        }
        worker.shutdown()
    }
}
