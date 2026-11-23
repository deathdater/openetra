import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

class FlashlightHardwareStatus extends Equatable {
  const FlashlightHardwareStatus({
    required this.hasFlash,
    required this.torchAvailable,
    required this.torchOn,
    required this.openetraOwnsTorch,
    required this.externalTorchActive,
    required this.hasLightSensor,
    required this.ambientLightLux,
    required this.activeFrameMeanLuma,
    required this.cameraActive,
  });

  factory FlashlightHardwareStatus.unavailable() => const FlashlightHardwareStatus(
        hasFlash: false,
        torchAvailable: false,
        torchOn: false,
        openetraOwnsTorch: false,
        externalTorchActive: false,
        hasLightSensor: false,
        ambientLightLux: -1.0,
        activeFrameMeanLuma: -1.0,
        cameraActive: false,
      );

  final bool hasFlash;
  final bool torchAvailable;
  final bool torchOn;
  final bool openetraOwnsTorch;
  final bool externalTorchActive;
  final bool hasLightSensor;
  final double ambientLightLux;
  final double activeFrameMeanLuma;
  final bool cameraActive;

  @override
  List<Object?> get props => [
        hasFlash,
        torchAvailable,
        torchOn,
        openetraOwnsTorch,
        externalTorchActive,
        hasLightSensor,
        ambientLightLux,
        activeFrameMeanLuma,
        cameraActive,
      ];
}

class TorchApplyResult extends Equatable {
  const TorchApplyResult({
    required this.applied,
    required this.torchOn,
    required this.openetraOwnsTorch,
    this.reason,
  });

  final bool applied;
  final bool torchOn;
  final bool openetraOwnsTorch;
  final String? reason;

  @override
  List<Object?> get props => [applied, torchOn, openetraOwnsTorch, reason];
}

abstract class FlashlightGateway {
  Future<FlashlightHardwareStatus> getStatus();
  Future<TorchApplyResult> setTorch(bool enabled);
  Future<void> setLightSensorMonitoring(bool enabled);
}

class NativeFlashlightGateway implements FlashlightGateway {
  NativeFlashlightGateway([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/flashlight');

  final MethodChannel _channel;

  @override
  Future<FlashlightHardwareStatus> getStatus() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      if (res == null) return FlashlightHardwareStatus.unavailable();
      return FlashlightHardwareStatus(
        hasFlash: (res['hasFlash'] as bool?) ?? false,
        torchAvailable: (res['torchAvailable'] as bool?) ?? false,
        torchOn: (res['torchOn'] as bool?) ?? false,
        openetraOwnsTorch: (res['openetraOwnsTorch'] as bool?) ?? false,
        externalTorchActive: (res['externalTorchActive'] as bool?) ?? false,
        hasLightSensor: (res['hasLightSensor'] as bool?) ?? false,
        ambientLightLux: (res['ambientLightLux'] as num?)?.toDouble() ?? -1.0,
        activeFrameMeanLuma:
            (res['activeFrameMeanLuma'] as num?)?.toDouble() ?? -1.0,
        cameraActive: (res['cameraActive'] as bool?) ?? false,
      );
    } on MissingPluginException {
      return FlashlightHardwareStatus.unavailable();
    }
  }

  @override
  Future<TorchApplyResult> setTorch(bool enabled) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'setTorch',
        {'enabled': enabled},
      );
      if (res == null) {
        return const TorchApplyResult(
          applied: false,
          torchOn: false,
          openetraOwnsTorch: false,
          reason: 'TORCH_UNAVAILABLE',
        );
      }
      return TorchApplyResult(
        applied: (res['applied'] as bool?) ?? false,
        torchOn: (res['torchOn'] as bool?) ?? false,
        openetraOwnsTorch: (res['openetraOwnsTorch'] as bool?) ?? false,
        reason: res['reason']?.toString(),
      );
    } on MissingPluginException {
      return const TorchApplyResult(
        applied: false,
        torchOn: false,
        openetraOwnsTorch: false,
        reason: 'FLASHLIGHT_UNAVAILABLE_ON_HOST',
      );
    }
  }

  @override
  Future<void> setLightSensorMonitoring(bool enabled) async {
    try {
      await _channel.invokeMethod<void>(
        'setLightSensorMonitoring',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // Host test safe no-op.
    }
  }
}

/// Deterministic test double for host verification of hysteresis & ownership.
class FakeFlashlightGateway implements FlashlightGateway {
  bool hasFlash = true;
  bool torchAvailable = true;
  bool torchOn = false;
  bool openetraOwnsTorch = false;
  bool hasLightSensor = true;
  double ambientLightLux = 100.0;
  double activeFrameMeanLuma = 120.0;
  bool cameraActive = false;
  bool sensorMonitoringEnabled = false;

  void simulateExternalTorch(bool enabled) {
    torchOn = enabled;
    openetraOwnsTorch = false;
  }

  @override
  Future<FlashlightHardwareStatus> getStatus() async {
    return FlashlightHardwareStatus(
      hasFlash: hasFlash,
      torchAvailable: hasFlash && torchAvailable,
      torchOn: torchOn,
      openetraOwnsTorch: openetraOwnsTorch && torchOn,
      externalTorchActive: torchOn && !openetraOwnsTorch,
      hasLightSensor: hasLightSensor,
      ambientLightLux: ambientLightLux,
      activeFrameMeanLuma: activeFrameMeanLuma,
      cameraActive: cameraActive,
    );
  }

  @override
  Future<TorchApplyResult> setTorch(bool enabled) async {
    if (!hasFlash || !torchAvailable) {
      return const TorchApplyResult(
        applied: false,
        torchOn: false,
        openetraOwnsTorch: false,
        reason: 'NO_FLASH_HARDWARE',
      );
    }
    if (!enabled && torchOn && !openetraOwnsTorch) {
      return const TorchApplyResult(
        applied: false,
        torchOn: true,
        openetraOwnsTorch: false,
        reason: 'EXTERNAL_TORCH_OWNER',
      );
    }
    torchOn = enabled;
    openetraOwnsTorch = enabled;
    return TorchApplyResult(
      applied: true,
      torchOn: torchOn,
      openetraOwnsTorch: openetraOwnsTorch,
    );
  }

  @override
  Future<void> setLightSensorMonitoring(bool enabled) async {
    sensorMonitoringEnabled = enabled;
  }
}
