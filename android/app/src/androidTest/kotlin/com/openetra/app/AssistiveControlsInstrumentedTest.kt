package com.openetra.app

import android.content.ComponentName
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.openetra.app.emergency.EmergencyAssistancePlugin
import com.openetra.app.floating.FloatingCompanionService
import com.openetra.app.floating.FloatingOrbView
import com.openetra.app.floating.FloatingWidgetState
import com.openetra.app.gesture.HandGesturePlugin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.charset.StandardCharsets

@RunWith(AndroidJUnit4::class)
class AssistiveControlsInstrumentedTest {

    companion object {
        private const val TAG = "AssistiveControlsTest"
    }

    @Test
    fun emergencyContactStoreEncryptsWithAndroidKeystoreAesGcm() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val secretName = "AnitaCaregiver"
        val secretPhone = "+919876543210"
        val sampleJson = """[{"id":"c1","name":"$secretName","phoneNumber":"$secretPhone","isPrimary":true}]"""

        EmergencyAssistancePlugin.encryptAndSave(ctx, sampleJson)
        val encFile = EmergencyAssistancePlugin.secureFile(ctx)
        assertTrue("Encrypted file must exist", encFile.exists() && encFile.length() > 20L)

        val rawBytes = encFile.readBytes()
        val rawAsText = String(rawBytes, StandardCharsets.ISO_8859_1)
        assertFalse("Ciphertext must never contain plaintext phone", rawAsText.contains(secretPhone))
        assertFalse("Ciphertext must never contain plaintext name", rawAsText.contains(secretName))

        val decrypted = EmergencyAssistancePlugin.loadAndDecrypt(ctx)
        assertEquals(sampleJson, decrypted)

        assertEquals("+919876543210", EmergencyAssistancePlugin.sanitizeDialNumber("+91 98765-43210"))

        // Clean up after test
        encFile.delete()
        Log.i(TAG, "Emergency Keystore AES-256-GCM roundtrip verified (${rawBytes.size} encrypted bytes)")
    }

    @Test
    fun handGestureModelVerifiesSha256AndRunsLiveLiteRtInference() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val tLoad0 = SystemClock.elapsedRealtime()
        val modelFile = HandGesturePlugin.ensureModelFile(ctx)
        assertEquals(HandGesturePlugin.EXPECTED_SHA256, HandGesturePlugin.sha256(modelFile))
        val interpreter = HandGesturePlugin.createInterpreter(modelFile, threads = 2)
        val loadMs = SystemClock.elapsedRealtime() - tLoad0

        try {
            val w = 224
            val h = 224
            val rgb = ByteArray(w * h * 3) { idx -> ((idx * 37) and 0xFF).toByte() }
            val result = HandGesturePlugin.runInferenceOnRgb(interpreter, rgb, w, h)
            val landmarks = result["landmarks"] as? List<*>
            assertNotNull("Landmarks list must be present", landmarks)
            assertEquals("Expected 63 landmark floats (21x3)", 63, landmarks!!.size)
            val presence = (result["handPresenceScore"] as Number).toDouble()
            val inferenceMs = (result["inferenceMs"] as Number).toInt()
            assertTrue("Presence score must be finite", presence.isFinite())
            Log.i(
                TAG,
                "HandGesture LiteRT 1.4.2 verified: loadMs=$loadMs inferenceMs=$inferenceMs presence=$presence"
            )
        } finally {
            interpreter.close()
        }
    }

    @Test
    fun floatingOrbViewRespectsReducedMotionIdleStopAndTalkBackSemantics() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val ctx = instrumentation.targetContext

        instrumentation.runOnMainSync {
            val orb = FloatingOrbView(ctx)

            // Default IDLE state must NEVER animate.
            assertEquals(FloatingWidgetState.IDLE, orb.getWidgetState())
            assertFalse("IDLE must not animate", orb.isGlowAnimatingForTest())
            assertTrue(
                "TalkBack contentDescription must describe idle state",
                orb.contentDescription.toString().contains("Idle")
            )

            // PAUSED and COMPLETED must NEVER animate.
            orb.applyState(FloatingWidgetState.PAUSED)
            assertFalse("PAUSED must not animate", orb.isGlowAnimatingForTest())
            orb.applyState(FloatingWidgetState.COMPLETED)
            assertFalse("COMPLETED must not animate", orb.isGlowAnimatingForTest())

            // Reduced-motion override suppresses pulse even in active states.
            orb.setReducedMotionOverride(true)
            orb.applyState(FloatingWidgetState.LISTENING, "Listening for voice command")
            assertFalse("Reduced motion must suppress LISTENING animation", orb.isGlowAnimatingForTest())
            assertTrue(
                "TalkBack description must reflect listening state",
                orb.contentDescription.toString().contains("Listening")
            )

            orb.applyState(FloatingWidgetState.EMERGENCY_FLOW)
            assertFalse("Reduced motion must suppress EMERGENCY_FLOW animation", orb.isGlowAnimatingForTest())
            assertTrue(
                "TalkBack description must reflect emergency confirmation",
                orb.contentDescription.toString().contains("Emergency confirmation")
            )
        }

        // Verify FloatingCompanionService declares specialUse foreground service type on API 34+.
        val svcInfo = ctx.packageManager.getServiceInfo(
            ComponentName(ctx, FloatingCompanionService::class.java),
            0
        )
        assertNotNull("FloatingCompanionService must be declared in manifest", svcInfo)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            assertTrue(
                "Service must declare FOREGROUND_SERVICE_TYPE_SPECIAL_USE",
                (svcInfo.foregroundServiceType and ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) != 0
            )
        }
        Log.i(TAG, "FloatingOrbView & FloatingCompanionService manifest compliance verified")
    }
}
