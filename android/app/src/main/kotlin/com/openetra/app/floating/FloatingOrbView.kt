package com.openetra.app.floating

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.provider.Settings
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.view.animation.LinearInterpolator
import kotlin.math.abs

/**
 * Accessible high-contrast floating assistive orb with calm state-aware radial
 * glow. Zero animation runs in IDLE/PAUSED/COMPLETED or under reduced-motion.
 */
class FloatingOrbView(
    context: Context,
    private val onSingleTap: (() -> Unit)? = null,
    private val onDoubleTap: (() -> Unit)? = null,
    private val onLongPress: (() -> Unit)? = null,
    private val onDragDelta: ((dx: Int, dy: Int) -> Unit)? = null,
    private val onDragEnd: (() -> Unit)? = null
) : View(context) {

    private var currentState: FloatingWidgetState = FloatingWidgetState.IDLE
    private var reducedMotionOverride: Boolean = false
    private var highContrastRing: Boolean = true
    private var glowFraction: Float = 0f
    private var pulseAnimator: ValueAnimator? = null

    private var downRawX: Float = 0f
    private var downRawY: Float = 0f
    private var lastRawX: Float = 0f
    private var lastRawY: Float = 0f
    private var dragging: Boolean = false
    private val dragSlopPx: Float = 12f * resources.displayMetrics.density

    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }
    private val corePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.WHITE
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.WHITE
    }

    private val gestureDetector = GestureDetector(
        context,
        object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                performClick()
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                onDoubleTap?.invoke()
                return true
            }

            override fun onLongPress(e: MotionEvent) {
                if (!dragging) {
                    onLongPress?.invoke()
                }
            }
        }
    )

    init {
        isClickable = true
        isFocusable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        updateSemantics()
    }

    fun getWidgetState(): FloatingWidgetState = currentState

    fun isGlowAnimatingForTest(): Boolean = pulseAnimator?.isRunning == true

    fun setReducedMotionOverride(enabled: Boolean) {
        reducedMotionOverride = enabled
        reconcileAnimator()
        invalidate()
    }

    fun setHighContrastRing(enabled: Boolean) {
        highContrastRing = enabled
        invalidate()
    }

    fun applyState(next: FloatingWidgetState, customLabel: String? = null) {
        currentState = next
        updateSemantics(customLabel)
        reconcileAnimator()
        invalidate()
    }

    private fun isSystemReducedMotion(): Boolean {
        return try {
            val scale = Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1.0f
            )
            scale == 0f
        } catch (_: Throwable) {
            false
        }
    }

    private fun reconcileAnimator() {
        val shouldAnimate = currentState.allowsPulseAnimation &&
            !reducedMotionOverride &&
            !isSystemReducedMotion()

        if (!shouldAnimate) {
            pulseAnimator?.cancel()
            pulseAnimator = null
            glowFraction = 0f
            return
        }

        if (pulseAnimator == null) {
            pulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 1400L
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                interpolator = LinearInterpolator()
                addUpdateListener { anim ->
                    glowFraction = anim.animatedValue as Float
                    invalidate()
                }
                start()
            }
        } else if (pulseAnimator?.isRunning != true) {
            pulseAnimator?.start()
        }
    }

    private fun updateSemantics(customLabel: String? = null) {
        val suffix = if (!customLabel.isNullOrBlank()) " $customLabel" else ""
        contentDescription = "Openetra Assistive Companion: ${currentState.talkBackStatus}$suffix"
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.addAction(
            AccessibilityNodeInfo.AccessibilityAction(
                AccessibilityNodeInfo.ACTION_CLICK,
                "Run primary assistive action"
            )
        )
        info.addAction(
            AccessibilityNodeInfo.AccessibilityAction(
                AccessibilityNodeInfo.ACTION_LONG_CLICK,
                "Trigger secondary or emergency confirmation action"
            )
        )
    }

    override fun performClick(): Boolean {
        super.performClick()
        onSingleTap?.invoke()
        return true
    }

    override fun performLongClick(): Boolean {
        super.performLongClick()
        onLongPress?.invoke()
        return true
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        gestureDetector.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                lastRawX = event.rawX
                lastRawY = event.rawY
                dragging = false
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val totalDx = event.rawX - downRawX
                val totalDy = event.rawY - downRawY
                if (!dragging && (abs(totalDx) > dragSlopPx || abs(totalDy) > dragSlopPx)) {
                    dragging = true
                }
                if (dragging) {
                    val stepDx = (event.rawX - lastRawX).toInt()
                    val stepDy = (event.rawY - lastRawY).toInt()
                    lastRawX = event.rawX
                    lastRawY = event.rawY
                    onDragDelta?.invoke(stepDx, stepDy)
                }
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) {
                    dragging = false
                    onDragEnd?.invoke()
                }
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val minDim = minOf(width, height).toFloat()
        if (minDim <= 0f) return

        val outerRadius = minDim * 0.44f
        val coreRadius = minDim * 0.34f

        // Calm outer state glow ring
        glowPaint.color = currentState.ringColor
        glowPaint.strokeWidth = minDim * (0.06f + glowFraction * 0.04f)
        glowPaint.alpha = (160 + (glowFraction * 95).toInt()).coerceIn(120, 255)
        canvas.drawCircle(cx, cy, outerRadius, glowPaint)

        // High-contrast core disc
        corePaint.color = currentState.coreColor
        canvas.drawCircle(cx, cy, coreRadius, corePaint)

        if (highContrastRing) {
            borderPaint.strokeWidth = minDim * 0.03f
            canvas.drawCircle(cx, cy, coreRadius, borderPaint)
        }

        // Center calm beacon dot
        canvas.drawCircle(cx, cy, minDim * 0.09f, dotPaint)
    }

    override fun onDetachedFromWindow() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        super.onDetachedFromWindow()
    }
}
