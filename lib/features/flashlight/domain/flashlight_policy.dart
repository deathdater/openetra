import 'package:equatable/equatable.dart';
import '../../../core/domain/entities/entities.dart';

class FlashlightPolicyConfig extends Equatable {
  const FlashlightPolicyConfig({
    this.autoModeEnabled = false,
    this.lowLightTurnOnLux = 15.0,
    this.brightTurnOffLux = 45.0,
    this.lowLightTurnOnLuma = 48.0,
    this.brightTurnOffLuma = 90.0,
    this.minDwell = const Duration(milliseconds: 4000),
    this.transitionDebounce = const Duration(milliseconds: 1500),
    this.maxContinuousOn = const Duration(seconds: 180),
    this.lowBatteryCutoffPercent = 15,
  });

  final bool autoModeEnabled;
  final double lowLightTurnOnLux;
  final double brightTurnOffLux;
  final double lowLightTurnOnLuma;
  final double brightTurnOffLuma;
  final Duration minDwell;
  final Duration transitionDebounce;
  final Duration maxContinuousOn;
  final int lowBatteryCutoffPercent;

  FlashlightPolicyConfig copyWith({
    bool? autoModeEnabled,
    double? lowLightTurnOnLux,
    double? brightTurnOffLux,
    double? lowLightTurnOnLuma,
    double? brightTurnOffLuma,
    Duration? minDwell,
    Duration? transitionDebounce,
    Duration? maxContinuousOn,
    int? lowBatteryCutoffPercent,
  }) {
    return FlashlightPolicyConfig(
      autoModeEnabled: autoModeEnabled ?? this.autoModeEnabled,
      lowLightTurnOnLux: lowLightTurnOnLux ?? this.lowLightTurnOnLux,
      brightTurnOffLux: brightTurnOffLux ?? this.brightTurnOffLux,
      lowLightTurnOnLuma: lowLightTurnOnLuma ?? this.lowLightTurnOnLuma,
      brightTurnOffLuma: brightTurnOffLuma ?? this.brightTurnOffLuma,
      minDwell: minDwell ?? this.minDwell,
      transitionDebounce: transitionDebounce ?? this.transitionDebounce,
      maxContinuousOn: maxContinuousOn ?? this.maxContinuousOn,
      lowBatteryCutoffPercent:
          lowBatteryCutoffPercent ?? this.lowBatteryCutoffPercent,
    );
  }

  @override
  List<Object?> get props => [
        autoModeEnabled,
        lowLightTurnOnLux,
        brightTurnOffLux,
        lowLightTurnOnLuma,
        brightTurnOffLuma,
        minDwell,
        transitionDebounce,
        maxContinuousOn,
        lowBatteryCutoffPercent,
      ];
}

enum TorchDecisionType {
  noChange,
  turnOn,
  turnOff,
  pauseAutoMode,
}

class TorchPolicyDecision extends Equatable {
  const TorchPolicyDecision({
    required this.type,
    this.reason,
  });

  final TorchDecisionType type;
  final String? reason;

  @override
  List<Object?> get props => [type, reason];
}

