import 'dart:async';
import 'package:equatable/equatable.dart';
import '../../../core/assistive/audio_arbitrator.dart';
import '../../../core/assistive/camera_resource_manager.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/resource_management/device_resource_manager.dart';
import '../../../core/storage/openetra_database.dart';
import '../data/native_flashlight_gateway.dart';
import 'flashlight_policy.dart';

class FlashlightControllerState extends Equatable {
  const FlashlightControllerState({
    required this.config,
    required this.hardwareStatus,
    this.manualOverrideActive = false,
    this.autoPaused = false,
    this.isAuthorizedTaskActive = false,
    this.statusSummary = 'Flashlight off.',
  });

  final FlashlightPolicyConfig config;
  final FlashlightHardwareStatus hardwareStatus;
  final bool manualOverrideActive;
  final bool autoPaused;
  final bool isAuthorizedTaskActive;
  final String statusSummary;

  @override
  List<Object?> get props => [
        config,
        hardwareStatus,
        manualOverrideActive,
        autoPaused,
        isAuthorizedTaskActive,
        statusSummary,
      ];
}

/// Ownership-aware manual and opt-in automatic flashlight controller extending
/// existing Openetra tasks without duplicating CameraX or audio pipelines.
class IntelligentFlashlightController {
  IntelligentFlashlightController({
    required FlashlightGateway gateway,
    required DeviceResourceManager resourceManager,
    CameraResourceManager? cameraResourceManager,
    AudioArbitrator? audioArbitrator,
    OpenetraDatabase? database,
    DateTime Function()? clock,
  })  : _gateway = gateway,
        _resourceManager = resourceManager,
        _cameraResourceManager = cameraResourceManager,
        _audioArbitrator = audioArbitrator,
        _database = database,
        _policy = FlashlightPolicyEvaluator(clock: clock) {
    _cameraResourceManager?.addLumaListener(_onActiveCameraLuma);
  }

  static const String prefAutoEnabledKey = 'flashlight_auto_enabled';
  static const String prefLowLightLuxKey = 'flashlight_low_light_lux';

  final FlashlightGateway _gateway;
  final DeviceResourceManager _resourceManager;
  final CameraResourceManager? _cameraResourceManager;
  final AudioArbitrator? _audioArbitrator;
  final OpenetraDatabase? _database;
  final FlashlightPolicyEvaluator _policy;

  final StreamController<FlashlightControllerState> _controller =
      StreamController<FlashlightControllerState>.broadcast();

  FlashlightPolicyConfig _config = const FlashlightPolicyConfig();
  FlashlightHardwareStatus _hardware = FlashlightHardwareStatus.unavailable();
  bool _manualOverrideActive = false;
  bool _autoPaused = false;
  bool _isAuthorizedTaskActive = false;
  String _statusSummary = 'Flashlight ready.';
  String _locale = 'en-IN';
  Timer? _sensorPollTimer;

  Stream<FlashlightControllerState> get stream => _controller.stream;

  FlashlightControllerState get state => FlashlightControllerState(
        config: _config,
        hardwareStatus: _hardware,
        manualOverrideActive: _manualOverrideActive,
        autoPaused: _autoPaused,
        isAuthorizedTaskActive: _isAuthorizedTaskActive,
        statusSummary: _statusSummary,
      );

  void setLocale(String locale) {
    _locale = locale;
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(state);
  }

  Future<void> initialize() async {
    final autoRaw = await _database?.getAssistivePreference(prefAutoEnabledKey);
    final luxRaw = await _database?.getAssistivePreference(prefLowLightLuxKey);
    final parsedLux = double.tryParse(luxRaw ?? '');
    final clampedLux = parsedLux?.clamp(5.0, 40.0).toDouble();
    _config = _config.copyWith(
      autoModeEnabled: autoRaw == 'true',
      lowLightTurnOnLux: clampedLux,
      brightTurnOffLux: clampedLux == null ? null : clampedLux * 3.0,
    );
    _hardware = await _gateway.getStatus();
    _statusSummary = _hardware.hasFlash
        ? (_hardware.torchOn ? 'Flashlight on.' : 'Flashlight off.')
        : 'Flashlight unavailable.';
    _emit();
  }

  Future<void> refreshStatus() async {
    _hardware = await _gateway.getStatus();
    _emit();
  }

  Future<TorchApplyResult> toggleManual() async {
    _hardware = await _gateway.getStatus();
    final targetOn = !_hardware.torchOn;
    return setManualTorch(targetOn);
  }

  Future<TorchApplyResult> setManualTorch(bool enabled) async {
    _hardware = await _gateway.getStatus();
    if (!_hardware.hasFlash || !_hardware.torchAvailable) {
      _statusSummary = 'Flashlight unavailable.';
      _announce('Flashlight unavailable.');
      _emit();
      return const TorchApplyResult(
        applied: false,
        torchOn: false,
        openetraOwnsTorch: false,
        reason: 'TORCH_UNAVAILABLE',
      );
    }
    if (!enabled && _hardware.externalTorchActive) {
      _statusSummary =
          'Flashlight is controlled outside Openetra; turn it off from Quick Settings.';
      _announce('Flashlight unavailable.');
      _emit();
      return const TorchApplyResult(
        applied: false,
        torchOn: true,
        openetraOwnsTorch: false,
        reason: 'EXTERNAL_TORCH_OWNER',
      );
    }

    final res = await _gateway.setTorch(enabled);
    _hardware = await _gateway.getStatus();
    if (res.applied) {
      _manualOverrideActive = true;
      _autoPaused = false;
      _policy.markManualTransition(enabled);
      _statusSummary = enabled ? 'Flashlight on.' : 'Flashlight off.';
      _announce(_statusSummary);
    } else {
      _statusSummary = 'Flashlight unavailable.';
      _announce('Flashlight unavailable.');
    }
    _emit();
    return res;
  }

