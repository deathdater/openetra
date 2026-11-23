package com.openetra.app

import com.openetra.app.camera.CameraXCaptureManager
import com.openetra.app.haptics.HapticsPlugin
import com.openetra.app.mirage.MirageEnginePlugin
import com.openetra.app.resources.DeviceResourcePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var miragePlugin: MirageEnginePlugin? = null
    private var cameraManager: CameraXCaptureManager? = null
    private var resourcePlugin: DeviceResourcePlugin? = null
    private var hapticsPlugin: HapticsPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        miragePlugin = MirageEnginePlugin(applicationContext, messenger)
        cameraManager = CameraXCaptureManager(applicationContext, this, messenger)
        resourcePlugin = DeviceResourcePlugin(applicationContext, messenger)
        hapticsPlugin = HapticsPlugin(applicationContext, messenger)
    }

    override fun onDestroy() {
        miragePlugin?.release()
        cameraManager?.release()
        resourcePlugin?.release()
        hapticsPlugin?.release()
        super.onDestroy()
    }
}
