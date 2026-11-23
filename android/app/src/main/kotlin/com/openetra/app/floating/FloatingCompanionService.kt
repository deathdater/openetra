package com.openetra.app.floating

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import com.openetra.app.MainActivity
import com.openetra.app.R
import kotlin.math.max
import kotlin.math.min

/**
 * Android 14/15 compliant `specialUse` foreground service hosting Openetra's
 * optional floating assistive orb. Never initiates covert background camera or
 * microphone capture: Category C actions trampoline cleanly to [MainActivity].
 */
class FloatingCompanionService : Service() {

    companion object {
        const val CHANNEL_ID = "openetra_floating_companion"
        const val NOTIFICATION_ID = 4107

        const val ACTION_START = "com.openetra.app.floating.ACTION_START"
        const val ACTION_STOP = "com.openetra.app.floating.ACTION_STOP"
        const val ACTION_HIDE = "com.openetra.app.floating.ACTION_HIDE"
        const val ACTION_UPDATE_STATE = "com.openetra.app.floating.ACTION_UPDATE_STATE"
        const val ACTION_UPDATE_CONFIG = "com.openetra.app.floating.ACTION_UPDATE_CONFIG"

        const val EXTRA_STATE = "extra_state"
        const val EXTRA_LABEL = "extra_label"
        const val EXTRA_PRIMARY_ACTION = "extra_primary_action"
        const val EXTRA_SECONDARY_ACTION = "extra_secondary_action"
        const val EXTRA_LONG_PRESS_ACTION = "extra_long_press_action"
        const val EXTRA_ORB_SIZE_DP = "extra_orb_size_dp"
        const val EXTRA_REDUCED_MOTION = "extra_reduced_motion"
        const val EXTRA_HIGH_CONTRAST = "extra_high_contrast"

        const val EXTRA_ASSISTIVE_ACTION = "com.openetra.app.EXTRA_ASSISTIVE_ACTION"

        private val BACKGROUND_SAFE_ACTIONS = setOf(
            "toggle_flashlight",
            "cancel_active_task",
            "repeat_last"
        )

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var actionBridgeCallback: ((actionId: String, fromBackground: Boolean) -> Unit)? = null
    }

    private var windowManager: WindowManager? = null
    private var orbView: FloatingOrbView? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private var primaryActionId: String = "describe_scene"
    private var secondaryActionId: String = "cancel_active_task"
    private var longPressActionId: String = "start_emergency_assistance"
    private var orbSizeDp: Int = 64
    private var reducedMotion: Boolean = false
    private var highContrast: Boolean = true
    private var currentState: FloatingWidgetState = FloatingWidgetState.IDLE

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP, ACTION_HIDE -> {
                removeOrb()
                isRunning = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_UPDATE_STATE -> {
                val stateName = intent.getStringExtra(EXTRA_STATE)
                val label = intent.getStringExtra(EXTRA_LABEL)
                currentState = FloatingWidgetState.fromWireName(stateName)
                orbView?.applyState(currentState, label)
                updateNotification()
                return START_STICKY
            }

            ACTION_UPDATE_CONFIG -> {
                applyConfigExtras(intent)
                orbView?.setReducedMotionOverride(reducedMotion)
                orbView?.setHighContrastRing(highContrast)
                resizeAndClampOrb()
                return START_STICKY
            }

            else -> {
                applyConfigExtras(intent)
                if (!Settings.canDrawOverlays(this)) {
                    isRunning = false
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForegroundSafe()
                isRunning = true
                attachOrbIfNeeded()
                return START_STICKY
            }
        }
    }

