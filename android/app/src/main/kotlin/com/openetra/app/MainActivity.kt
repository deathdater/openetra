package com.openetra.app

import android.content.Intent
import com.openetra.app.camera.CameraXCaptureManager
import com.openetra.app.emergency.EmergencyAssistancePlugin
import com.openetra.app.flashlight.FlashlightPlugin
import com.openetra.app.floating.FloatingCompanionPlugin
import com.openetra.app.floating.FloatingCompanionService
import com.openetra.app.gesture.HandGesturePlugin
import com.openetra.app.haptics.HapticsPlugin
import com.openetra.app.mirage.MirageEnginePlugin
import com.openetra.app.ocr.IndicOcrPlugin
import com.openetra.app.resources.DeviceResourcePlugin
import com.openetra.app.specialist.SpecialistVisionPlugin
import com.openetra.app.speech.OfflineSpeechPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var miragePlugin: MirageEnginePlugin? = null
    private var cameraManager: CameraXCaptureManager? = null
    private var resourcePlugin: DeviceResourcePlugin? = null
    private var hapticsPlugin: HapticsPlugin? = null
    private var indicOcrPlugin: IndicOcrPlugin? = null
    private var offlineSpeechPlugin: OfflineSpeechPlugin? = null
    private var specialistPlugin: SpecialistVisionPlugin? = null
    private var emergencyPlugin: EmergencyAssistancePlugin? = null
    private var flashlightPlugin: FlashlightPlugin? = null
    private var handGesturePlugin: HandGesturePlugin? = null
    private var floatingCompanionPlugin: FloatingCompanionPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        miragePlugin = MirageEnginePlugin(applicationContext, messenger)
        val cam = CameraXCaptureManager(applicationContext, this, messenger)
        cameraManager = cam
        resourcePlugin = DeviceResourcePlugin(applicationContext, messenger)
        hapticsPlugin = HapticsPlugin(applicationContext, messenger)
        indicOcrPlugin = IndicOcrPlugin(applicationContext, messenger)
        offlineSpeechPlugin = OfflineSpeechPlugin(applicationContext, messenger)
        specialistPlugin = SpecialistVisionPlugin(applicationContext, messenger)
        emergencyPlugin = EmergencyAssistancePlugin(applicationContext, messenger)
        flashlightPlugin = FlashlightPlugin(applicationContext, cam, messenger)
        handGesturePlugin = HandGesturePlugin(applicationContext, messenger)
        floatingCompanionPlugin = FloatingCompanionPlugin(applicationContext, messenger)
        forwardAssistiveIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardAssistiveIntent(intent)
    }

    private fun forwardAssistiveIntent(intent: Intent?) {
        val actionId = intent?.getStringExtra(FloatingCompanionService.EXTRA_ASSISTIVE_ACTION)
        if (!actionId.isNullOrBlank()) {
            intent.removeExtra(FloatingCompanionService.EXTRA_ASSISTIVE_ACTION)
            floatingCompanionPlugin?.dispatchActionToFlutter(actionId, false)
        }
    }

    override fun onDestroy() {
        floatingCompanionPlugin?.release()
        handGesturePlugin?.release()
        flashlightPlugin?.release()
        emergencyPlugin?.release()
        miragePlugin?.release()
        cameraManager?.release()
        resourcePlugin?.release()
        hapticsPlugin?.release()
        indicOcrPlugin?.release()
        offlineSpeechPlugin?.release()
        specialistPlugin?.release()
        super.onDestroy()
    }
}
