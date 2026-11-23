import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/assistive/assistive_action.dart';
import '../../../core/assistive/audio_arbitrator.dart';
import '../../../core/assistive/task_orchestrator.dart';
import '../../../core/haptics/haptic_feedback_manager.dart';
import '../models/dial_menu_node.dart';

abstract class AssistiveDialEvent extends Equatable {
  const AssistiveDialEvent();

  @override
  List<Object?> get props => [];
}

class DialInitialized extends AssistiveDialEvent {
  const DialInitialized({this.locale = 'en-IN'});
  final String locale;

  @override
  List<Object?> get props => [locale];
}

class DialBrowseNext extends AssistiveDialEvent {
  const DialBrowseNext();
}

class DialBrowsePrevious extends AssistiveDialEvent {
  const DialBrowsePrevious();
}

class DialFocusOptionAt extends AssistiveDialEvent {
  const DialFocusOptionAt(this.index);
  final int index;

  @override
  List<Object?> get props => [index];
}

class DialSlideUpRequested extends AssistiveDialEvent {
  const DialSlideUpRequested();
}

class DialSlideDownRequested extends AssistiveDialEvent {
  const DialSlideDownRequested();
}

class DialRepeatCurrentAnnouncement extends AssistiveDialEvent {
  const DialRepeatCurrentAnnouncement();
}

class DialCancelActiveOperation extends AssistiveDialEvent {
  const DialCancelActiveOperation();
}

class DialNavigationRouteHandled extends AssistiveDialEvent {
  const DialNavigationRouteHandled();
}

class DialUpdatePreferences extends AssistiveDialEvent {
  const DialUpdatePreferences({
    this.locale,
    this.detailedAnnouncements,
    this.hapticsEnabled,
    this.reducedMotion,
  });

  final String? locale;
  final bool? detailedAnnouncements;
  final bool? hapticsEnabled;
  final bool? reducedMotion;

  @override
  List<Object?> get props =>
      [locale, detailedAnnouncements, hapticsEnabled, reducedMotion];
}

class _DialTaskSnapshotUpdated extends AssistiveDialEvent {
  const _DialTaskSnapshotUpdated(this.snapshot);
  final AssistiveTaskSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

class DialMenuStackFrame extends Equatable {
  const DialMenuStackFrame({required this.menuId, required this.focusedIndex});
  final String menuId;
  final int focusedIndex;

  @override
  List<Object?> get props => [menuId, focusedIndex];
}

class AssistiveDialState extends Equatable {
  const AssistiveDialState({
    required this.menuId,
    required this.focusedIndex,
    required this.phase,
    this.menuStack = const [],
    this.activeOperationTitle,
    this.statusAnnouncement = 'Openetra ready.',
    this.pendingScreenRoute,
    this.pendingConfirmationOptionId,
    this.locale = 'en-IN',
    this.detailedAnnouncements = true,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
  });

  final String menuId;
  final int focusedIndex;
  final DialLifecyclePhase phase;
  final List<DialMenuStackFrame> menuStack;
  final String? activeOperationTitle;
  final String statusAnnouncement;
  final DialScreenRoute? pendingScreenRoute;
  final String? pendingConfirmationOptionId;
  final String locale;
  final bool detailedAnnouncements;
  final bool hapticsEnabled;
  final bool reducedMotion;

  bool get isBusy =>
      phase == DialLifecyclePhase.executing ||
      phase == DialLifecyclePhase.listening ||
      phase == DialLifecyclePhase.processing ||
      phase == DialLifecyclePhase.speaking ||
      phase == DialLifecyclePhase.cancelling;