    private fun applyConfigExtras(intent: Intent?) {
        if (intent == null) return
        intent.getStringExtra(EXTRA_PRIMARY_ACTION)?.let { primaryActionId = it }
        intent.getStringExtra(EXTRA_SECONDARY_ACTION)?.let { secondaryActionId = it }
        intent.getStringExtra(EXTRA_LONG_PRESS_ACTION)?.let { longPressActionId = it }
        if (intent.hasExtra(EXTRA_ORB_SIZE_DP)) {
            orbSizeDp = intent.getIntExtra(EXTRA_ORB_SIZE_DP, 64).coerceIn(48, 96)
        }
        if (intent.hasExtra(EXTRA_REDUCED_MOTION)) {
            reducedMotion = intent.getBooleanExtra(EXTRA_REDUCED_MOTION, false)
        }
        if (intent.hasExtra(EXTRA_HIGH_CONTRAST)) {
            highContrast = intent.getBooleanExtra(EXTRA_HIGH_CONTRAST, true)
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val existing = nm?.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Openetra Floating Companion",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Shows when Openetra's optional floating assistive button is active."
                    setShowBadge(false)
                }
                nm?.createNotificationChannel(channel)
            }
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPending = PendingIntent.getActivity(
            this,
            101,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, FloatingCompanionService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            102,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        // Honest, non-sensitive status notification (no OCR/scene/contact content).
        return builder
            .setContentTitle("Openetra Companion Active")
            .setContentText("Status: ${currentState.talkBackStatus}")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(openPending)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "Hide & Stop",
                    stopPending
                ).build()
            )
            .build()
    }

    private fun startForegroundSafe() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun attachOrbIfNeeded() {
        if (orbView != null || windowManager == null) return
        val sizePx = (orbSizeDp * resources.displayMetrics.density).toInt()
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (16 * resources.displayMetrics.density).toInt()
            y = (180 * resources.displayMetrics.density).toInt()
        }

        val view = FloatingOrbView(
            context = this,
            onSingleTap = { dispatchOrbAction(primaryActionId) },
            onDoubleTap = { dispatchOrbAction(secondaryActionId) },
            onLongPress = { dispatchOrbAction(longPressActionId) },
            onDragDelta = { dx, dy ->
                val lp = layoutParams ?: return@FloatingOrbView
                lp.x += dx
                lp.y += dy
                clampPosition(lp)
                try {
                    windowManager?.updateViewLayout(orbView, lp)
                } catch (_: Throwable) {
                }
            },
            onDragEnd = { snapToNearestEdge() }
        ).apply {
            setReducedMotionOverride(reducedMotion)
            setHighContrastRing(highContrast)
            applyState(currentState)
        }

        layoutParams = params
        orbView = view
        try {
            windowManager?.addView(view, params)
            snapToNearestEdge()
        } catch (_: Throwable) {
            orbView = null
            layoutParams = null
        }
    }

    private fun dispatchOrbAction(actionId: String) {
        val cb = actionBridgeCallback
        if (BACKGROUND_SAFE_ACTIONS.contains(actionId) && cb != null) {
            // Category A: safe to execute without launching camera/mic UI.
            cb.invoke(actionId, true)
            return
        }
        // Category C: bring MainActivity to foreground so camera/mic/confirmation
        // run with full Android visual privacy indicators & user visibility.
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ASSISTIVE_ACTION, actionId)
        }
        startActivity(intent)
    }

    private fun screenDimensions(): Pair<Int, Int> {
        val dm = resources.displayMetrics
        return Pair(dm.widthPixels, dm.heightPixels)
    }

    private fun clampPosition(lp: WindowManager.LayoutParams) {
        val (sw, sh) = screenDimensions()
        val margin = (8 * resources.displayMetrics.density).toInt()
        val topSafe = (48 * resources.displayMetrics.density).toInt()
        val bottomSafe = (48 * resources.displayMetrics.density).toInt()
        lp.x = max(margin, min(lp.x, sw - lp.width - margin))
        lp.y = max(topSafe, min(lp.y, sh - lp.height - bottomSafe))
    }

    private fun snapToNearestEdge() {
        val lp = layoutParams ?: return
        val view = orbView ?: return
        val (sw, _) = screenDimensions()
        val margin = (8 * resources.displayMetrics.density).toInt()
        val centerX = lp.x + lp.width / 2
        lp.x = if (centerX < sw / 2) margin else max(margin, sw - lp.width - margin)
        clampPosition(lp)
        try {
            windowManager?.updateViewLayout(view, lp)
        } catch (_: Throwable) {
        }
    }

    private fun resizeAndClampOrb() {
        val lp = layoutParams ?: return
        val view = orbView ?: return
        val sizePx = (orbSizeDp * resources.displayMetrics.density).toInt()
        lp.width = sizePx
        lp.height = sizePx
        clampPosition(lp)
        try {
            windowManager?.updateViewLayout(view, lp)
        } catch (_: Throwable) {
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        snapToNearestEdge()
    }

    private fun removeOrb() {
        val view = orbView
        orbView = null
        layoutParams = null
        if (view != null) {
            try {
                windowManager?.removeView(view)
            } catch (_: Throwable) {
            }
        }
    }

    override fun onDestroy() {
        removeOrb()
        isRunning = false
        super.onDestroy()
    }
}
