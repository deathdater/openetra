import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/assistive/assistive_action.dart';

/// Deterministic lifecycle state machine phases for the Assistive Dial.
enum DialLifecyclePhase {
  initializing,
  ready,
  rootMenu,
  submenu,
  confirmingAction,
  executing,
  listening,
  processing,
  speaking,
  completed,
  paused,
  failed,
  cancelling,
  exitArmed,
  exiting,
}

/// Identifies dedicated Openetra screens reachable from dial options without
/// duplicating configuration UI inside the radial dial.
enum DialScreenRoute {
  settings,
  emergencyAssistance,
  objectMemory,
  shoppingAssistant,
  flashlightSettings,
  gestureAutomation,
  floatingCompanion,
  modelManager,
  classicListHome,
}

enum DialOptionKind {
  submenu,
  action,
  screenRoute,
  returnParent,
  flashlightOn,
  flashlightOff,
  toggleContinuousHazard,
  toggleContinuousScene,
}

/// Bespoke minimalist vector emblem drawn inside the central Assistive Dial
/// focal orb so each option has a distinctive, calm visual identity.
enum DialGlyphKind {
  eyeIris,
  continuousScene,
  scriptLines,
  objectReticle,
  hazardWave,
  voiceHarmonic,
  emergencyBeacon,
  flashlightBeam,
  flashlightOff,
  toolsConstellation,
  repeatArc,
  stopSilence,
  currencyRupee,
  barcodeScan,
  handGesture,
  floatingOrb,
  aiChip,
  listView,
  settingsGear,
}

/// Declarative dial option node containing accessible title, concise spoken
/// description, bespoke vector glyph, action/submenu/screen target, and confirmation policy.
class DialOption extends Equatable {
  const DialOption({
    required this.id,
    required this.title,
    required this.spokenDescription,
    required this.icon,
    required this.glyph,
    required this.kind,
    this.childMenuId,
    this.actionId,
    this.screenRoute,
    this.requiresConfirmation = false,
    this.isEmergency = false,
    this.unavailableMessage,
  });

  final String id;
  final String title;
  final String spokenDescription;
  final IconData icon;
  final DialGlyphKind glyph;
  final DialOptionKind kind;
  final String? childMenuId;
  final AssistiveActionId? actionId;
  final DialScreenRoute? screenRoute;
  final bool requiresConfirmation;
  final bool isEmergency;
  final String? unavailableMessage;

  String spokenAnnouncement({bool detailed = true}) {
    if (!detailed) return title;
    final kindHint = kind == DialOptionKind.submenu ? ' Opens submenu.' : '';
    return '$title. $spokenDescription$kindHint';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        spokenDescription,
        icon,
        glyph,
        kind,
        childMenuId,
        actionId,
        screenRoute,
        requiresConfirmation,
        isEmergency,
        unavailableMessage,
      ];
}

/// Declarative menu level (root or submenu) in the radial dial hierarchy.
class DialMenuNode extends Equatable {
  const DialMenuNode({
    required this.id,
    required this.title,
    required this.spokenIntro,
    required this.options,
    this.parentId,
  });

  final String id;
  final String title;
  final String spokenIntro;
  final List<DialOption> options;
  final String? parentId;

  bool get isRoot => parentId == null;

  @override
  List<Object?> get props => [id, title, spokenIntro, options, parentId];
}

/// Builds the verified Openetra dial hierarchy mapped strictly to existing
/// implemented capabilities. Redundant "Return / Back" submenu items are
/// intentionally omitted because Slide Down and the Back control handle return
/// consistently across every submenu.
class OpenetraDialMenuTree {
  static const String rootId = 'root';

