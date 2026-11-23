import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/assistive/assistive_action.dart';
import '../../../core/assistive/assistive_action_router.dart';
import '../../../core/assistive/task_orchestrator.dart';
import '../../../core/storage/openetra_database.dart';
import '../data/native_floating_companion_bridge.dart';
import '../domain/floating_widget_config.dart';

abstract class FloatingCompanionEvent extends Equatable {
  const FloatingCompanionEvent();

  @override
  List<Object?> get props => [];
}

class LoadFloatingCompanionConfig extends FloatingCompanionEvent {
  const LoadFloatingCompanionConfig();
}

class RefreshOverlayPermission extends FloatingCompanionEvent {
  const RefreshOverlayPermission();
}

class RequestOpenOverlaySettings extends FloatingCompanionEvent {
  const RequestOpenOverlaySettings();
}

class ToggleFloatingCompanion extends FloatingCompanionEvent {
  const ToggleFloatingCompanion(this.enabled);
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class UpdateFloatingCompanionConfig extends FloatingCompanionEvent {
  const UpdateFloatingCompanionConfig(this.config);
  final FloatingWidgetConfig config;

  @override
  List<Object?> get props => [config];
}

class _OverlayActionReceived extends FloatingCompanionEvent {
  const _OverlayActionReceived(this.event);
  final OverlayActionEvent event;

  @override
  List<Object?> get props => [event];
}

class FloatingCompanionState extends Equatable {
  const FloatingCompanionState({
    this.config = const FloatingWidgetConfig(),
    this.overlayPermissionGranted = false,
    this.serviceRunning = false,
    this.statusMessage,
  });

  final FloatingWidgetConfig config;
  final bool overlayPermissionGranted;
  final bool serviceRunning;
  final String? statusMessage;

  FloatingCompanionState copyWith({
    FloatingWidgetConfig? config,
    bool? overlayPermissionGranted,
    bool? serviceRunning,
    String? statusMessage,
  }) {
    return FloatingCompanionState(
      config: config ?? this.config,
      overlayPermissionGranted:
          overlayPermissionGranted ?? this.overlayPermissionGranted,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      statusMessage: statusMessage,
    );
  }

