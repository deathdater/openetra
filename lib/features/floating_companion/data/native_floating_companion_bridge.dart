import 'dart:async';
import 'package:flutter/services.dart';
import '../../../core/assistive/assistive_action.dart';
import '../../../core/assistive/feedback_dispatcher.dart';
import '../domain/floating_widget_config.dart';

class OverlayActionEvent {
  const OverlayActionEvent({
    required this.actionWireId,
    required this.fromBackground,
  });

  final String actionWireId;
  final bool fromBackground;
}

class OverlayPermissionStatus {
  const OverlayPermissionStatus({
    required this.granted,
    required this.serviceRunning,
  });

  final bool granted;
  final bool serviceRunning;
}

abstract class FloatingCompanionBridge implements FloatingOverlayStateSink {
  Stream<OverlayActionEvent> get overlayActions;
  Future<OverlayPermissionStatus> checkOverlayPermission();
  Future<void> openOverlaySettings();
  Future<bool> startOverlay(FloatingWidgetConfig config);
  Future<void> stopOverlay();
  Future<void> updateConfig(FloatingWidgetConfig config);
  Future<void> dispose();
}

/// Bridges Flutter to `FloatingCompanionPlugin.kt` (`com.openetra.app/floating_companion`).
class NativeFloatingCompanionBridge implements FloatingCompanionBridge {
  NativeFloatingCompanionBridge([MethodChannel? channel])
      : _channel =
            channel ?? const MethodChannel('com.openetra.app/floating_companion') {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<OverlayActionEvent> _actions =
      StreamController<OverlayActionEvent>.broadcast();

  @override
  Stream<OverlayActionEvent> get overlayActions => _actions.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onOverlayAction' && call.arguments is Map) {
      final map = Map<String, dynamic>.from(call.arguments as Map);
      final wireId = (map['actionId'] ?? '').toString();
      final fromBg = map['fromBackground'] == true;
      if (wireId.isNotEmpty && !_actions.isClosed) {
        _actions.add(
          OverlayActionEvent(actionWireId: wireId, fromBackground: fromBg),
        );
      }
    }
    return null;
  }

  @override
  Future<OverlayPermissionStatus> checkOverlayPermission() async {
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('checkOverlayPermission');
      return OverlayPermissionStatus(
        granted: (res?['granted'] as bool?) ?? false,
        serviceRunning: (res?['serviceRunning'] as bool?) ?? false,
      );
    } on MissingPluginException {
      return const OverlayPermissionStatus(
        granted: false,
        serviceRunning: false,
      );
    }
  }

  @override
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } on MissingPluginException {
      // Host test no-op.
    }
  }

  @override
  Future<bool> startOverlay(FloatingWidgetConfig config) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'startOverlay',
        config.toNativeMap(),
      );
      return (res?['started'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> stopOverlay() async {
    try {
      await _channel.invokeMethod<void>('stopOverlay');
    } on MissingPluginException {
      // Host test no-op.
    }
  }

  @override
  Future<void> updateConfig(FloatingWidgetConfig config) async {
    try {
      await _channel.invokeMethod<void>('updateConfig', config.toNativeMap());
    } on MissingPluginException {
      // Host test no-op.
    }
  }

  @override
  Future<void> publishWidgetState(AssistiveTaskSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('updateWidgetState', {
        'phase': snapshot.phase.name,
        'statusLabel': snapshot.statusLabel,
      });
    } on MissingPluginException {
      // Host test no-op.
    }
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _actions.close();
  }
}

/// Deterministic test double for host verification of overlay lifecycle & state.
class FakeFloatingCompanionBridge implements FloatingCompanionBridge {
  bool permissionGranted = true;
  bool serviceRunning = false;
  int openSettingsCount = 0;
  FloatingWidgetConfig? lastConfig;
  final List<AssistiveTaskSnapshot> publishedStates = [];
  final StreamController<OverlayActionEvent> _actions =
      StreamController<OverlayActionEvent>.broadcast();

  void simulateOrbTrigger(String wireId, {bool fromBackground = false}) {
    if (!_actions.isClosed) {
      _actions.add(
        OverlayActionEvent(
          actionWireId: wireId,
          fromBackground: fromBackground,
        ),
      );
    }
  }

  @override
  Stream<OverlayActionEvent> get overlayActions => _actions.stream;

  @override
  Future<OverlayPermissionStatus> checkOverlayPermission() async {
    return OverlayPermissionStatus(
      granted: permissionGranted,
      serviceRunning: serviceRunning,
    );
  }

  @override
  Future<void> openOverlaySettings() async {
    openSettingsCount++;
  }

  @override
  Future<bool> startOverlay(FloatingWidgetConfig config) async {
    if (!permissionGranted) return false;
    serviceRunning = true;
    lastConfig = config;
    return true;
  }

  @override
  Future<void> stopOverlay() async {
    serviceRunning = false;
  }

  @override
  Future<void> updateConfig(FloatingWidgetConfig config) async {
    lastConfig = config;
  }

  @override
  Future<void> publishWidgetState(AssistiveTaskSnapshot snapshot) async {
    publishedStates.add(snapshot);
  }

  @override
  Future<void> dispose() async {
    await _actions.close();
  }
}
