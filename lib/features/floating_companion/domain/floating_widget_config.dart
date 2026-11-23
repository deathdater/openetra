import 'package:equatable/equatable.dart';
import '../../../core/assistive/assistive_action.dart';

class FloatingWidgetConfig extends Equatable {
  const FloatingWidgetConfig({
    this.enabled = false,
    this.primaryAction = AssistiveActionId.describeScene,
    this.secondaryAction = AssistiveActionId.cancelActiveTask,
    this.longPressAction = AssistiveActionId.startEmergencyAssistance,
    this.orbSizeDp = 64,
    this.reducedMotionOverride = false,
    this.highContrastRing = true,
  });

  final bool enabled;
  final AssistiveActionId primaryAction;
  final AssistiveActionId secondaryAction;
  final AssistiveActionId longPressAction;
  final int orbSizeDp;
  final bool reducedMotionOverride;
  final bool highContrastRing;

  FloatingWidgetConfig copyWith({
    bool? enabled,
    AssistiveActionId? primaryAction,
    AssistiveActionId? secondaryAction,
    AssistiveActionId? longPressAction,
    int? orbSizeDp,
    bool? reducedMotionOverride,
    bool? highContrastRing,
  }) {
    return FloatingWidgetConfig(
      enabled: enabled ?? this.enabled,
      primaryAction: primaryAction ?? this.primaryAction,
      secondaryAction: secondaryAction ?? this.secondaryAction,
      longPressAction: longPressAction ?? this.longPressAction,
      orbSizeDp: (orbSizeDp ?? this.orbSizeDp).clamp(48, 96),
      reducedMotionOverride:
          reducedMotionOverride ?? this.reducedMotionOverride,
      highContrastRing: highContrastRing ?? this.highContrastRing,
    );
  }

  static String actionToWireId(AssistiveActionId id) {
    switch (id) {
      case AssistiveActionId.describeScene:
        return 'describe_scene';
      case AssistiveActionId.readText:
        return 'read_text';
      case AssistiveActionId.findRegisteredObject:
        return 'find_registered_object';
      case AssistiveActionId.assessHazardCues:
        return 'assess_hazard_cues';
      case AssistiveActionId.identifyCurrency:
        return 'identify_currency';
      case AssistiveActionId.scanProduct:
        return 'scan_product';
      case AssistiveActionId.startEmergencyAssistance:
        return 'start_emergency_assistance';
      case AssistiveActionId.toggleFlashlight:
        return 'toggle_flashlight';
      case AssistiveActionId.startOrResumeSupportedTask:
        return 'start_or_resume_supported_task';
      case AssistiveActionId.cancelActiveTask:
        return 'cancel_active_task';
      case AssistiveActionId.repeatLast:
        return 'repeat_last';
    }
  }

  Map<String, dynamic> toNativeMap() => {
        'primaryActionId': actionToWireId(primaryAction),
        'secondaryActionId': actionToWireId(secondaryAction),
        'longPressActionId': actionToWireId(longPressAction),
        'orbSizeDp': orbSizeDp,
        'reducedMotion': reducedMotionOverride,
        'highContrastRing': highContrastRing,
      };

  @override
  List<Object?> get props => [
        enabled,
        primaryAction,
        secondaryAction,
        longPressAction,
        orbSizeDp,
        reducedMotionOverride,
        highContrastRing,
      ];
}
