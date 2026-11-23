package com.openetra.app

import com.openetra.app.camera.CameraXCaptureManager
import com.openetra.app.haptics.HapticsPlugin
import com.openetra.app.mirage.MirageEnginePlugin
import com.openetra.app.ocr.IndicOcrPlugin
import com.openetra.app.resources.DeviceResourcePlugin
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        miragePlugin = MirageEnginePlugin(applicationContext, messenger)
        cameraManager = CameraXCaptureManager(applicationContext, this, messenger)
        resourcePlugin = DeviceResourcePlugin(applicationContext, messenger)
        hapticsPlugin = HapticsPlugin(applicationContext, messenger)
        indicOcrPlugin = IndicOcrPlugin(applicationContext, messenger)
        offlineSpeechPlugin = OfflineSpeechPlugin(applicationContext, messenger)
    }

    override fun onDestroy() {
        miragePlugin?.release()
        cameraManager?.release()
        resourcePlugin?.release()
        hapticsPlugin?.release()
        indicOcrPlugin?.release()
        offlineSpeechPlugin?.release()
        super.onDestroy()
    }
}