  AssistiveDialState copyWith({
    String? menuId,
    int? focusedIndex,
    DialLifecyclePhase? phase,
    List<DialMenuStackFrame>? menuStack,
    String? activeOperationTitle,
    bool clearActiveOperation = false,
    String? statusAnnouncement,
    DialScreenRoute? pendingScreenRoute,
    bool clearPendingRoute = false,
    String? pendingConfirmationOptionId,
    bool clearPendingConfirmation = false,
    String? locale,
    bool? detailedAnnouncements,
    bool? hapticsEnabled,
    bool? reducedMotion,
  }) {
    return AssistiveDialState(
      menuId: menuId ?? this.menuId,
      focusedIndex: focusedIndex ?? this.focusedIndex,
      phase: phase ?? this.phase,
      menuStack: menuStack ?? this.menuStack,
      activeOperationTitle: clearActiveOperation
          ? null
          : (activeOperationTitle ?? this.activeOperationTitle),
      statusAnnouncement: statusAnnouncement ?? this.statusAnnouncement,
      pendingScreenRoute: clearPendingRoute
          ? null
          : (pendingScreenRoute ?? this.pendingScreenRoute),
      pendingConfirmationOptionId: clearPendingConfirmation
          ? null
          : (pendingConfirmationOptionId ?? this.pendingConfirmationOptionId),
      locale: locale ?? this.locale,
      detailedAnnouncements:
          detailedAnnouncements ?? this.detailedAnnouncements,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }

  @override
  List<Object?> get props => [
        menuId,
        focusedIndex,
        phase,
        menuStack,
        activeOperationTitle,
        statusAnnouncement,
        pendingScreenRoute,
        pendingConfirmationOptionId,
        locale,
        detailedAnnouncements,
        hapticsEnabled,
        reducedMotion,
      ];
}

/// Deterministic state machine for Openetra's Intelligent Assistive Dial.
/// Single source of truth for voice, haptics, and radial UI; routes all actions
/// through [TaskOrchestrator] and never duplicates domain/AI logic.
class AssistiveDialBloc extends Bloc<AssistiveDialEvent, AssistiveDialState> {
  AssistiveDialBloc({
    required this.taskOrchestrator,
    required this.audioArbitrator,
    required this.hapticManager,
    Map<String, DialMenuNode>? menuTree,
    this.onFlashlightExplicit,
    this.onToggleContinuousHazard,
    this.onToggleContinuousScene,
    DateTime Function()? clock,
  })  : _menuTree = menuTree ?? OpenetraDialMenuTree.buildDefaultTree(),
        _clock = clock ?? DateTime.now,
        super(const AssistiveDialState(
          menuId: OpenetraDialMenuTree.rootId,
          focusedIndex: 0,
          phase: DialLifecyclePhase.initializing,
        )) {
    on<DialInitialized>(_onInit);
    on<DialBrowseNext>(_onBrowseNext);
    on<DialBrowsePrevious>(_onBrowsePrevious);
    on<DialFocusOptionAt>(_onFocusAt);
    on<DialSlideUpRequested>(_onSlideUp);
    on<DialSlideDownRequested>(_onSlideDown);
    on<DialRepeatCurrentAnnouncement>(_onRepeat);
    on<DialCancelActiveOperation>(_onCancelActive);
    on<DialNavigationRouteHandled>(_onRouteHandled);
    on<DialUpdatePreferences>(_onUpdatePrefs);
    on<_DialTaskSnapshotUpdated>(_onTaskSnapshot);

    _taskSub = taskOrchestrator.snapshots.listen((snap) {
      if (!isClosed) add(_DialTaskSnapshotUpdated(snap));
    });
  }

  final TaskOrchestrator taskOrchestrator;
  final AudioArbitrator audioArbitrator;
  final HapticFeedbackManager hapticManager;
  final Map<String, DialMenuNode> _menuTree;
  final Future<void> Function(bool enabled)? onFlashlightExplicit;
  final Future<void> Function()? onToggleContinuousHazard;
  final Future<void> Function()? onToggleContinuousScene;
  final DateTime Function() _clock;

  StreamSubscription<AssistiveTaskSnapshot>? _taskSub;
  DateTime? _exitArmedAt;

  DialMenuNode get currentMenu =>
      _menuTree[state.menuId] ?? _menuTree[OpenetraDialMenuTree.rootId]!;

  DialOption get focusedOption {
    final opts = currentMenu.options;
    final idx = state.focusedIndex.clamp(0, opts.length - 1);
    return opts[idx];
  }

  Future<void> _onInit(
    DialInitialized event,
    Emitter<AssistiveDialState> emit,
  ) async {
    final root = _menuTree[OpenetraDialMenuTree.rootId]!;
    final first = root.options.first;
    final intro =
        'Openetra ready. ${root.spokenIntro} ${first.spokenAnnouncement(detailed: state.detailedAnnouncements)}';
    audioArbitrator.announceSelection(spokenText: intro, locale: event.locale);
    emit(state.copyWith(
      menuId: OpenetraDialMenuTree.rootId,
      focusedIndex: 0,
      phase: DialLifecyclePhase.rootMenu,
      locale: event.locale,
      statusAnnouncement: intro,
      clearPendingConfirmation: true,
      clearPendingRoute: true,
    ));
  }