  @override
  List<Object?> get props => [
        config,
        overlayPermissionGranted,
        serviceRunning,
        statusMessage,
      ];
}

/// Manages optional Floating Assistive Companion lifecycle, permissions, and
/// routes orb events strictly through [TaskOrchestrator] / [AssistiveActionRouter].
class FloatingCompanionBloc
    extends Bloc<FloatingCompanionEvent, FloatingCompanionState> {
  FloatingCompanionBloc({
    required this.bridge,
    required this.taskOrchestrator,
    this.database,
  }) : super(const FloatingCompanionState()) {
    on<LoadFloatingCompanionConfig>(_onLoad);
    on<RefreshOverlayPermission>(_onRefreshPermission);
    on<RequestOpenOverlaySettings>(_onOpenSettings);
    on<ToggleFloatingCompanion>(_onToggle);
    on<UpdateFloatingCompanionConfig>(_onUpdateConfig);
    on<_OverlayActionReceived>(_onOverlayAction);

    _actionSub = bridge.overlayActions.listen((ev) {
      if (!isClosed) add(_OverlayActionReceived(ev));
    });
  }

  static const String prefEnabledKey = 'floating_widget_enabled';
  static const String prefPrimaryActionKey = 'floating_widget_primary_action';
  static const String prefSecondaryActionKey = 'floating_widget_secondary_action';
  static const String prefLongPressActionKey = 'floating_widget_long_press_action';
  static const String prefOrbSizeKey = 'floating_widget_orb_size_dp';
  static const String prefReducedMotionKey = 'floating_widget_reduced_motion';

  final FloatingCompanionBridge bridge;
  final TaskOrchestrator taskOrchestrator;
  final OpenetraDatabase? database;
  StreamSubscription<OverlayActionEvent>? _actionSub;

  Future<void> _onLoad(
    LoadFloatingCompanionConfig event,
    Emitter<FloatingCompanionState> emit,
  ) async {
    final perm = await bridge.checkOverlayPermission();
    final enabledRaw = await database?.getAssistivePreference(prefEnabledKey);
    final primRaw = await database?.getAssistivePreference(prefPrimaryActionKey);
    final secRaw = await database?.getAssistivePreference(prefSecondaryActionKey);
    final longRaw = await database?.getAssistivePreference(prefLongPressActionKey);
    final sizeRaw = await database?.getAssistivePreference(prefOrbSizeKey);
    final reducedRaw =
        await database?.getAssistivePreference(prefReducedMotionKey);

    final loaded = FloatingWidgetConfig(
      enabled: (enabledRaw == 'true') && perm.granted,
      primaryAction: AssistiveActionRouter.parseId(primRaw ?? '') ??
          AssistiveActionId.describeScene,
      secondaryAction: AssistiveActionRouter.parseId(secRaw ?? '') ??
          AssistiveActionId.cancelActiveTask,
      longPressAction: AssistiveActionRouter.parseId(longRaw ?? '') ??
          AssistiveActionId.startEmergencyAssistance,
      orbSizeDp: int.tryParse(sizeRaw ?? '') ?? 64,
      reducedMotionOverride: reducedRaw == 'true',
    );

    if (loaded.enabled && !perm.serviceRunning) {
      final started = await bridge.startOverlay(loaded);
      emit(state.copyWith(
        config: loaded.copyWith(enabled: started),
        overlayPermissionGranted: perm.granted,
        serviceRunning: started,
      ));
      return;
    }

    emit(state.copyWith(
      config: loaded,
      overlayPermissionGranted: perm.granted,
      serviceRunning: perm.serviceRunning,
    ));
  }

  Future<void> _onRefreshPermission(
    RefreshOverlayPermission event,
    Emitter<FloatingCompanionState> emit,
  ) async {
    final perm = await bridge.checkOverlayPermission();
    if (!perm.granted && state.config.enabled) {
      await bridge.stopOverlay();
      await database?.setAssistivePreference(prefEnabledKey, 'false');
      emit(state.copyWith(
        config: state.config.copyWith(enabled: false),
        overlayPermissionGranted: false,
        serviceRunning: false,
        statusMessage:
            'Overlay permission revoked. Floating companion turned off safely.',
      ));
      return;
    }
    emit(state.copyWith(
      overlayPermissionGranted: perm.granted,
      serviceRunning: perm.serviceRunning,
    ));
  }

  Future<void> _onOpenSettings(
    RequestOpenOverlaySettings event,
    Emitter<FloatingCompanionState> emit,
  ) async {
    await bridge.openOverlaySettings();
    emit(state.copyWith(
      statusMessage:
          'Opened Android Display Over Other Apps settings. Grant permission and return to enable the floating companion.',
    ));
  }

  Future<void> _onToggle(
    ToggleFloatingCompanion event,
    Emitter<FloatingCompanionState> emit,
  ) async {
    if (!event.enabled) {
      await bridge.stopOverlay();
      await database?.setAssistivePreference(prefEnabledKey, 'false');
      emit(state.copyWith(
        config: state.config.copyWith(enabled: false),
        serviceRunning: false,
        statusMessage: 'Floating companion stopped and hidden.',
      ));
      return;
    }

    final perm = await bridge.checkOverlayPermission();
    if (!perm.granted) {
      emit(state.copyWith(
        overlayPermissionGranted: false,
        serviceRunning: false,
        statusMessage:
            'Display Over Other Apps permission is required first. Open Android overlay settings to grant it.',
      ));
      return;
    }

    final next = state.config.copyWith(enabled: true);
    final started = await bridge.startOverlay(next);
    await database?.setAssistivePreference(prefEnabledKey, started.toString());
    emit(state.copyWith(
      config: next.copyWith(enabled: started),
      overlayPermissionGranted: true,
      serviceRunning: started,
      statusMessage: started
          ? 'Floating companion active. Camera and microphone actions open Openetra transparently in the foreground.'
          : 'Could not start floating companion overlay.',
    ));
  }

  Future<void> _onUpdateConfig(
    UpdateFloatingCompanionConfig event,
    Emitter<FloatingCompanionState> emit,
  ) async {
    final cfg = event.config;
    await database?.setAssistivePreference(
      prefPrimaryActionKey,
      FloatingWidgetConfig.actionToWireId(cfg.primaryAction),
    );
    await database?.setAssistivePreference(
      prefSecondaryActionKey,
      FloatingWidgetConfig.actionToWireId(cfg.secondaryAction),
    );
    await database?.setAssistivePreference(
      prefLongPressActionKey,
      FloatingWidgetConfig.actionToWireId(cfg.longPressAction),
    );
    await database?.setAssistivePreference(
      prefOrbSizeKey,
      cfg.orbSizeDp.toString(),
    );
    await database?.setAssistivePreference(
      prefReducedMotionKey,
      cfg.reducedMotionOverride.toString(),
    );
    if (state.serviceRunning) {
      await bridge.updateConfig(cfg);
    }
    emit(state.copyWith(
      config: cfg,
      statusMessage: 'Floating companion preferences saved.',
    ));
  }

  Future<void> _onOverlayAction(
    _OverlayActionReceived event,
    Emitter<FloatingCompanionState> emit,
  ) async {
    final actionId = AssistiveActionRouter.parseId(event.event.actionWireId);
    if (actionId == null) return;
    final res = await taskOrchestrator.dispatch(
      actionId,
      sourceTrigger: 'floating_widget',
      fromBackground: event.event.fromBackground,
    );
    if (!res.accepted && res.availability != null) {
      emit(state.copyWith(statusMessage: res.availability!.reason));
    }
  }

  @override
  Future<void> close() async {
    await _actionSub?.cancel();
    return super.close();
  }
}
