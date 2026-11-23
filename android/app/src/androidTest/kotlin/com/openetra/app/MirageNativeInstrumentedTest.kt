package com.openetra.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.openetra.app.mirage.MirageNativeBridge
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

@RunWith(AndroidJUnit4::class)
class MirageNativeInstrumentedTest {

    companion object {
        private const val TAG = "OpenetraMirageAndroidTest"
        private const val EXPECTED_MIRAGE_SHA256 =
            "4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237"
    }

    private fun extractAsset(context: Context, assetName: String, outName: String): File {
        val outFile = File(context.filesDir, outName)
        context.assets.open("flutter_assets/$assetName").use { input ->
            FileOutputStream(outFile).use { output ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    output.write(buf, 0, n)
                }
            }
        }
        return outFile
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                digest.update(buf, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun decodeAssetRgb(context: Context, assetName: String): Triple<ByteArray, Int, Int> {
        val bmp = context.assets.open("flutter_assets/$assetName").use { stream ->
            BitmapFactory.decodeStream(stream)
        }
        val argb = if (bmp.config != Bitmap.Config.ARGB_8888) {
            bmp.copy(Bitmap.Config.ARGB_8888, false).also { bmp.recycle() }
        } else {
            bmp
        }
        val w = argb.width
        val h = argb.height
        val pixels = IntArray(w * h)
        argb.getPixels(pixels, 0, w, 0, 0, w, h)
        argb.recycle()

        val rgb = ByteArray(w * h * 3)
        var i = 0
        for (px in pixels) {
            rgb[i++] = ((px shr 16) and 0xFF).toByte()
            rgb[i++] = ((px shr 8) and 0xFF).toByte()
            rgb[i++] = (px and 0xFF).toByte()
        }
        return Triple(rgb, w, h)
    }

    @Test
    fun verifyMirageSha256LoadAndCocoInferenceOnAndroidArm64() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val modelFile = extractAsset(context, "assets/models/mirage.cact", "test_mirage.cact")
        val actualHash = sha256(modelFile)
        assertTrue("Mirage SHA-256 mismatch: $actualHash", actualHash == EXPECTED_MIRAGE_SHA256)

        MirageNativeBridge.nativeSetThreads(4)
        val tLoad0 = System.nanoTime()
        val mask = MirageNativeBridge.nativeLoadModelFile(modelFile.absolutePath)
        val loadMs = (System.nanoTime() - tLoad0) / 1_000_000.0
        assertTrue("Expected CACTUS_VISION bitmask, got $mask", (mask and 4) != 0)
        assertTrue(MirageNativeBridge.nativeIsVisionLoaded())
        Log.i(TAG, "ANDROID_MIRAGE_LOAD_MS=%.2f mask=%d".format(loadMs, mask))

        val options =
            """{"sections":["scene","objects","text","relations"],"fields":["bbox","score","position","description"]}"""

        val (stopRgb, stopW, stopH) =
            decodeAssetRgb(context, "assets/test_fixtures/stop_sign_231049.jpg")
        val stopQuality = MirageNativeBridge.nativeAnalyzeImageQuality(stopRgb, stopW, stopH)

        val t0 = System.nanoTime()
        val stopJsonCold = String(
            MirageNativeBridge.nativeDescribeRgb(stopRgb, stopW, stopH, options, "en", null),
            StandardCharsets.UTF_8
        )
        val stopColdMs = (System.nanoTime() - t0) / 1_000_000.0

        val t1 = System.nanoTime()
        val stopJsonWarm = String(
            MirageNativeBridge.nativeDescribeRgb(stopRgb, stopW, stopH, options, "en", null),
            StandardCharsets.UTF_8
        )
        val stopWarmMs = (System.nanoTime() - t1) / 1_000_000.0

        Log.i(
            TAG,
            "COCO_231049 cold_ms=%.2f warm_ms=%.2f luma=%.1f lap=%.1f json=%s".format(
                stopColdMs,
                stopWarmMs,
                stopQuality[0],
                stopQuality[2],
                stopJsonWarm
            )
        )
        assertTrue("Expected stop sign in $stopJsonCold", stopJsonCold.contains("stop sign", ignoreCase = true))
        assertTrue("Expected ARRET OCR in $stopJsonWarm", stopJsonWarm.contains("ARRET", ignoreCase = true))

        val (roomRgb, roomW, roomH) =
            decodeAssetRgb(context, "assets/test_fixtures/living_room_139.jpg")
        val t2 = System.nanoTime()
        val roomJson = String(
            MirageNativeBridge.nativeDescribeRgb(roomRgb, roomW, roomH, options, "en", null),
            StandardCharsets.UTF_8
        )
        val roomMs = (System.nanoTime() - t2) / 1_000_000.0
        Log.i(TAG, "COCO_139 warm_ms=%.2f json=%s".format(roomMs, roomJson))
        assertTrue("Expected living room in $roomJson", roomJson.contains("living room", ignoreCase = true))
        assertTrue("Expected chair in $roomJson", roomJson.contains("chair", ignoreCase = true))
    }
}
