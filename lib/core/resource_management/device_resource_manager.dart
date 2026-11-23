import 'package:flutter/services.dart';
import '../domain/entities/entities.dart';

/// Abstracts platform resource queries for testability and native Android execution.
abstract class NativeResourceGateway {
  Future<Map<String, dynamic>> readTelemetry();
  Future<Map<String, bool>> checkOfflineVoices(List<String> locales);
}

class MethodChannelResourceGateway implements NativeResourceGateway {
  MethodChannelResourceGateway([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/resources');

  final MethodChannel _channel;

  @override
  Future<Map<String, dynamic>> readTelemetry() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getTelemetry');
      return raw ?? const {};
    } on MissingPluginException {
      return const {};
    }
  }

  @override
  Future<Map<String, bool>> checkOfflineVoices(List<String> locales) async {
    try {
      final raw = await _channel.invokeMapMethod<String, bool>(
        'checkOfflineVoices',
        {'locales': locales},
      );
      return raw ?? {for (final l in locales) l: false};
    } on MissingPluginException {
      return {for (final l in locales) l: false};
    }
  }
}

/// Manages operating mode, thermal/battery budgets, and honest safety degradation notices.
class DeviceResourceManager {
  DeviceResourceManager({NativeResourceGateway? gateway})
      : _gateway = gateway ?? MethodChannelResourceGateway();

  final NativeResourceGateway _gateway;
  DeviceResourceState _state = DeviceResourceState.nominalBalanced;

  DeviceResourceState get currentState => _state;

  DeviceResourceState setOperatingMode(OperatingMode mode) {
    _state = _recompute(
      mode: mode,
      batteryPercent: _state.batteryPercent,
      isCharging: _state.isCharging,
      thermalState: _state.thermalState,
      availableRamMb: _state.availableRamMb,
      isLowMemory: _state.isLowMemory,
    );
    return _state;
  }

  Future<DeviceResourceState> refreshTelemetry() async {
    final data = await _gateway.readTelemetry();
    if (data.isEmpty) return _state;
    final battery = (data['batteryPercent'] as num?)?.toInt() ?? _state.batteryPercent;
    final charging = (data['isCharging'] as bool?) ?? _state.isCharging;
    final ramMb = (data['availableRamMb'] as num?)?.toInt() ?? _state.availableRamMb;
    final lowMem = (data['isLowMemory'] as bool?) ?? _state.isLowMemory;
    final thermalCode = (data['thermalLevel'] as num?)?.toInt() ?? 0;
    final thermal = _mapAndroidThermal(thermalCode);

    _state = _recompute(
      mode: _state.operatingMode,
      batteryPercent: battery,
      isCharging: charging,
      thermalState: thermal,
      availableRamMb: ramMb,
      isLowMemory: lowMem,
    );
    return _state;
  }

  DeviceResourceState applySimulatedTelemetry({
    OperatingMode? mode,
    int? batteryPercent,
    bool? isCharging,
    ThermalState? thermalState,
    int? availableRamMb,
    bool? isLowMemory,
  }) {
    _state = _recompute(
      mode: mode ?? _state.operatingMode,
      batteryPercent: batteryPercent ?? _state.batteryPercent,
      isCharging: isCharging ?? _state.isCharging,
      thermalState: thermalState ?? _state.thermalState,
      availableRamMb: availableRamMb ?? _state.availableRamMb,
      isLowMemory: isLowMemory ?? _state.isLowMemory,
    );
    return _state;
  }

  Future<Map<String, bool>> checkOfflineVoiceAvailability(
    List<String> locales,
  ) =>
      _gateway.checkOfflineVoices(locales);

  static ThermalState _mapAndroidThermal(int level) {
    if (level <= 0) return ThermalState.nominal;
    if (level == 1) return ThermalState.light;
    if (level == 2) return ThermalState.moderate;
    if (level == 3) return ThermalState.severe;
    return ThermalState.critical;
  }

  static DeviceResourceState _recompute({
    required OperatingMode mode,
    required int batteryPercent,
    required bool isCharging,
    required ThermalState thermalState,
    required int availableRamMb,
    required bool isLowMemory,
  }) {
    int baseInterval = switch (mode) {
      OperatingMode.eco => 2500,
      OperatingMode.balanced => 1200,
      OperatingMode.reading => 1500,
      OperatingMode.objectSearch => 1000,
      OperatingMode.hazardAwareness => 550,
      OperatingMode.idle => 0,
    };

    int threads = mode == OperatingMode.eco ? 2 : 0;
    bool degraded = false;
    final notes = <String>[];

    if (thermalState == ThermalState.severe ||
        thermalState == ThermalState.critical) {
      degraded = true;
      threads = 2;
      baseInterval = (baseInterval * 2).clamp(1200, 4000);
      notes.add('Device temperature is high; hazard scan cadence is reduced');
    } else if (thermalState == ThermalState.moderate) {
      threads = 2;
      if (mode == OperatingMode.hazardAwareness) {
        baseInterval = 900;
        degraded = true;
        notes.add('Moderate device heat; reducing scan frequency slightly');
      }
    }

    if (batteryPercent <= 15 && !isCharging) {
      threads = 2;
      if (mode == OperatingMode.hazardAwareness) {
        baseInterval = baseInterval < 1000 ? 1000 : baseInterval;
        degraded = true;
        notes.add('Low battery ($batteryPercent%); scan interval widened');
      }
    }

    if (isLowMemory || availableRamMb < 400) {
      degraded = true;
      threads = 2;
      notes.add('Low available memory; keeping only primary vision model active');
    }

    return DeviceResourceState(
      operatingMode: mode,
      batteryPercent: batteryPercent,
      isCharging: isCharging,
      thermalState: thermalState,
      availableRamMb: availableRamMb,
      isLowMemory: isLowMemory,
      recommendedThreads: threads,
      inferenceIntervalMs: baseInterval,
      isDegradedCapability: degraded,
      degradationMessage: notes.isEmpty ? null : '${notes.join('. ')}.',
    );
  }
}
