package com.openetra.app.ocr

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

class IndicOcrPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val HIN_SHA256 =
            "4c73ffc59d497c186b19d1e90f5d721d678ea6b2e277b719bee4e2af12271825"
        const val MAR_SHA256 =
            "0ba3f2d116972e72fe9e176bc84c38e81dfb6670f4ed1f7f6c8e16a27da7cb61"
        const val KAN_SHA256 =
            "bd31e6b6ae93271e3bcf5383d306d8eefbb91542937cd6d735a5930c970e61d8"
        const val TAM_SHA256 =
            "d02fbec24be4b07e32e80d0ccfc3b6b67a3c5d61c9d0a7c8532677990912c6ec"
        const val TEL_SHA256 =
            "d10691fddd5b67802e1c12800ebb321d3b8bcd8d24a2ac3ff206f93188c04ab5"
        const val MAL_SHA256 =
            "bd05cbf1b197e7810d2903419aedb06f9ef77bfedf50b358673c1d18d707cdb4"
        const val BEN_SHA256 =
            "31163084c279aaebd376216f0c3d5c17ad4b5fee8db49dae79c20000b5de5964"

        private val bundledTrainedData = mapOf(
            "hin" to ("assets/models/tessdata/hin.traineddata" to HIN_SHA256),
            "mar" to ("assets/models/tessdata/mar.traineddata" to MAR_SHA256),
            "kan" to ("assets/models/tessdata/kan.traineddata" to KAN_SHA256),
            "tam" to ("assets/models/tessdata/tam.traineddata" to TAM_SHA256),
            "tel" to ("assets/models/tessdata/tel.traineddata" to TEL_SHA256),
            "mal" to ("assets/models/tessdata/mal.traineddata" to MAL_SHA256),
            "ben" to ("assets/models/tessdata/ben.traineddata" to BEN_SHA256)
        )

        fun rgbToBitmap(rgb: ByteArray, width: Int, height: Int): Bitmap {
            require(width > 0 && height > 0) { "Invalid image dimensions" }
            require(rgb.size == width * height * 3) { "RGB byte length mismatch" }
            val pixels = IntArray(width * height)
            var p = 0
            for (i in pixels.indices) {
                val r = rgb[p++].toInt() and 0xFF
                val g = rgb[p++].toInt() and 0xFF
                val b = rgb[p++].toInt() and 0xFF
                pixels[i] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
            return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
        }

        fun ensureTessDataProvisioned(context: Context, langCode: String): File {
            val tessRoot = File(context.filesDir, "tesseract")
            val tessDataDir = File(tessRoot, "tessdata")
            tessDataDir.mkdirs()
            val outFile = File(tessDataDir, "$langCode.traineddata")
            val bundled = bundledTrainedData[langCode]
            if (bundled == null) {
                if (!outFile.exists() || outFile.length() == 0L) {
                    throw IllegalStateException("Offline Tesseract pack '$langCode' is not installed")
                }
                return tessRoot
            }

            val (assetPath, expectedHash) = bundled
            if (outFile.exists() && outFile.length() > 0L) {
                if (sha256(outFile) == expectedHash) {
                    return tessRoot
                }
            }

            val lookupKey = runCatching {
                FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            }.getOrElse { "flutter_assets/$assetPath" }
            val tmpFile = File(tessDataDir, "$langCode.traineddata.tmp")
            val digest = MessageDigest.getInstance("SHA-256")
            val buf = ByteArray(64 * 1024)
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
            val actualHash = digest.digest().joinToString("") { "%02x".format(it) }
            if (actualHash != expectedHash) {
                tmpFile.delete()
                throw SecurityException(
                    "Checksum mismatch for $langCode.traineddata: expected $expectedHash, got $actualHash"
                )
            }
            if (outFile.exists()) outFile.delete()
            if (!tmpFile.renameTo(outFile)) {
                throw IllegalStateException("Failed saving $langCode.traineddata")
            }
            return tessRoot
        }

        fun recognizeDevanagariMlKitBitmap(bitmap: Bitmap): Map<String, Any> {
            val recognizer = TextRecognition.getClient(
                DevanagariTextRecognizerOptions.Builder().build()
            )
            return try {
                val t0 = SystemClock.elapsedRealtime()
                val result = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)))
                val ms = (SystemClock.elapsedRealtime() - t0).toInt()
                val w = max(1, bitmap.width)
                val h = max(1, bitmap.height)
                val lines = mutableListOf<Map<String, Any>>()

                for (block in result.textBlocks) {
                    for (line in block.lines) {
                        val box = line.boundingBox
                        val x1 = if (box != null) ((box.left * 1000) / w).coerceIn(0, 1000) else 0
                        val y1 = if (box != null) ((box.top * 1000) / h).coerceIn(0, 1000) else 0
                        val x2 = if (box != null) ((box.right * 1000) / w).coerceIn(0, 1000) else 1000
                        val y2 = if (box != null) ((box.bottom * 1000) / h).coerceIn(0, 1000) else 1000
                        val rawConf = line.confidence
                        val conf = if (rawConf in 0.0f..1.0f) rawConf.toDouble() else 0.85
                        lines.add(
                            mapOf(
                                "text" to line.text,
                                "bbox" to listOf(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2)),
                                "confidence" to conf
                            )
                        )
                    }
                }

                mapOf(
                    "engine" to "mlkit-text-devanagari",
                    "inferenceMs" to ms,
                    "fullText" to result.text,
                    "lines" to lines
                )
            } finally {
                recognizer.close()
            }
        }

        fun recognizeTesseractBitmap(
            context: Context,
            bitmap: Bitmap,
            langCode: String
        ): Map<String, Any> {
            val tessRoot = ensureTessDataProvisioned(context, langCode)
            val tess = TessBaseAPI()
            return try {
                val ok = tess.init(tessRoot.absolutePath, langCode)
                if (!ok) {
                    throw IllegalStateException("TessBaseAPI.init failed for $langCode")
                }
                val t0 = SystemClock.elapsedRealtime()
                tess.setImage(bitmap)
                val fullText = (tess.utF8Text ?: "").trim()
                val meanConf = (tess.meanConfidence().coerceIn(0, 100)) / 100.0
                val w = max(1, bitmap.width)
                val h = max(1, bitmap.height)
                val lines = mutableListOf<Map<String, Any>>()

                val iter = tess.resultIterator
                if (iter != null) {
                    iter.begin()
                    do {
                        val lineText = iter.getUTF8Text(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE)?.trim()
                        if (!lineText.isNullOrEmpty()) {
                            val box = iter.getBoundingBox(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE)
                            val x1 = if (box != null && box.size >= 4) ((box[0] * 1000) / w).coerceIn(0, 1000) else 0
                            val y1 = if (box != null && box.size >= 4) ((box[1] * 1000) / h).coerceIn(0, 1000) else 0
                            val x2 = if (box != null && box.size >= 4) ((box[2] * 1000) / w).coerceIn(0, 1000) else 1000
                            val y2 = if (box != null && box.size >= 4) ((box[3] * 1000) / h).coerceIn(0, 1000) else 1000
                            val lineConf = (iter.confidence(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE) / 100.0f)
                                .coerceIn(0.0f, 1.0f)
                                .toDouble()
                            lines.add(
                                mapOf(
                                    "text" to lineText,
                                    "bbox" to listOf(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2)),
                                    "confidence" to if (lineConf > 0.0) lineConf else meanConf
                                )
                            )
                        }
                    } while (iter.next(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE))
                    iter.delete()
                }
                val ms = (SystemClock.elapsedRealtime() - t0).toInt()
                mapOf(
                    "engine" to "tesseract-fast-$langCode",
                    "inferenceMs" to ms,
                    "fullText" to fullText,
                    "lines" to lines
                )
            } finally {
                tess.recycle()
            }
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

    private val channel = MethodChannel(messenger, "com.openetra.app/indic_ocr")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "OpenetraIndicOcrWorker").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkInstalledPacks" -> {
                runOnWorker(result) {
                    mapOf(
                        "devanagari" to true, // bundled ML Kit + hin/mar.traineddata
                        "kannada" to true, // bundled kan.traineddata
                        "tamil" to true, // bundled tam.traineddata
                        "telugu" to true, // bundled tel.traineddata
                        "malayalam" to true, // bundled mal.traineddata
                        "bengali" to true // bundled ben.traineddata
                    )
                }
            }

            "recognizeDevanagariMlKit" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "rgbBytes, width, and height required", null)
                    return
                }
                runOnWorker(result) {
                    val bmp = rgbToBitmap(rgb, width, height)
                    try {
                        recognizeDevanagariMlKitBitmap(bmp)
                    } finally {
                        bmp.recycle()
                    }
                }
            }

            "recognizeTesseract" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val langCode = call.argument<String>("langCode") ?: "kan"
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "rgbBytes, width, and height required", null)
                    return
                }
                runOnWorker(result) {
                    val bmp = rgbToBitmap(rgb, width, height)
                    try {
                        recognizeTesseractBitmap(context, bmp, langCode)
                    } finally {
                        bmp.recycle()
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun runOnWorker(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("INTEGRITY_ERROR", e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("INDIC_OCR_ERROR", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