/// Hysteresis, dwell, debounce, thermal/battery, and ownership safety policy for
/// opt-in automatic flashlight control during authorized active Openetra tasks.
class FlashlightPolicyEvaluator {
  FlashlightPolicyEvaluator({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _lastTransitionAt;
  DateTime? _darkConditionSince;
  DateTime? _brightConditionSince;
  DateTime? _turnedOnAt;

  void resetTimers() {
    _lastTransitionAt = null;
    _darkConditionSince = null;
    _brightConditionSince = null;
    _turnedOnAt = null;
  }

  void markManualTransition(bool isNowOn) {
    final now = _clock();
    _lastTransitionAt = now;
    _darkConditionSince = null;
    _brightConditionSince = null;
    _turnedOnAt = isNowOn ? now : null;
  }

  TorchPolicyDecision evaluate({
    required FlashlightPolicyConfig config,
    required bool isAuthorizedTaskActive,
    required bool manualOverrideActive,
    required bool torchCurrentlyOn,
    required bool openetraOwnsTorch,
    required DeviceResourceState resourceState,
    double? ambientLux,
    double? activeFrameMeanLuma,
  }) {
    if (!config.autoModeEnabled || !isAuthorizedTaskActive) {
      return const TorchPolicyDecision(type: TorchDecisionType.noChange);
    }
    if (manualOverrideActive) {
      return const TorchPolicyDecision(type: TorchDecisionType.noChange);
    }
    if (torchCurrentlyOn && !openetraOwnsTorch) {
      // External app or user system quick-setting owns the torch. Do not touch it.
      return const TorchPolicyDecision(
        type: TorchDecisionType.noChange,
        reason: 'External torch active; Openetra will not override.',
      );
    }

    // Battery & thermal constraints always take precedence.
    final lowBattery = !resourceState.isCharging &&
        resourceState.batteryPercent <= config.lowBatteryCutoffPercent;
    final highHeat = resourceState.thermalState == ThermalState.severe ||
        resourceState.thermalState == ThermalState.critical;
    if (lowBattery || highHeat) {
      return TorchPolicyDecision(
        type: TorchDecisionType.pauseAutoMode,
        reason: highHeat
            ? 'Device temperature is high'
            : 'Low battery (${resourceState.batteryPercent}%)',
      );
    }

    final now = _clock();

    // Enforce maximum continuous-on safety timeout.
    if (torchCurrentlyOn &&
        openetraOwnsTorch &&
        _turnedOnAt != null &&
        now.difference(_turnedOnAt!) >= config.maxContinuousOn) {
      _lastTransitionAt = now;
      _turnedOnAt = null;
      return const TorchPolicyDecision(
        type: TorchDecisionType.pauseAutoMode,
        reason: 'Maximum continuous-on safety limit reached',
      );
    }

    // Dwell check prevents rapid flipping.
    if (_lastTransitionAt != null &&
        now.difference(_lastTransitionAt!) < config.minDwell) {
      return const TorchPolicyDecision(type: TorchDecisionType.noChange);
    }

    final bool hasLux = ambientLux != null && ambientLux >= 0.0;
    final bool hasLuma = activeFrameMeanLuma != null && activeFrameMeanLuma >= 0.0;
    if (!hasLux && !hasLuma) {
      return const TorchPolicyDecision(type: TorchDecisionType.noChange);
    }

    final bool isDark = hasLux
        ? ambientLux <= config.lowLightTurnOnLux
        : activeFrameMeanLuma! <= config.lowLightTurnOnLuma;
    final bool isBright = hasLux
        ? ambientLux >= config.brightTurnOffLux
        : activeFrameMeanLuma! >= config.brightTurnOffLuma;

    if (!torchCurrentlyOn && isDark) {
      _brightConditionSince = null;
      _darkConditionSince ??= now;
      if (now.difference(_darkConditionSince!) >= config.transitionDebounce) {
        _lastTransitionAt = now;
        _turnedOnAt = now;
        _darkConditionSince = null;
        return const TorchPolicyDecision(
          type: TorchDecisionType.turnOn,
          reason: 'Low light sustained during active task',
        );
      }
      return const TorchPolicyDecision(type: TorchDecisionType.noChange);
    }

    if (torchCurrentlyOn && openetraOwnsTorch && isBright) {
      _darkConditionSince = null;
      _brightConditionSince ??= now;
      if (now.difference(_brightConditionSince!) >= config.transitionDebounce) {
        _lastTransitionAt = now;
        _turnedOnAt = null;
        _brightConditionSince = null;
        return const TorchPolicyDecision(
          type: TorchDecisionType.turnOff,
          reason: 'Sufficient light sustained',
        );
      }
      return const TorchPolicyDecision(type: TorchDecisionType.noChange);
    }

    // In dead-band between turn-on and turn-off thresholds -> hold steady.
    _darkConditionSince = null;
    _brightConditionSince = null;
    return const TorchPolicyDecision(type: TorchDecisionType.noChange);
  }
}