  Future<void> _onBrowseNext(
    DialBrowseNext event,
    Emitter<AssistiveDialState> emit,
  ) async {
    if (state.isBusy) return;
    final len = currentMenu.options.length;
    final nextIdx = (state.focusedIndex + 1) % len;
    await _focusIndex(nextIdx, emit);
  }

  Future<void> _onBrowsePrevious(
    DialBrowsePrevious event,
    Emitter<AssistiveDialState> emit,
  ) async {
    if (state.isBusy) return;
    final len = currentMenu.options.length;
    final prevIdx = (state.focusedIndex - 1 + len) % len;
    await _focusIndex(prevIdx, emit);
  }

  Future<void> _onFocusAt(
    DialFocusOptionAt event,
    Emitter<AssistiveDialState> emit,
  ) async {
    if (state.isBusy) return;
    final len = currentMenu.options.length;
    if (event.index < 0 || event.index >= len) return;
    await _focusIndex(event.index, emit);
  }

  Future<void> _focusIndex(int idx, Emitter<AssistiveDialState> emit) async {
    _exitArmedAt = null;
    final option = currentMenu.options[idx];
    final spoken =
        option.spokenAnnouncement(detailed: state.detailedAnnouncements);
    unawaited(hapticManager.onFocusChanged());
    audioArbitrator.announceSelection(spokenText: spoken, locale: state.locale);
    emit(state.copyWith(
      focusedIndex: idx,
      phase: currentMenu.isRoot
          ? DialLifecyclePhase.rootMenu
          : DialLifecyclePhase.submenu,
      statusAnnouncement: spoken,
      clearPendingConfirmation: true,
    ));
  }

  Future<void> _onSlideUp(
    DialSlideUpRequested event,
    Emitter<AssistiveDialState> emit,
  ) async {
    if (state.isBusy) return;
    _exitArmedAt = null;
    final option = focusedOption;

    // Sensitive option confirmation gate (e.g., Emergency Assistance).
    if (option.requiresConfirmation &&
        state.pendingConfirmationOptionId != option.id) {
      if (option.isEmergency) {
        unawaited(hapticManager.onEmergencyInitiated());
      } else {
        unawaited(hapticManager.onOptionSelected());
      }
      final prompt =
          'Confirm ${option.title}. Slide up again to confirm, or slide down to cancel.';
      audioArbitrator.announceSelection(
        spokenText: prompt,
        locale: state.locale,
      );
      emit(state.copyWith(
        phase: DialLifecyclePhase.confirmingAction,
        pendingConfirmationOptionId: option.id,
        statusAnnouncement: prompt,
      ));
      return;
    }

    switch (option.kind) {
      case DialOptionKind.submenu:
        final childId = option.childMenuId;
        final child = childId != null ? _menuTree[childId] : null;
        if (child == null || child.options.isEmpty) {
          await _emitUnavailable(
            emit,
            option.unavailableMessage ?? '${option.title} is unavailable.',
          );
          return;
        }
        unawaited(hapticManager.onSubmenuEntered());
        final nextStack = [
          ...state.menuStack,
          DialMenuStackFrame(
            menuId: state.menuId,
            focusedIndex: state.focusedIndex,
          ),
        ];
        final first = child.options.first;
        final spoken =
            '${child.spokenIntro} ${first.spokenAnnouncement(detailed: state.detailedAnnouncements)}';
        audioArbitrator.announceSelection(
          spokenText: spoken,
          locale: state.locale,
        );
        emit(state.copyWith(
          menuId: child.id,
          focusedIndex: 0,
          phase: DialLifecyclePhase.submenu,
          menuStack: nextStack,
          statusAnnouncement: spoken,
          clearPendingConfirmation: true,
        ));

      case DialOptionKind.returnParent:
        await _navigateBackToParent(emit);

      case DialOptionKind.screenRoute:
        final route = option.screenRoute;
        if (route == null) {
          await _emitUnavailable(emit, '${option.title} is unavailable.');
          return;
        }
        unawaited(hapticManager.onOptionSelected());
        final spoken = 'Opening ${option.title}.';
        audioArbitrator.announceSelection(
          spokenText: spoken,
          locale: state.locale,
        );
        emit(state.copyWith(
          phase: currentMenu.isRoot
              ? DialLifecyclePhase.rootMenu
              : DialLifecyclePhase.submenu,
          pendingScreenRoute: route,
          statusAnnouncement: spoken,
          clearPendingConfirmation: true,
        ));

      case DialOptionKind.flashlightOn:
        await hapticManager.onOptionSelected();
        await onFlashlightExplicit?.call(true);
        emit(state.copyWith(
          statusAnnouncement: 'Flashlight turned on.',
          clearPendingConfirmation: true,
        ));

      case DialOptionKind.flashlightOff:
        await hapticManager.onOptionSelected();
        await onFlashlightExplicit?.call(false);
        emit(state.copyWith(
          statusAnnouncement: 'Flashlight turned off.',
          clearPendingConfirmation: true,
        ));

      case DialOptionKind.toggleContinuousHazard:
        unawaited(hapticManager.onOptionSelected());
        await onToggleContinuousHazard?.call();
        emit(state.copyWith(
          statusAnnouncement: 'Toggled continuous hazard cue mode.',
          clearPendingConfirmation: true,
        ));

      case DialOptionKind.toggleContinuousScene:
        unawaited(hapticManager.onOptionSelected());
        await onToggleContinuousScene?.call();
        emit(state.copyWith(
          statusAnnouncement: 'Toggled continuous scene understanding mode.',
          clearPendingConfirmation: true,
        ));

      case DialOptionKind.action:
        final actionId = option.actionId;
        if (actionId == null) {
          await _emitUnavailable(emit, '${option.title} is unavailable.');
          return;
        }
        unawaited(hapticManager.onOperationStarted());
        final startMsg = 'Starting ${option.title}.';
        emit(state.copyWith(
          phase: DialLifecyclePhase.executing,
          activeOperationTitle: option.title,
          statusAnnouncement: startMsg,
          clearPendingConfirmation: true,
        ));
        final res = await taskOrchestrator.dispatch(
          actionId,
          sourceTrigger: 'assistive_dial',
          fromBackground: false,
        );
        if (!res.accepted) {
          final reason = res.availability?.reason ??
              res.finalSnapshot.errorMessage ??
              '${option.title} is currently unavailable.';
          await _emitUnavailable(emit, reason);
        } else {
          await hapticManager.onOperationCompleted();
          emit(state.copyWith(
            phase: DialLifecyclePhase.completed,
            clearActiveOperation: true,
            statusAnnouncement: '${option.title} completed.',
          ));
        }
    }
  }

