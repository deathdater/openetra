package com.openetra.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import com.openetra.app.mirage.MirageNativeBridge
import com.openetra.app.ocr.IndicOcrPlugin
import com.openetra.app.specialist.SpecialistVisionPlugin
import com.openetra.app.speech.OfflineSpeechPlugin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

@RunWith(AndroidJUnit4::class)
class IndicAndSpecialistInstrumentedTest {

    companion object {
        private const val TAG = "OpenetraIndicSpecialistTest"
    }

    private fun renderHighContrastTextBitmap(text: String, width: Int = 800, height: Int = 220): Bitmap {
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(Color.WHITE)
        val paint = Paint().apply {
            color = Color.BLACK
            textSize = 56f
            isAntiAlias = true
        }
        canvas.drawText(text, 40f, 130f, paint)
        return bmp
    }

    private fun renderCode128Bitmap(content: String): Bitmap {
        val barWidth = 420
        val barHeight = 120
        val quietPadX = 40
        val quietPadY = 40
        val matrix = MultiFormatWriter().encode(content, BarcodeFormat.CODE_128, barWidth, barHeight)
        val totalW = barWidth + quietPadX * 2
        val totalH = barHeight + quietPadY * 2
        val pixels = IntArray(totalW * totalH) { Color.WHITE }
        for (y in 0 until matrix.height) {
            val rowOffset = (y + quietPadY) * totalW + quietPadX
            for (x in 0 until matrix.width) {
                if (matrix.get(x, y)) {
                    pixels[rowOffset + x] = Color.BLACK
                }
            }
        }
        return Bitmap.createBitmap(pixels, totalW, totalH, Bitmap.Config.ARGB_8888)
    }

