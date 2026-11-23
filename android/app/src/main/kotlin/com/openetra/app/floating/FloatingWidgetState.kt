package com.openetra.app.floating

import android.graphics.Color

/**
 * Unified 10-state visual & TalkBack contract mirroring Flutter's
 * [AssistiveTaskPhase]. Idle, Completed, and Paused states NEVER run continuous
 * glow animations to conserve battery and avoid visual distraction.
 */
enum class FloatingWidgetState(
    val wireName: String,
    val ringColor: Int,
    val coreColor: Int,
    val allowsPulseAnimation: Boolean,
    val talkBackStatus: String
) {
    IDLE(
        wireName = "idle",
        ringColor = Color.parseColor("#8A94A6"),
        coreColor = Color.parseColor("#11161F"),
        allowsPulseAnimation = false,
        talkBackStatus = "Idle. Tap to run primary assistive action."
    ),
    ACTIVATED(
        wireName = "activated",
        ringColor = Color.parseColor("#38BDF8"),
        coreColor = Color.parseColor("#0B253A"),
        allowsPulseAnimation = true,
        talkBackStatus = "Activated."
    ),
    LISTENING(
        wireName = "listening",
        ringColor = Color.parseColor("#22D3EE"),
        coreColor = Color.parseColor("#083344"),
        allowsPulseAnimation = true,
        talkBackStatus = "Listening."
    ),
    PROCESSING(
        wireName = "processing",
        ringColor = Color.parseColor("#F59E0B"),
        coreColor = Color.parseColor("#2C1D04"),
        allowsPulseAnimation = true,
        talkBackStatus = "Processing."
    ),
    AI_INFERENCE(
        wireName = "aiInference",
        ringColor = Color.parseColor("#A78BFA"),
        coreColor = Color.parseColor("#21123B"),
        allowsPulseAnimation = true,
        talkBackStatus = "Analyzing visually."
    ),
    SPEAKING(
        wireName = "speaking",
        ringColor = Color.parseColor("#34D399"),
        coreColor = Color.parseColor("#062E22"),
        allowsPulseAnimation = true,
        talkBackStatus = "Speaking response."
    ),
    COMPLETED(
        wireName = "completed",
        ringColor = Color.parseColor("#10B981"),
        coreColor = Color.parseColor("#08291E"),
        allowsPulseAnimation = false,
        talkBackStatus = "Completed."
    ),
    FAILED(
        wireName = "failed",
        ringColor = Color.parseColor("#F97316"),
        coreColor = Color.parseColor("#3B1605"),
        allowsPulseAnimation = false,
        talkBackStatus = "Action unavailable or failed."
    ),
    PAUSED(
        wireName = "paused",
        ringColor = Color.parseColor("#94A3B8"),
        coreColor = Color.parseColor("#1E293B"),
        allowsPulseAnimation = false,
        talkBackStatus = "Paused."
    ),
    EMERGENCY_FLOW(
        wireName = "emergencyFlow",
        ringColor = Color.parseColor("#EF4444"),
        coreColor = Color.parseColor("#450A0A"),
        allowsPulseAnimation = true,
        talkBackStatus = "Emergency confirmation active."
    );

    companion object {
        fun fromWireName(raw: String?): FloatingWidgetState {
            return when (raw?.trim()) {
                "idle" -> IDLE
                "activated", "capturing" -> ACTIVATED
                "listening", "gestureListening" -> LISTENING
                "processing" -> PROCESSING
                "aiInference" -> AI_INFERENCE
                "speaking" -> SPEAKING
                "completed" -> COMPLETED
                "failed", "warning", "error" -> FAILED
                "paused" -> PAUSED
                "emergencyFlow", "emergencyConfirmation" -> EMERGENCY_FLOW
                else -> IDLE
            }
        }
    }
}