  Future<void> _onSlideDown(
    DialSlideDownRequested event,
    Emitter<AssistiveDialState> emit,
  ) async {
    // 1. Cancel pending confirmation safely.
    if (state.phase == DialLifecyclePhase.confirmingAction) {
      await hapticManager.onNavigateBack();
      final msg = 'Confirmation cancelled. ${focusedOption.title}.';
      audioArbitrator.announceSelection(spokenText: msg, locale: state.locale);
      emit(state.copyWith(
        phase: currentMenu.isRoot
            ? DialLifecyclePhase.rootMenu
            : DialLifecyclePhase.submenu,
        clearPendingConfirmation: true,
        statusAnnouncement: msg,
      ));
      return;
    }

    // 2. During an active operation, cancel cleanly rather than silently exiting.
    if (state.isBusy) {
      await _cancelRunningOperation(emit);
      return;
    }

    // 3. Inside a submenu -> return to parent menu & restore parent focus.
    if (state.menuStack.isNotEmpty) {
      await _navigateBackToParent(emit);
      return;
    }

    // 4. At root menu -> require deliberate two-step downward confirmation to exit.
    final now = _clock();
    if (_exitArmedAt != null &&
        now.difference(_exitArmedAt!) <= const Duration(seconds: 5)) {
      _exitArmedAt = null;
      await hapticManager.onNavigateBack();
      const msg = 'Closing the dial.';
      audioArbitrator.announceSelection(spokenText: msg, locale: state.locale);
      emit(state.copyWith(
        phase: DialLifecyclePhase.exiting,
        statusAnnouncement: msg,
      ));
      return;
    }

    _exitArmedAt = now;
    await hapticManager.onRootExitRequested();
    const armMsg = 'At main menu. Slide down again within 5 seconds to exit.';
    audioArbitrator.announceSelection(spokenText: armMsg, locale: state.locale);
    emit(state.copyWith(
      phase: DialLifecyclePhase.exitArmed,
      statusAnnouncement: armMsg,
    ));
  }

