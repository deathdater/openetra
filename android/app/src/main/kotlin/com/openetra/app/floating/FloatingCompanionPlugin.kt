package com.openetra.app.floating

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter MethodChannel bridge (`com.openetra.app/floating_companion`) for
 * managing overlay permissions, service lifecycle, live task-state glow, and
 * forwarding orb triggers back to Flutter's [AssistiveActionRouter].
 */
class FloatingCompanionPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.openetra.app/floating_companion")
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
        FloatingCompanionService.actionBridgeCallback = { actionId, fromBg ->
            dispatchActionToFlutter(actionId, fromBg)
        }
    }

    fun dispatchActionToFlutter(actionId: String, fromBackground: Boolean) {
        mainHandler.post {
            try {
                channel.invokeMethod(
                    "onOverlayAction",
                    mapOf(
                        "actionId" to actionId,
                        "fromBackground" to fromBackground
                    )
                )
            } catch (_: Throwable) {
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkOverlayPermission" -> {
                result.success(
                    mapOf(
                        "granted" to Settings.canDrawOverlays(context),
                        "serviceRunning" to FloatingCompanionService.isRunning
                    )
                )
            }

            "openOverlaySettings" -> {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(mapOf("opened" to true))
                } catch (e: Throwable) {
                    result.error("OVERLAY_SETTINGS_ERROR", e.message, null)
                }
            }

            "startOverlay" -> {
                if (!Settings.canDrawOverlays(context)) {
                    result.success(mapOf("started" to false, "reason" to "OVERLAY_PERMISSION_DENIED"))
                    return
                }
                val intent = Intent(context, FloatingCompanionService::class.java).apply {
                    action = FloatingCompanionService.ACTION_START
                    call.argument<String>("primaryActionId")?.let {
                        putExtra(FloatingCompanionService.EXTRA_PRIMARY_ACTION, it)
                    }
                    call.argument<String>("secondaryActionId")?.let {
                        putExtra(FloatingCompanionService.EXTRA_SECONDARY_ACTION, it)
                    }
                    call.argument<String>("longPressActionId")?.let {
                        putExtra(FloatingCompanionService.EXTRA_LONG_PRESS_ACTION, it)
                    }
                    call.argument<Int>("orbSizeDp")?.let {
                        putExtra(FloatingCompanionService.EXTRA_ORB_SIZE_DP, it)
                    }
                    call.argument<Boolean>("reducedMotion")?.let {
                        putExtra(FloatingCompanionService.EXTRA_REDUCED_MOTION, it)
                    }
                    call.argument<Boolean>("highContrastRing")?.let {
                        putExtra(FloatingCompanionService.EXTRA_HIGH_CONTRAST, it)
                    }
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(mapOf("started" to true))
                } catch (e: Throwable) {
                    result.error("OVERLAY_START_FAILED", e.message, null)
                }
            }

            "stopOverlay" -> {
                val intent = Intent(context, FloatingCompanionService::class.java).apply {
                    action = FloatingCompanionService.ACTION_STOP
                }
                try {
                    context.startService(intent)
                } catch (_: Throwable) {
                }
                result.success(mapOf("stopped" to true))
            }

            "updateWidgetState" -> {
                if (!FloatingCompanionService.isRunning) {
                    result.success(mapOf("updated" to false))
                    return
                }
                val stateName = call.argument<String>("phase") ?: "idle"
                val label = call.argument<String>("statusLabel")
                val intent = Intent(context, FloatingCompanionService::class.java).apply {
                    action = FloatingCompanionService.ACTION_UPDATE_STATE
                    putExtra(FloatingCompanionService.EXTRA_STATE, stateName)
                    if (label != null) putExtra(FloatingCompanionService.EXTRA_LABEL, label)
                }
                try {
                    context.startService(intent)
                    result.success(mapOf("updated" to true))
                } catch (_: Throwable) {
                    result.success(mapOf("updated" to false))
                }
            }

            "updateConfig" -> {
                if (!FloatingCompanionService.isRunning) {
                    result.success(mapOf("updated" to false))
                    return
                }
                val intent = Intent(context, FloatingCompanionService::class.java).apply {
                    action = FloatingCompanionService.ACTION_UPDATE_CONFIG
                    call.argument<String>("primaryActionId")?.let {
                        putExtra(FloatingCompanionService.EXTRA_PRIMARY_ACTION, it)
                    }
                    call.argument<String>("secondaryActionId")?.let {
                        putExtra(FloatingCompanionService.EXTRA_SECONDARY_ACTION, it)
                    }
                    call.argument<String>("longPressActionId")?.let {
                        putExtra(FloatingCompanionService.EXTRA_LONG_PRESS_ACTION, it)
                    }
                    call.argument<Int>("orbSizeDp")?.let {
                        putExtra(FloatingCompanionService.EXTRA_ORB_SIZE_DP, it)
                    }
                    call.argument<Boolean>("reducedMotion")?.let {
                        putExtra(FloatingCompanionService.EXTRA_REDUCED_MOTION, it)
                    }
                    call.argument<Boolean>("highContrastRing")?.let {
                        putExtra(FloatingCompanionService.EXTRA_HIGH_CONTRAST, it)
                    }
                }
                try {
                    context.startService(intent)
                    result.success(mapOf("updated" to true))
                } catch (_: Throwable) {
                    result.success(mapOf("updated" to false))
                }
            }

            else -> result.notImplemented()
        }
    }

    fun release() {
        FloatingCompanionService.actionBridgeCallback = null
        channel.setMethodCallHandler(null)
    }
}
