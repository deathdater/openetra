import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/accessibility/accessibility_announcer.dart';
import 'package:openetra/core/assistive/audio_arbitrator.dart';
import 'package:openetra/core/assistive/camera_resource_manager.dart';
import 'package:openetra/core/audio/bloc/audio_bloc.dart';
import 'package:openetra/core/audio/haptic_feedback_service.dart';
import 'package:openetra/core/audio/speech_controller.dart';
import 'package:openetra/core/camera/camera_controller_bridge.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/resource_management/device_resource_manager.dart';
import 'package:openetra/features/flashlight/data/native_flashlight_gateway.dart';
import 'package:openetra/features/flashlight/domain/flashlight_policy.dart';
import 'package:openetra/features/flashlight/domain/intelligent_flashlight_controller.dart';
import 'package:openetra/features/flashlight/presentation/flashlight_settings_screen.dart';

class _FakeCameraSource implements CameraSource {
  int startCount = 0;
  int stopCount = 0;
  double nextLuma = 128.0;

  @override
  Future<void> start({int minIntervalMs = 500}) async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<CapturedFrame> captureFrame() async {
    return CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics(
        meanLuma: nextLuma,
        lumaStdDev: 20,
        laplacianVariance: 100,
        overexposedRatio: 0,
        underexposedRatio: 0,
      ),
    );
  }
}

class _FakeDeviceResourceManager extends DeviceResourceManager {
  _FakeDeviceResourceManager(this._state);
  DeviceResourceState _state;

  void setState(DeviceResourceState next) {
    _state = next;
  }

  @override
  DeviceResourceState get currentState => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FlashlightPolicyEvaluator enforces opt-in, hysteresis, dwell, debounce, battery/thermal pause, and 180s cutoff', () {
    var fakeNow = DateTime(2026, 11, 23, 12, 0, 0);
    final policy = FlashlightPolicyEvaluator(clock: () => fakeNow);
    const config = FlashlightPolicyConfig(autoModeEnabled: true);
    const nominal = DeviceResourceState.nominalBalanced;

