package com.openetra.app.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Size
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.openetra.app.mirage.MirageNativeBridge
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.atan2

class CameraXCaptureManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, SensorEventListener {

    private val channel = MethodChannel(messenger, "com.openetra.app/camera")
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "OpenetraCameraAnalysis").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val pendingCapture = AtomicReference<MethodChannel.Result?>(null)

    @Volatile
    private var cameraProvider: ProcessCameraProvider? = null

    @Volatile
    private var boundCamera: Camera? = null

    @Volatile
    private var latestPitchDegrees: Double = 0.0

    @Volatile
    private var latestMeanLuma: Double = -1.0

    @Volatile
    private var isStarted: Boolean = false

    fun isCameraActive(): Boolean = isStarted && boundCamera != null

    fun currentMeanLuma(): Double = latestMeanLuma

    fun setCameraTorch(enabled: Boolean): Boolean {
        val cam = boundCamera ?: return false
        if (!cam.cameraInfo.hasFlashUnit()) return false
        cam.cameraControl.enableTorch(enabled)
        return true
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startCamera" -> startCamera(result)
            "stopCamera" -> {
                stopCamera()
                result.success(null)
            }
            "captureFrame" -> captureNextFrame(result)
            else -> result.notImplemented()
        }
    }

    private fun startCamera(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("CAMERA_PERMISSION", "Camera permission has not been granted", null)
            return
        }
        if (isStarted) {
            result.success(null)
            return
        }

        val accel = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accel != null) {
            sensorManager?.registerListener(this, accel, SensorManager.SENSOR_DELAY_UI)
        }

        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider
                val analysis = ImageAnalysis.Builder()
                    .setTargetResolution(Size(640, 480))
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                    .build()

                analysis.setAnalyzer(analysisExecutor) { image ->
                    handleFrame(image)
                }

                provider.unbindAll()
                boundCamera = provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    analysis
                )
                isStarted = true
                result.success(null)
            } catch (e: Throwable) {
                result.error("CAMERA_INIT_ERROR", e.message ?: "Failed starting CameraX", null)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun captureNextFrame(result: MethodChannel.Result) {
        if (!isStarted) {
            result.error("CAMERA_NOT_STARTED", "Camera must be started before capture", null)
            return
        }
        val previous = pendingCapture.getAndSet(result)
        previous?.let { old ->
            mainHandler.post { old.error("CAPTURE_SUPERSEDED", "Superseded by newer capture request", null) }
        }
        mainHandler.postDelayed({
            if (pendingCapture.compareAndSet(result, null)) {
                result.error("CAPTURE_TIMEOUT", "Timed out waiting for next camera frame", null)
            }
        }, 3000L)
    }

    private fun handleFrame(image: ImageProxy) {
        try {
            val callback = pendingCapture.getAndSet(null) ?: return
            val converted = yuv420ToPackedRgb24(image)
            val q = MirageNativeBridge.nativeAnalyzeImageQuality(
                converted.rgb,
                converted.width,
                converted.height
            )
            latestMeanLuma = q[0]
            val payload = mapOf(
                "rgbBytes" to converted.rgb,
                "width" to converted.width,
                "height" to converted.height,
                "pitchDegrees" to latestPitchDegrees,
                "quality" to mapOf(
                    "meanLuma" to q[0],
                    "lumaStdDev" to q[1],
                    "laplacianVariance" to q[2],
                    "overexposedRatio" to q[3],
                    "underexposedRatio" to q[4]
                )
            )
            mainHandler.post { callback.success(payload) }
        } catch (e: Throwable) {
            pendingCapture.getAndSet(null)?.let { cb ->
                mainHandler.post { cb.error("FRAME_CONVERT_ERROR", e.message, null) }
            }
        } finally {
            image.close()
        }
    }

    private data class RgbFrame(val rgb: ByteArray, val width: Int, val height: Int)

    private fun yuv420ToPackedRgb24(image: ImageProxy): RgbFrame {
        val w = image.width
        val h = image.height
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]

        val yBuf = yPlane.buffer
        val uBuf = uPlane.buffer
        val vBuf = vPlane.buffer

        val yRowStride = yPlane.rowStride
        val yPixStride = yPlane.pixelStride
        val uvRowStride = uPlane.rowStride
        val uvPixStride = uPlane.pixelStride

        val rot = ((image.imageInfo.rotationDegrees % 360) + 360) % 360
        val outW = if (rot == 90 || rot == 270) h else w
        val outH = if (rot == 90 || rot == 270) w else h
        val out = ByteArray(outW * outH * 3)

        for (y in 0 until h) {
            val yRowOff = y * yRowStride
            val uvRowOff = (y shr 1) * uvRowStride
            for (x in 0 until w) {
                val yVal = (yBuf.get(yRowOff + x * yPixStride).toInt() and 0xFF)
                val uvIdx = uvRowOff + (x shr 1) * uvPixStride
                val uVal = (uBuf.get(uvIdx).toInt() and 0xFF) - 128
                val vVal = (vBuf.get(uvIdx).toInt() and 0xFF) - 128

                var r = (yVal + 1.370705 * vVal).toInt()
                var g = (yVal - 0.337633 * uVal - 0.698001 * vVal).toInt()
                var b = (yVal + 1.732446 * uVal).toInt()
                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255

                val dstX: Int
                val dstY: Int
                when (rot) {
                    90 -> {
                        dstX = h - 1 - y
                        dstY = x
                    }
                    180 -> {
                        dstX = w - 1 - x
                        dstY = h - 1 - y
                    }
                    270 -> {
                        dstX = y
                        dstY = w - 1 - x
                    }
                    else -> {
                        dstX = x
                        dstY = y
                    }
                }
                val dstIdx = (dstY * outW + dstX) * 3
                out[dstIdx] = r.toByte()
                out[dstIdx + 1] = g.toByte()
                out[dstIdx + 2] = b.toByte()
            }
        }
        return RgbFrame(out, outW, outH)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER && event.values.size >= 3) {
            val ay = event.values[1].toDouble()
            val az = event.values[2].toDouble()
            latestPitchDegrees = Math.toDegrees(atan2(ay, az))
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    fun stopCamera() {
        isStarted = false
        boundCamera = null
        sensorManager?.unregisterListener(this)
        pendingCapture.getAndSet(null)?.let { cb ->
            mainHandler.post { cb.error("CAMERA_STOPPED", "Camera stopped", null) }
        }
        mainHandler.post {
            try {
                cameraProvider?.unbindAll()
            } catch (_: Throwable) {
            }
        }
    }

    fun release() {
        stopCamera()
        channel.setMethodCallHandler(null)
        analysisExecutor.shutdown()
    }
}