  Future<void> setAutoModeEnabled(bool enabled) async {
    _config = _config.copyWith(autoModeEnabled: enabled);
    _autoPaused = false;
    await _database?.setAssistivePreference(
      prefAutoEnabledKey,
      enabled.toString(),
    );
    if (!enabled) {
      await _gateway.setLightSensorMonitoring(false);
      _stopPolling();
      await turnOffIfOwned(announce: true);
    } else if (_isAuthorizedTaskActive) {
      await _gateway.setLightSensorMonitoring(true);
    }
    _emit();
  }

  Future<void> setLowLightThresholdLux(double lux) async {
    final clamped = lux.clamp(5.0, 40.0);
    _config = _config.copyWith(
      lowLightTurnOnLux: clamped,
      brightTurnOffLux: clamped * 3.0,
    );
    await _database?.setAssistivePreference(
      prefLowLightLuxKey,
      clamped.toStringAsFixed(1),
    );
    _emit();
  }

  Future<void> beginAuthorizedTaskSession({bool enablePolling = false}) async {
    _isAuthorizedTaskActive = true;
    _manualOverrideActive = false;
    _autoPaused = false;
    _policy.resetTimers();
    if (_config.autoModeEnabled) {
      await _gateway.setLightSensorMonitoring(true);
      if (enablePolling) {
        _sensorPollTimer?.cancel();
        _sensorPollTimer = Timer.periodic(
          const Duration(milliseconds: 600),
          (_) => evaluateCurrentConditions(),
        );
      }
    }
    _emit();
  }

  Future<void> endAuthorizedTaskSession() async {
    _isAuthorizedTaskActive = false;
    _manualOverrideActive = false;
    _stopPolling();
    await _gateway.setLightSensorMonitoring(false);
    await turnOffIfOwned(announce: false);
    _emit();
  }

  void _onActiveCameraLuma(double meanLuma) {
    if (!_isAuthorizedTaskActive || !_config.autoModeEnabled) return;
    evaluateCurrentConditions(activeFrameLumaOverride: meanLuma);
  }

  Future<void> evaluateCurrentConditions({double? activeFrameLumaOverride}) async {
    _hardware = await _gateway.getStatus();
    if (!_config.autoModeEnabled || !_isAuthorizedTaskActive) return;

    final lux = _hardware.hasLightSensor && _hardware.ambientLightLux >= 0
        ? _hardware.ambientLightLux
        : null;
    final luma = activeFrameLumaOverride ??
        (_hardware.activeFrameMeanLuma >= 0
            ? _hardware.activeFrameMeanLuma
            : null);

    final decision = _policy.evaluate(
      config: _config,
      isAuthorizedTaskActive: _isAuthorizedTaskActive,
      manualOverrideActive: _manualOverrideActive,
      torchCurrentlyOn: _hardware.torchOn,
      openetraOwnsTorch: _hardware.openetraOwnsTorch,
      resourceState: _resourceManager.currentState,
      ambientLux: lux,
      activeFrameMeanLuma: luma,
    );

    switch (decision.type) {
      case TorchDecisionType.turnOn:
        final res = await _gateway.setTorch(true);
        _hardware = await _gateway.getStatus();
        if (res.applied) {
          _statusSummary = 'Flashlight on.';
          _announce('Flashlight on.');
        } else {
          _statusSummary = 'Flashlight unavailable.';
        }
        _emit();
      case TorchDecisionType.turnOff:
        await turnOffIfOwned(announce: true);
      case TorchDecisionType.pauseAutoMode:
        if (!_autoPaused) {
          _autoPaused = true;
          await turnOffIfOwned(announce: false);
          _statusSummary = 'Automatic flashlight paused.';
          _announce('Automatic flashlight paused.');
          _emit();
        }
      case TorchDecisionType.noChange:
        break;
    }
  }

  Future<void> turnOffIfOwned({bool announce = true}) async {
    _hardware = await _gateway.getStatus();
    if (_hardware.torchOn && _hardware.openetraOwnsTorch) {
      final res = await _gateway.setTorch(false);
      _hardware = await _gateway.getStatus();
      if (res.applied && announce) {
        _statusSummary = 'Flashlight off.';
        _announce('Flashlight off.');
      }
    }
  }

  void _announce(String phrase) {
    _audioArbitrator?.announceTransition(
      categoryKey: 'flashlight',
      spokenText: phrase,
      locale: _locale,
      cooldown: const Duration(milliseconds: 1800),
      haptic: HapticPattern.confirm,
    );
  }

  void _stopPolling() {
    _sensorPollTimer?.cancel();
    _sensorPollTimer = null;
  }

  Future<void> dispose() async {
    _stopPolling();
    _cameraResourceManager?.removeLumaListener(_onActiveCameraLuma);
    await _gateway.setLightSensorMonitoring(false);
    await turnOffIfOwned(announce: false);
    await _controller.close();
  }
}