  static Map<String, DialMenuNode> buildDefaultTree() {
    return const {
      rootId: DialMenuNode(
        id: rootId,
        title: 'Main Dial',
        spokenIntro: 'Main menu.',
        options: [
          DialOption(
            id: 'root_describe',
            title: 'Describe Surroundings',
            spokenDescription: 'Understand what is around you.',
            icon: Icons.visibility_outlined,
            glyph: DialGlyphKind.eyeIris,
            kind: DialOptionKind.submenu,
            childMenuId: 'describe_menu',
          ),
          DialOption(
            id: 'root_read',
            title: 'Read Text',
            spokenDescription: 'Read signs, labels, and documents offline.',
            icon: Icons.text_snippet_outlined,
            glyph: DialGlyphKind.scriptLines,
            kind: DialOptionKind.submenu,
            childMenuId: 'read_menu',
          ),
          DialOption(
            id: 'root_find',
            title: 'Find an Object',
            spokenDescription: 'Locate or manage personal registered items.',
            icon: Icons.search_outlined,
            glyph: DialGlyphKind.objectReticle,
            kind: DialOptionKind.submenu,
            childMenuId: 'find_menu',
          ),
          DialOption(
            id: 'root_hazard',
            title: 'Visible Hazards',
            spokenDescription: 'Check camera view for potential hazard cues.',
            icon: Icons.warning_amber_rounded,
            glyph: DialGlyphKind.hazardWave,
            kind: DialOptionKind.submenu,
            childMenuId: 'hazard_menu',
          ),
          DialOption(
            id: 'root_voice',
            title: 'Voice Assistance',
            spokenDescription: 'Speak a command, repeat, or silence speech.',
            icon: Icons.graphic_eq_outlined,
            glyph: DialGlyphKind.voiceHarmonic,
            kind: DialOptionKind.submenu,
            childMenuId: 'voice_menu',
          ),
          DialOption(
            id: 'root_emergency',
            title: 'Emergency Assistance',
            spokenDescription: 'Contact your trusted person with confirmation.',
            icon: Icons.emergency_outlined,
            glyph: DialGlyphKind.emergencyBeacon,
            kind: DialOptionKind.submenu,
            childMenuId: 'emergency_menu',
            isEmergency: true,
          ),
          DialOption(
            id: 'root_flashlight',
            title: 'Flashlight',
            spokenDescription: 'Control manual or automatic illumination.',
            icon: Icons.flashlight_on_outlined,
            glyph: DialGlyphKind.flashlightBeam,
            kind: DialOptionKind.submenu,
            childMenuId: 'flashlight_menu',
          ),
          DialOption(
            id: 'root_more',
            title: 'More Tools',
            spokenDescription: 'Currency, shopping barcode, gestures, and settings.',
            icon: Icons.apps_outlined,
            glyph: DialGlyphKind.toolsConstellation,
            kind: DialOptionKind.submenu,
            childMenuId: 'more_menu',
          ),
        ],
      ),
      'describe_menu': DialMenuNode(
        id: 'describe_menu',
        title: 'Describe Surroundings',
        spokenIntro: 'Scene description options.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'describe_now',
            title: 'Describe Current Scene',
            spokenDescription: 'Captures camera view and describes surroundings naturally.',
            icon: Icons.camera_alt_outlined,
            glyph: DialGlyphKind.eyeIris,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.describeScene,
          ),
          DialOption(
            id: 'describe_continuous',
            title: 'Continuous Scene Mode',
            spokenDescription: 'Continuously analyses and speaks about your surroundings with a break between updates.',
            icon: Icons.autorenew_rounded,
            glyph: DialGlyphKind.continuousScene,
            kind: DialOptionKind.toggleContinuousScene,
          ),
          DialOption(
            id: 'describe_repeat',
            title: 'Repeat Last Description',
            spokenDescription: 'Speaks the last response again.',
            icon: Icons.replay_outlined,
            glyph: DialGlyphKind.repeatArc,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.repeatLast,
          ),
        ],
      ),
      'read_menu': DialMenuNode(
        id: 'read_menu',
        title: 'Read Text',
        spokenIntro: 'Reading options.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'read_now',
            title: 'Read Visible Text',
            spokenDescription: 'Reads signs, labels, or documents in English and Indic scripts.',
            icon: Icons.document_scanner_outlined,
            glyph: DialGlyphKind.scriptLines,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.readText,
          ),
          DialOption(
            id: 'read_repeat',
            title: 'Repeat Recognised Text',
            spokenDescription: 'Repeats the last spoken reading result.',
            icon: Icons.replay_outlined,
            glyph: DialGlyphKind.repeatArc,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.repeatLast,
          ),
        ],
      ),
      'find_menu': DialMenuNode(
        id: 'find_menu',
        title: 'Find an Object',
        spokenIntro: 'Object memory options.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'find_now',
            title: 'Find Registered Object',
            spokenDescription: 'Scans view for your saved personal item.',
            icon: Icons.find_in_page_outlined,
            glyph: DialGlyphKind.objectReticle,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.findRegisteredObject,
          ),
          DialOption(
            id: 'find_manage',
            title: 'Manage Registered Objects',
            spokenDescription: 'Register new items or review saved objects.',
            icon: Icons.inventory_2_outlined,
            glyph: DialGlyphKind.listView,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.objectMemory,
          ),
          DialOption(
            id: 'find_repeat',
            title: 'Repeat Last Result',
            spokenDescription: 'Repeats the last spoken response.',
            icon: Icons.replay_outlined,
            glyph: DialGlyphKind.repeatArc,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.repeatLast,
          ),
        ],
      ),
      'hazard_menu': DialMenuNode(
        id: 'hazard_menu',
        title: 'Visible Hazards',
        spokenIntro: 'Hazard cue options. Openetra is an assistive cue tool and does not guarantee clear paths.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'hazard_scan',
            title: 'Check Visible Hazard Cues',
            spokenDescription: 'Assesses visible obstacles and uncertainty in the current view.',
            icon: Icons.shield_outlined,
            glyph: DialGlyphKind.hazardWave,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.assessHazardCues,
          ),
          DialOption(
            id: 'hazard_continuous',
            title: 'Toggle Continuous Hazard Mode',
            spokenDescription: 'Starts or stops periodic hazard cue scans.',
            icon: Icons.radar_outlined,
            glyph: DialGlyphKind.continuousScene,
            kind: DialOptionKind.toggleContinuousHazard,
          ),
          DialOption(
            id: 'hazard_repeat',
            title: 'Repeat Last Alert',
            spokenDescription: 'Repeats the last spoken notice.',
            icon: Icons.replay_outlined,
            glyph: DialGlyphKind.repeatArc,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.repeatLast,
          ),
        ],
      ),
      'voice_menu': DialMenuNode(
        id: 'voice_menu',
        title: 'Voice Assistance',
        spokenIntro: 'Voice assistance options.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'voice_repeat',
            title: 'Repeat Last Response',
            spokenDescription: 'Speaks the last Openetra announcement again.',
            icon: Icons.replay_outlined,
            glyph: DialGlyphKind.repeatArc,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.repeatLast,
          ),
          DialOption(
            id: 'voice_stop',
            title: 'Stop Speaking',
            spokenDescription: 'Silences current speech and cancels active task.',
            icon: Icons.volume_off_outlined,
            glyph: DialGlyphKind.stopSilence,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.cancelActiveTask,
          ),
          DialOption(
            id: 'voice_settings',
            title: 'Language & Voice Settings',
            spokenDescription: 'Switch between 8 Indian languages and speech speed.',
            icon: Icons.record_voice_over_outlined,
            glyph: DialGlyphKind.voiceHarmonic,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.settings,
          ),
        ],
      ),
      'emergency_menu': DialMenuNode(
        id: 'emergency_menu',
        title: 'Emergency Assistance',
        spokenIntro: 'Emergency assistance options. Confirmation is required before opening the dialer.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'emergency_open',
            title: 'Contact Trusted Person',
            spokenDescription: 'Opens confirmed emergency dialer handoff screen.',
            icon: Icons.phone_forwarded_outlined,
            glyph: DialGlyphKind.emergencyBeacon,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.emergencyAssistance,
            requiresConfirmation: true,
            isEmergency: true,
          ),
        ],
      ),
      'flashlight_menu': DialMenuNode(
        id: 'flashlight_menu',
        title: 'Flashlight',
        spokenIntro: 'Flashlight controls.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'flash_toggle',
            title: 'Toggle Flashlight',
            spokenDescription: 'Switches phone torch on or off.',
            icon: Icons.flashlight_on_outlined,
            glyph: DialGlyphKind.flashlightBeam,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.toggleFlashlight,
          ),
          DialOption(
            id: 'flash_on',
            title: 'Turn Flashlight On',
            spokenDescription: 'Turns the rear flashlight on.',
            icon: Icons.wb_incandescent_outlined,
            glyph: DialGlyphKind.flashlightBeam,
            kind: DialOptionKind.flashlightOn,
          ),
          DialOption(
            id: 'flash_off',
            title: 'Turn Flashlight Off',
            spokenDescription: 'Turns off Openetra owned flashlight.',
            icon: Icons.flashlight_off_outlined,
            glyph: DialGlyphKind.flashlightOff,
            kind: DialOptionKind.flashlightOff,
          ),
          DialOption(
            id: 'flash_settings',
            title: 'Automatic Flashlight Settings',
            spokenDescription: 'Configure opt-in low-light automatic mode.',
            icon: Icons.tune_outlined,
            glyph: DialGlyphKind.settingsGear,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.flashlightSettings,
          ),
        ],
      ),
      'more_menu': DialMenuNode(
        id: 'more_menu',
        title: 'More Tools',
        spokenIntro: 'Additional tools and configuration.',
        parentId: rootId,
        options: [
          DialOption(
            id: 'more_currency',
            title: 'Identify Currency Note',
            spokenDescription: 'Checks Indian rupee denomination with safety notice.',
            icon: Icons.currency_rupee_outlined,
            glyph: DialGlyphKind.currencyRupee,
            kind: DialOptionKind.action,
            actionId: AssistiveActionId.identifyCurrency,
          ),
          DialOption(
            id: 'more_shopping',
            title: 'Shopping & Barcode',
            spokenDescription: 'Scan product barcodes and labels offline.',
            icon: Icons.qr_code_scanner_outlined,
            glyph: DialGlyphKind.barcodeScan,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.shoppingAssistant,
          ),
          DialOption(
            id: 'more_gestures',
            title: 'Custom Hand Gestures',
            spokenDescription: 'Enrol or manage camera hand gestures.',
            icon: Icons.pan_tool_outlined,
            glyph: DialGlyphKind.handGesture,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.gestureAutomation,
          ),
          DialOption(
            id: 'more_floating',
            title: 'Floating Companion',
            spokenDescription: 'Configure optional floating orb above other apps.',
            icon: Icons.assistant_outlined,
            glyph: DialGlyphKind.floatingOrb,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.floatingCompanion,
          ),
          DialOption(
            id: 'more_models',
            title: 'Offline AI Models',
            spokenDescription: 'Inspect bundled model status and checksums.',
            icon: Icons.memory_outlined,
            glyph: DialGlyphKind.aiChip,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.modelManager,
          ),
          DialOption(
            id: 'more_classic',
            title: 'Classic List View',
            spokenDescription: 'Open the full scrollable list of Openetra actions.',
            icon: Icons.view_list_outlined,
            glyph: DialGlyphKind.listView,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.classicListHome,
          ),
          DialOption(
            id: 'more_settings',
            title: 'Settings & Accessibility',
            spokenDescription: 'Voice, haptics, dial sensitivity, and privacy controls.',
            icon: Icons.settings_outlined,
            glyph: DialGlyphKind.settingsGear,
            kind: DialOptionKind.screenRoute,
            screenRoute: DialScreenRoute.settings,
          ),
        ],
      ),
    };
  }
}