    // 1. Auto mode disabled or unauthorized task -> never turns on.
    expect(
      policy.evaluate(
        config: const FlashlightPolicyConfig(autoModeEnabled: false),
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: nominal,
        ambientLux: 2.0,
      ).type,
      TorchDecisionType.noChange,
    );
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: false,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: nominal,
        ambientLux: 2.0,
      ).type,
      TorchDecisionType.noChange,
    );

    // 2. Dark condition must be sustained across transitionDebounce (1500 ms).
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: nominal,
        ambientLux: 10.0,
      ).type,
      TorchDecisionType.noChange,
    );
    fakeNow = fakeNow.add(const Duration(milliseconds: 1000));
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: nominal,
        ambientLux: 10.0,
      ).type,
      TorchDecisionType.noChange,
    );
    fakeNow = fakeNow.add(const Duration(milliseconds: 600));
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: nominal,
        ambientLux: 10.0,
      ).type,
      TorchDecisionType.turnOn,
    );

    // 3. Dead-band (15..45 lux) keeps torch steady; manual override also suppresses changes.
    fakeNow = fakeNow.add(const Duration(seconds: 5));
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: true,
        openetraOwnsTorch: true,
        resourceState: nominal,
        ambientLux: 25.0,
      ).type,
      TorchDecisionType.noChange,
    );
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: true,
        torchCurrentlyOn: true,
        openetraOwnsTorch: true,
        resourceState: nominal,
        ambientLux: 200.0,
      ).type,
      TorchDecisionType.noChange,
    );

    // 4. Bright condition (>= 45 lux) after minDwell starts debounce and turns off at +1500 ms.
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: true,
        openetraOwnsTorch: true,
        resourceState: nominal,
        ambientLux: 60.0,
      ).type,
      TorchDecisionType.noChange,
    );
    fakeNow = fakeNow.add(const Duration(milliseconds: 1600));
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: true,
        openetraOwnsTorch: true,
        resourceState: nominal,
        ambientLux: 60.0,
      ).type,
      TorchDecisionType.turnOff,
    );

    // 5. Low battery (<= 15% not charging) and severe thermal state pause auto mode.
    const lowBat = DeviceResourceState(
      operatingMode: OperatingMode.eco,
      batteryPercent: 15,
      isCharging: false,
      thermalState: ThermalState.nominal,
      availableRamMb: 2048,
      isLowMemory: false,
      recommendedThreads: 2,
      inferenceIntervalMs: 1500,
      isDegradedCapability: true,
    );
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: lowBat,
        ambientLux: 5.0,
      ).type,
      TorchDecisionType.pauseAutoMode,
    );

    const hotState = DeviceResourceState(
      operatingMode: OperatingMode.balanced,
      batteryPercent: 80,
      isCharging: false,
      thermalState: ThermalState.severe,
      availableRamMb: 2048,
      isLowMemory: false,
      recommendedThreads: 2,
      inferenceIntervalMs: 1500,
      isDegradedCapability: true,
    );
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: hotState,
        ambientLux: 5.0,
      ).type,
      TorchDecisionType.pauseAutoMode,
    );

    // 6. 180 s continuous-on safety cutoff pauses auto mode.
    fakeNow = fakeNow.add(const Duration(seconds: 5));
    policy.evaluate(
      config: config,
      isAuthorizedTaskActive: true,
      manualOverrideActive: false,
      torchCurrentlyOn: false,
      openetraOwnsTorch: false,
      resourceState: nominal,
      ambientLux: 5.0,
    );
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: false,
        openetraOwnsTorch: false,
        resourceState: nominal,
        ambientLux: 5.0,
      ).type,
      TorchDecisionType.turnOn,
    );
    fakeNow = fakeNow.add(const Duration(seconds: 180));
    expect(
      policy.evaluate(
        config: config,
        isAuthorizedTaskActive: true,
        manualOverrideActive: false,
        torchCurrentlyOn: true,
        openetraOwnsTorch: true,
        resourceState: nominal,
        ambientLux: 5.0,
      ).type,
      TorchDecisionType.pauseAutoMode,
    );
  });

  test('IntelligentFlashlightController respects TorchCallback ownership, shares active camera meanLuma, and cleans up on session end', () async {
    var fakeNow = DateTime(2026, 11, 23, 12, 30, 0);
    final gateway = FakeFlashlightGateway()..hasLightSensor = false;
    final cameraSource = _FakeCameraSource()..nextLuma = 30.0;
    final camManager = CameraResourceManager(cameraSource: cameraSource);
    final resManager = _FakeDeviceResourceManager(DeviceResourceState.nominalBalanced);
    final speech = SpeechController(enablePlatformTts: false);
    final audioBloc = AudioBloc(
      announcer: AccessibilityAnnouncer(
        speechController: speech,
        hapticService: HapticFeedbackService(),
      ),
      speechController: speech,
    );
    final arbitrator = AudioArbitrator(
      audioBloc: audioBloc,
      speechController: speech,
    );

    final controller = IntelligentFlashlightController(
      gateway: gateway,
      resourceManager: resManager,
      cameraResourceManager: camManager,
      audioArbitrator: arbitrator,
      clock: () => fakeNow,
    );
    addTearDown(() async {
      await controller.dispose();
      await audioBloc.close();
    });

    await controller.initialize();

    // External torch active -> Openetra never turns it off!
    gateway.simulateExternalTorch(true);
    await controller.turnOffIfOwned(announce: false);
    expect(gateway.torchOn, isTrue);

    final manualOffResult = await controller.setManualTorch(false);
    expect(manualOffResult.applied, isFalse);
    expect(manualOffResult.reason, 'EXTERNAL_TORCH_OWNER');
    expect(gateway.torchOn, isTrue);

    // Clear external torch and test opt-in auto mode using active camera luma fallback.
    gateway.simulateExternalTorch(false);
    await controller.setAutoModeEnabled(true);
    await controller.beginAuthorizedTaskSession();

    final lease = await camManager.acquireLease(CameraLeasePurpose.scene);
    await camManager.captureFrame(lease);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gateway.torchOn, isFalse);

    fakeNow = fakeNow.add(const Duration(milliseconds: 1600));
    await camManager.captureFrame(lease);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gateway.torchOn, isTrue);
    expect(gateway.openetraOwnsTorch, isTrue);
    expect(cameraSource.startCount, 1); // Never opens a second camera session!

    // Thermal severe pauses automatic flashlight and turns off owned torch.
    resManager.setState(const DeviceResourceState(
      operatingMode: OperatingMode.balanced,
      batteryPercent: 80,
      isCharging: false,
      thermalState: ThermalState.severe,
      availableRamMb: 2048,
      isLowMemory: false,
      recommendedThreads: 2,
      inferenceIntervalMs: 1200,
      isDegradedCapability: true,
    ));
    await controller.evaluateCurrentConditions();
    expect(controller.state.autoPaused, isTrue);
    expect(gateway.torchOn, isFalse);

    // Ending authorized task session turns off owned torch and disables monitoring.
    resManager.setState(DeviceResourceState.nominalBalanced);
    await controller.setManualTorch(true);
    expect(gateway.torchOn, isTrue);
    await controller.endAuthorizedTaskSession();
    expect(gateway.torchOn, isFalse);
    expect(gateway.sensorMonitoringEnabled, isFalse);

    await camManager.releaseLease(lease);
  });

  testWidgets('FlashlightSettingsScreen toggles manual and opt-in auto torch cleanly', (tester) async {
    final gateway = FakeFlashlightGateway();
    final resManager = _FakeDeviceResourceManager(DeviceResourceState.nominalBalanced);
    final controller = IntelligentFlashlightController(
      gateway: gateway,
      resourceManager: resManager,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FlashlightSettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turn Flashlight On'), findsOneWidget);
    await tester.tap(find.text('Turn Flashlight On'));
    await tester.pumpAndSettle();
    expect(gateway.torchOn, isTrue);
    expect(find.text('Turn Flashlight Off'), findsOneWidget);

    await tester.ensureVisible(find.text('Automatic Low-Light Torch: Disabled'));
    await tester.tap(find.text('Automatic Low-Light Torch: Disabled'));
    await tester.pumpAndSettle();
    expect(controller.state.config.autoModeEnabled, isTrue);
    expect(find.text('Automatic Low-Light Torch: Enabled'), findsOneWidget);
  });
}