  Future<void> _navigateBackToParent(Emitter<AssistiveDialState> emit) async {
    if (state.menuStack.isEmpty) return;
    final nextStack = List<DialMenuStackFrame>.from(state.menuStack);
    final parent = nextStack.removeLast();
    final parentNode =
        _menuTree[parent.menuId] ?? _menuTree[OpenetraDialMenuTree.rootId]!;
    final restoredOpt =
        parentNode.options[parent.focusedIndex.clamp(0, parentNode.options.length - 1)];
    unawaited(hapticManager.onNavigateBack());
    final spoken =
        'Back to ${parentNode.title}. ${restoredOpt.spokenAnnouncement(detailed: state.detailedAnnouncements)}';
    audioArbitrator.announceSelection(spokenText: spoken, locale: state.locale);
    emit(state.copyWith(
      menuId: parentNode.id,
      focusedIndex: parent.focusedIndex,
      phase: parentNode.isRoot
          ? DialLifecyclePhase.rootMenu
          : DialLifecyclePhase.submenu,
      menuStack: nextStack,
      statusAnnouncement: spoken,
      clearPendingConfirmation: true,
    ));
  }

  Future<void> _cancelRunningOperation(Emitter<AssistiveDialState> emit) async {
    emit(state.copyWith(phase: DialLifecyclePhase.cancelling));
    await taskOrchestrator.cancelCurrentTask(reason: 'Cancelled from dial');
    await hapticManager.onNavigateBack();
    const msg = 'Operation cancelled.';
    audioArbitrator.announceSelection(spokenText: msg, locale: state.locale);
    emit(state.copyWith(
      phase: currentMenu.isRoot
          ? DialLifecyclePhase.rootMenu
          : DialLifecyclePhase.submenu,
      clearActiveOperation: true,
      statusAnnouncement: msg,
    ));
  }

  Future<void> _emitUnavailable(
    Emitter<AssistiveDialState> emit,
    String reason,
  ) async {
    await hapticManager.onOperationFailed();
    audioArbitrator.announceSelection(spokenText: reason, locale: state.locale);
    emit(state.copyWith(
      phase: DialLifecyclePhase.failed,
      clearActiveOperation: true,
      clearPendingConfirmation: true,
      statusAnnouncement: reason,
    ));
  }

  Future<void> _onRepeat(
    DialRepeatCurrentAnnouncement event,
    Emitter<AssistiveDialState> emit,
  ) async {
    final text = state.isBusy
        ? (state.activeOperationTitle != null
            ? '${state.activeOperationTitle} in progress.'
            : state.statusAnnouncement)
        : focusedOption.spokenAnnouncement(
            detailed: state.detailedAnnouncements,
          );
    audioArbitrator.announceSelection(spokenText: text, locale: state.locale);
  }

  Future<void> _onCancelActive(
    DialCancelActiveOperation event,
    Emitter<AssistiveDialState> emit,
  ) async {
    if (state.isBusy) {
      await _cancelRunningOperation(emit);
    }
  }

  void _onRouteHandled(
    DialNavigationRouteHandled event,
    Emitter<AssistiveDialState> emit,
  ) {
    emit(state.copyWith(clearPendingRoute: true));
  }

  void _onUpdatePrefs(
    DialUpdatePreferences event,
    Emitter<AssistiveDialState> emit,
  ) {
    if (event.hapticsEnabled != null) {
      hapticManager.setEnabled(event.hapticsEnabled!);
    }
    emit(state.copyWith(
      locale: event.locale,
      detailedAnnouncements: event.detailedAnnouncements,
      hapticsEnabled: event.hapticsEnabled,
      reducedMotion: event.reducedMotion,
    ));
  }

  void _onTaskSnapshot(
    _DialTaskSnapshotUpdated event,
    Emitter<AssistiveDialState> emit,
  ) {
    final p = event.snapshot.phase;
    switch (p) {
      case AssistiveTaskPhase.listening:
        emit(state.copyWith(phase: DialLifecyclePhase.listening));
      case AssistiveTaskPhase.processing:
      case AssistiveTaskPhase.aiInference:
        emit(state.copyWith(phase: DialLifecyclePhase.processing));
      case AssistiveTaskPhase.speaking:
        emit(state.copyWith(phase: DialLifecyclePhase.speaking));
      case AssistiveTaskPhase.paused:
        emit(state.copyWith(
          phase: DialLifecyclePhase.paused,
          clearActiveOperation: true,
        ));
      case AssistiveTaskPhase.idle:
      case AssistiveTaskPhase.activated:
      case AssistiveTaskPhase.completed:
      case AssistiveTaskPhase.failed:
      case AssistiveTaskPhase.emergencyFlow:
        break;
    }
  }

  @override
  Future<void> close() async {
    await _taskSub?.cancel();
    return super.close();
  }
}