    private fun extractAssetIfMissing(context: Context, assetName: String, outName: String): File {
        val outFile = File(context.filesDir, outName)
        if (outFile.exists() && outFile.length() > 0L) return outFile
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

    private fun cosine(a: FloatArray, b: FloatArray): Float {
        var dot = 0f
        var na = 0f
        var nb = 0f
        for (i in a.indices) {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        val denom = sqrt(na) * sqrt(nb)
        return if (denom <= 1e-6f) 0f else dot / denom
    }

    @Test
    fun verifyIndicOcrSileroVadBarcodeMirageFormAndEmbeddings() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        // 1 & 2. Hindi ML Kit + Tesseract hin, plus Kannada Tesseract kan.
        val hiBmp = renderHighContrastTextBitmap("नमस्ते निकास 500")
        val knBmp = renderHighContrastTextBitmap("ಬೆಂಗಳೂರು 500")
        try {
            val mlKitHi = IndicOcrPlugin.recognizeDevanagariMlKitBitmap(hiBmp)
            val mlMs = mlKitHi["inferenceMs"] as Int
            val mlText = (mlKitHi["fullText"] as String).trim()
            Log.i(TAG, "MLKIT_DEVANAGARI ms=%d text=%s".format(mlMs, mlText.replace('\n', ' ')))
            assertTrue(
                "Expected non-empty Devanagari/500 ML Kit OCR, got '$mlText'",
                mlText.isNotEmpty() && (mlText.any { it in '\u0900'..'\u097F' } || mlText.contains("500"))
            )

            val tessHi = IndicOcrPlugin.recognizeTesseractBitmap(context, hiBmp, "hin")
            val tessHiMs = tessHi["inferenceMs"] as Int
            val tessHiText = (tessHi["fullText"] as String).trim()
            Log.i(TAG, "TESS_HIN ms=%d text=%s".format(tessHiMs, tessHiText.replace('\n', ' ')))
            assertTrue("Expected non-empty Tesseract hin OCR", tessHiText.isNotEmpty())

            val tessKn = IndicOcrPlugin.recognizeTesseractBitmap(context, knBmp, "kan")
            val tessKnMs = tessKn["inferenceMs"] as Int
            val tessKnText = (tessKn["fullText"] as String).trim()
            Log.i(TAG, "TESS_KAN ms=%d text=%s".format(tessKnMs, tessKnText.replace('\n', ' ')))
            assertTrue("Expected non-empty Tesseract kan OCR", tessKnText.isNotEmpty())
        } finally {
            hiBmp.recycle()
            knBmp.recycle()
        }

        // 3. Silero VAD (sherpa-onnx 2.0.3 native runtime).
        val vadFile = OfflineSpeechPlugin.provisionSileroVad(context)
        val vad = OfflineSpeechPlugin.createVad(vadFile)
        try {
            val samples = FloatArray(32000)
            for (i in 16000 until 32000) {
                val t = (i - 16000) / 16000.0
                val carrier = 0.5 * sin(2.0 * PI * 300.0 * t) + 0.35 * sin(2.0 * PI * 600.0 * t)
                val env = 0.5 * (1.0 + sin(2.0 * PI * 4.0 * t))
                samples[i] = (carrier * env).toFloat()
            }
            val vadRes = OfflineSpeechPlugin.runVadOnSamples(vad, samples)
            val vadMs = vadRes["vadMs"] as Int
            val detected = vadRes["speechDetected"] as Boolean
            val segCount = vadRes["segmentCount"] as Int
            Log.i(TAG, "SILERO_VAD ms=%d detected=%b segments=%d".format(vadMs, detected, segCount))
            assertTrue("Expected non-negative VAD duration, got $vadMs", vadMs >= 0)
            assertTrue(vadRes.containsKey("speechDetected") && vadRes.containsKey("segmentCount"))
        } finally {
            vad.release()
        }

        // 4. ML Kit Barcode 17.3.0 with ZXing Code-128 EAN-style test payload.
        val barcodeBmp = renderCode128Bitmap("8901058851234")
        try {
            val barcodeRes = SpecialistVisionPlugin.scanBarcodeBitmap(barcodeBmp)
            val barcodeMs = barcodeRes["scanMs"] as Int
            @Suppress("UNCHECKED_CAST")
            val barcodes = barcodeRes["barcodes"] as List<Map<String, Any>>
            Log.i(TAG, "MLKIT_BARCODE ms=%d barcodes=%s".format(barcodeMs, barcodes.toString()))
            assertTrue(
                "Expected Code-128 '8901058851234' in $barcodes",
                barcodes.any { it["rawValue"] == "8901058851234" }
            )
        } finally {
            barcodeBmp.recycle()
        }

        // 5. Mirage constrained form mode + 96-dim visual crop embedding.
        if (!MirageNativeBridge.nativeIsVisionLoaded()) {
            val modelFile = extractAssetIfMissing(context, "assets/models/mirage.cact", "test_mirage.cact")
            MirageNativeBridge.nativeSetThreads(4)
            val mask = MirageNativeBridge.nativeLoadModelFile(modelFile.absolutePath)
            assertTrue("Expected vision bitmask, got $mask", (mask and 4) != 0)
        }

        val (stopRgb, stopW, stopH) =
            decodeAssetRgb(context, "assets/test_fixtures/stop_sign_231049.jpg")

        val formOptions = """{"form":{"sign":{"enum":["stop","yield","speed limit"]}}}"""
        val tForm0 = System.nanoTime()
        val formJson = String(
            MirageNativeBridge.nativeDescribeRgb(stopRgb, stopW, stopH, formOptions, "en", null),
            StandardCharsets.UTF_8
        )
        val formMs = (System.nanoTime() - tForm0) / 1_000_000.0
        Log.i(TAG, "MIRAGE_FORM ms=%.2f json=%s".format(formMs, formJson))
        assertTrue("Expected 'stop' in Mirage form JSON: $formJson", formJson.contains("stop", ignoreCase = true))

        val tEmb0 = System.nanoTime()
        val embSign = SpecialistVisionPlugin.computeCropDescriptor96(stopRgb, stopW, stopH, 377, 238, 643, 436)
        val embMs = (System.nanoTime() - tEmb0) / 1_000_000.0
        val embCorner = SpecialistVisionPlugin.computeCropDescriptor96(stopRgb, stopW, stopH, 0, 0, 200, 200)

        assertEquals(96, embSign.size)
        var normSq = 0f
        for (v in embSign) normSq += v * v
        val norm = sqrt(normSq)
        val selfCos = cosine(embSign, embSign)
        val diffCos = cosine(embSign, embCorner)
        Log.i(TAG, "EMBED96 ms=%.2f norm=%.4f selfCos=%.4f diffCos=%.4f".format(embMs, norm, selfCos, diffCos))
        assertTrue("Expected unit L2 norm in [0.99, 1.01], got $norm", norm in 0.99f..1.01f)
        assertTrue("Expected self cosine >= 0.999, got $selfCos", selfCos >= 0.999f)
        assertTrue("Expected distinct crop cosine < 0.99, got $diffCos", diffCos < 0.99f)
    }
}
