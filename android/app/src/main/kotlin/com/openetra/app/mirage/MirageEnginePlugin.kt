package com.openetra.app.mirage

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.exifinterface.media.ExifInterface
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class MirageEnginePlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.openetra.app/mirage")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "OpenetraMirageWorker").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "provisionAssetModel" -> {
                val assetKey = call.argument<String>("assetPath") ?: "assets/models/mirage.cact"
                val destPath = call.argument<String>("destPath")
                val expectedSha256 = call.argument<String>("expectedSha256")
                if (destPath.isNullOrBlank() || expectedSha256.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "destPath and expectedSha256 are required", null)
                    return
                }
                runOnWorker(result) {
                    provisionAsset(assetKey, destPath, expectedSha256)
                }
            }

            "loadModel" -> {
                val path = call.argument<String>("path")
                val expectedSha256 = call.argument<String>("expectedSha256")
                val threads = call.argument<Int>("threads") ?: 0
                if (path.isNullOrBlank() || expectedSha256.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "path and expectedSha256 are required", null)
                    return
                }
                runOnWorker(result) {
                    loadVerifiedModel(path, expectedSha256, threads)
                }
            }

            "describeRgb" -> {
                val rgb = call.argument<ByteArray>("rgbBytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val optionsJson = call.argument<String>("optionsJson") ?: "{}"
                val language = call.argument<String>("language")
                val keywords = call.argument<String>("keywords")
                if (rgb == null || width <= 0 || height <= 0) {
                    result.error("INVALID_ARGS", "Valid rgbBytes, width, and height required", null)
                    return
                }
                runOnWorker(result) {
                    describeRgbInternal(rgb, width, height, optionsJson, language, keywords)
                }
            }

            "describeImageFile" -> {
                val path = call.argument<String>("path")
                val optionsJson = call.argument<String>("optionsJson") ?: "{}"
                val language = call.argument<String>("language")
                val keywords = call.argument<String>("keywords")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Image path is required", null)
                    return
                }
                runOnWorker(result) {
                    val decoded = decodeFileToRgb24(path)
                    describeRgbInternal(
                        decoded.rgb,
                        decoded.width,
                        decoded.height,
                        optionsJson,
                        language,
                        keywords
                    )
                }
            }

            "setThreads" -> {
                val threads = call.argument<Int>("threads") ?: 0
                runOnWorker(result) {
                    MirageNativeBridge.nativeSetThreads(threads)
                    mapOf("threads" to threads)
                }
            }

            "status" -> {
                runOnWorker(result) {
                    mapOf("loaded" to MirageNativeBridge.nativeIsVisionLoaded())
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
                mainHandler.post { result.error("MIRAGE_ERROR", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    private fun provisionAsset(
        assetPath: String,
        destPath: String,
        expectedSha256: String
    ): Map<String, Any> {
        val expected = expectedSha256.trim().lowercase()
        val destFile = File(destPath)
        destFile.parentFile?.mkdirs()

        if (destFile.exists() && destFile.length() > 0) {
            val existingHash = computeFileSha256(destFile)
            if (existingHash == expected) {
                return mapOf("path" to destFile.absolutePath, "sha256" to existingHash, "cached" to true)
            }
        }

        val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        val tmpFile = File(destFile.parentFile, "${destFile.name}.tmp")
        val digest = MessageDigest.getInstance("SHA-256")
        val buf = ByteArray(64 * 1024)

        context.assets.open(lookupKey).use { input ->
            FileOutputStream(tmpFile).use { out ->
                while (true) {
                    val read = input.read(buf)
                    if (read <= 0) break
                    digest.update(buf, 0, read)
                    out.write(buf, 0, read)
                }
            }
        }

        val actualHash = digest.digest().joinToString("") { "%02x".format(it) }
        if (actualHash != expected) {
            tmpFile.delete()
            throw SecurityException("Bundled asset checksum mismatch: expected $expected, got $actualHash")
        }
        if (destFile.exists()) destFile.delete()
        if (!tmpFile.renameTo(destFile)) {
            throw IllegalStateException("Failed moving verified asset to ${destFile.absolutePath}")
        }
        return mapOf("path" to destFile.absolutePath, "sha256" to actualHash, "cached" to false)
    }

    private fun loadVerifiedModel(
        path: String,
        expectedSha256: String,
        threads: Int
    ): Map<String, Any> {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalStateException("Mirage model missing at $path")
        }
        val expected = expectedSha256.trim().lowercase()
        val actual = computeFileSha256(file)
        if (actual != expected) {
            throw SecurityException("Mirage SHA-256 verification failed: expected $expected, got $actual")
        }
        MirageNativeBridge.nativeSetThreads(threads)
        val t0 = SystemClock.elapsedRealtime()
        val mask = MirageNativeBridge.nativeLoadModelFile(path)
        val loadMs = (SystemClock.elapsedRealtime() - t0).toInt()
        return mapOf(
            "loaded" to true,
            "loadMs" to loadMs,
            "modelsMask" to mask,
            "sha256" to actual
        )
    }

    private fun describeRgbInternal(
        rgb: ByteArray,
        width: Int,
        height: Int,
        optionsJson: String,
        language: String?,
        keywords: String?
    ): Map<String, Any> {
        val q = MirageNativeBridge.nativeAnalyzeImageQuality(rgb, width, height)
        val t0 = SystemClock.elapsedRealtime()
        val jsonBytes = MirageNativeBridge.nativeDescribeRgb(
            rgb,
            width,
            height,
            optionsJson,
            language,
            keywords
        )
        val inferenceMs = (SystemClock.elapsedRealtime() - t0).toInt()
        val jsonText = String(jsonBytes, StandardCharsets.UTF_8)

        return mapOf(
            "json" to jsonText,
            "inferenceMs" to inferenceMs,
            "width" to width,
            "height" to height,
            "quality" to mapOf(
                "meanLuma" to q[0],
                "lumaStdDev" to q[1],
                "laplacianVariance" to q[2],
                "overexposedRatio" to q[3],
                "underexposedRatio" to q[4]
            )
        )
    }

    private data class DecodedRgb(val rgb: ByteArray, val width: Int, val height: Int)

    private fun decodeFileToRgb24(path: String): DecodedRgb {
        val raw = BitmapFactory.decodeFile(path)
            ?: throw IllegalArgumentException("Failed to decode image at $path")
        val exif = ExifInterface(path)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )
        val rotation = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val rotated = if (rotation != 0f) {
            val matrix = Matrix().apply { postRotate(rotation) }
            Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, matrix, true).also {
                if (it != raw) raw.recycle()
            }
        } else {
            raw
        }

        val maxDim = max(rotated.width, rotated.height)
        val finalBmp = if (maxDim > 640) {
            val scale = 640.0 / maxDim.toDouble()
            val nw = max(1, (rotated.width * scale).roundToInt())
            val nh = max(1, (rotated.height * scale).roundToInt())
            Bitmap.createScaledBitmap(rotated, nw, nh, true).also {
                if (it != rotated) rotated.recycle()
            }
        } else {
            rotated
        }

        val argbBmp = if (finalBmp.config != Bitmap.Config.ARGB_8888) {
            finalBmp.copy(Bitmap.Config.ARGB_8888, false).also { finalBmp.recycle() }
        } else {
            finalBmp
        }

        val w = argbBmp.width
        val h = argbBmp.height
        val pixels = IntArray(w * h)
        argbBmp.getPixels(pixels, 0, w, 0, 0, w, h)
        argbBmp.recycle()

        val rgb = ByteArray(w * h * 3)
        var outIdx = 0
        for (px in pixels) {
            rgb[outIdx++] = ((px shr 16) and 0xFF).toByte()
            rgb[outIdx++] = ((px shr 8) and 0xFF).toByte()
            rgb[outIdx++] = (px and 0xFF).toByte()
        }
        return DecodedRgb(rgb, w, h)
    }

    private fun computeFileSha256(file: File): String {
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

    fun release() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
