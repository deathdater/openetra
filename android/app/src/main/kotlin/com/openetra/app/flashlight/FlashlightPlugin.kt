package com.openetra.app.flashlight

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import com.openetra.app.camera.CameraXCaptureManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Ownership-aware Android flashlight controller + opt-in ambient light sensor
 * bridge (`com.openetra.app/flashlight`). Never creates a second CameraX session
 * and never shuts off a torch owned by an external app or Android system tile.
 */
class FlashlightPlugin(
    private val context: Context,
    private val cameraManager: CameraXCaptureManager,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, SensorEventListener {

    private val channel = MethodChannel(messenger, "com.openetra.app/flashlight")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sysCameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private var flashCameraId: String? = null

    @Volatile
    private var torchAvailable: Boolean = true

    @Volatile
    private var systemTorchOn: Boolean = false

    @Volatile
    private var openetraRequestedTorch: Boolean = false

    @Volatile
    private var ambientLux: Float = -1f

    @Volatile
    private var lightSensorMonitoring: Boolean = false

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeUnavailable(cameraId: String) {
            if (cameraId == flashCameraId) {
                torchAvailable = false
                if (!openetraRequestedTorch) {
                    systemTorchOn = false
                }
            }
        }

        override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
            if (cameraId == flashCameraId) {
                torchAvailable = true
                systemTorchOn = enabled
                if (!enabled) {
                    openetraRequestedTorch = false
                }
            }
        }
    }

    init {
        flashCameraId = findBackFlashCameraId()
        try {
            if (flashCameraId != null) {
                sysCameraManager?.registerTorchCallback(torchCallback, mainHandler)
            }
        } catch (_: Throwable) {
        }
        channel.setMethodCallHandler(this)
    }

    private fun findBackFlashCameraId(): String? {
        val cm = sysCameraManager ?: return null
        return try {
            val ids = cm.cameraIdList
            for (id in ids) {
                val chars = cm.getCameraCharacteristics(id)
                val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                if (hasFlash && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    return id
                }
            }
            for (id in ids) {
                val chars = cm.getCameraCharacteristics(id)
                if (chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true) {
                    return id
                }
            }
            null
        } catch (_: Throwable) {
            null
        }
    }

    fun getStatusSnapshot(): Map<String, Any> {
        val hasFlash = flashCameraId != null
        val externalActive = systemTorchOn && !openetraRequestedTorch
        val hasLightSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT) != null
        return mapOf(
            "hasFlash" to hasFlash,
            "torchAvailable" to (hasFlash && torchAvailable),
            "torchOn" to systemTorchOn,
            "openetraOwnsTorch" to (openetraRequestedTorch && systemTorchOn),
            "externalTorchActive" to externalActive,
            "hasLightSensor" to hasLightSensor,
            "ambientLightLux" to ambientLux.toDouble(),
            "activeFrameMeanLuma" to cameraManager.currentMeanLuma(),
            "cameraActive" to cameraManager.isCameraActive()
        )
    }

    private fun applyTorchState(enabled: Boolean): Map<String, Any> {
        val camId = flashCameraId
            ?: return mapOf("applied" to false, "reason" to "NO_FLASH_HARDWARE", "torchOn" to false)

        // Never turn off a torch that Openetra does not own.
        if (!enabled && systemTorchOn && !openetraRequestedTorch) {
            return mapOf(
                "applied" to false,
                "reason" to "EXTERNAL_TORCH_OWNER",
                "torchOn" to true,
                "openetraOwnsTorch" to false
            )
        }

        return try {
            if (cameraManager.isCameraActive()) {
                val ok = cameraManager.setCameraTorch(enabled)
                if (!ok) {
                    return mapOf("applied" to false, "reason" to "CAMERA_TORCH_UNAVAILABLE", "torchOn" to systemTorchOn)
                }
            } else {
                val cm = sysCameraManager
                    ?: return mapOf("applied" to false, "reason" to "CAMERA_MANAGER_MISSING", "torchOn" to false)
                cm.setTorchMode(camId, enabled)
            }
            openetraRequestedTorch = enabled
            systemTorchOn = enabled
            mapOf(
                "applied" to true,
                "torchOn" to enabled,
                "openetraOwnsTorch" to enabled
            )
        } catch (e: Throwable) {
            mapOf(
                "applied" to false,
                "reason" to (e.message ?: "TORCH_ERROR"),
                "torchOn" to systemTorchOn,
                "openetraOwnsTorch" to openetraRequestedTorch
            )
        }
    }

    private fun setLightMonitoring(enabled: Boolean) {
        if (enabled == lightSensorMonitoring) return
        val light = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)
        if (enabled && light != null) {
            lightSensorMonitoring = true
            sensorManager?.registerListener(this, light, SensorManager.SENSOR_DELAY_UI)
        } else {
            lightSensorMonitoring = false
            ambientLux = -1f
            sensorManager?.unregisterListener(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(getStatusSnapshot())
            "setTorch" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                result.success(applyTorchState(enabled))
            }
            "setLightSensorMonitoring" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setLightMonitoring(enabled)
                result.success(mapOf("monitoring" to lightSensorMonitoring))
            }
            else -> result.notImplemented()
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_LIGHT && event.values.isNotEmpty()) {
            ambientLux = event.values[0]
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    fun release() {
        channel.setMethodCallHandler(null)
        setLightMonitoring(false)
        if (openetraRequestedTorch) {
            applyTorchState(false)
        }
        try {
            sysCameraManager?.unregisterTorchCallback(torchCallback)
        } catch (_: Throwable) {
        }
    }
}
