import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/openetra_coordinator.dart';
import '../../../app/theme.dart';
import '../../../core/audio/bloc/audio_bloc.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/resource_management/bloc/device_resource_bloc.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
import '../../emergency/bloc/emergency_bloc.dart';
import '../../emergency/presentation/emergency_assistance_screen.dart';
import '../../dial/bloc/assistive_dial_bloc.dart';
import '../../flashlight/domain/intelligent_flashlight_controller.dart';
import '../../flashlight/presentation/flashlight_settings_screen.dart';
import '../../floating_companion/bloc/floating_companion_bloc.dart';
import '../../floating_companion/presentation/floating_widget_settings_screen.dart';
import '../../gestures/bloc/gesture_automation_bloc.dart';
import '../../gestures/presentation/gesture_automation_screen.dart';
import '../bloc/settings_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.coordinator,
    this.flashlightController,
    this.emergencyBloc,
    this.gestureBloc,
    this.floatingCompanionBloc,
    this.dialBloc,
  });

  final OpenetraCoordinator? coordinator;
  final IntelligentFlashlightController? flashlightController;
  final EmergencyBloc? emergencyBloc;
  final GestureAutomationBloc? gestureBloc;
  final FloatingCompanionBloc? floatingCompanionBloc;
  final AssistiveDialBloc? dialBloc;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _languagesExpanded = false;

  static const List<({String locale, String label})> _languages = [
    (locale: 'en-IN', label: 'English (India)'),
    (locale: 'hi-IN', label: 'Hindi (हिन्दी)'),
    (locale: 'kn-IN', label: 'Kannada (ಕನ್ನಡ)'),
    (locale: 'ta-IN', label: 'Tamil (தமிழ்)'),
    (locale: 'te-IN', label: 'Telugu (తెలుగు)'),
    (locale: 'ml-IN', label: 'Malayalam (മലയാളം)'),
    (locale: 'mr-IN', label: 'Marathi (मराठी)'),
    (locale: 'bn-IN', label: 'Bengali (বাংলা)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Accessibility')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return BlocBuilder<DeviceResourceBloc, DeviceResourceBlocState>(
            builder: (context, resState) {
              final prefs = settingsState.preferences;
              final mode = resState.resourceState.operatingMode;
              final palette = OpenetraTheme.paletteOf(context);
              final activeLangEntry = _languages.firstWhere(
                (l) => l.locale == prefs.preferredLanguage,
                orElse: () => _languages.first,
              );
              final activeOfflineOk =
                  resState.offlineVoiceSupport[activeLangEntry.locale] ?? false;

              return ListView(
                padding: const EdgeInsets.all(OpenetraSpacing.lg),
                children: [
                  if (settingsState.statusMessage != null) ...[
                    SpokenStatusBanner(
                      statusText: settingsState.statusMessage!,
                      isDegraded: false,
                      isBusy: false,
                    ),
                    const SizedBox(height: OpenetraSpacing.lg),
                  ],
                  const OpenetraSectionHeader(
                    title: 'Appearance & Theme',
                    subtitle: 'Choose Deep Aubergine dark mode or Warm White light mode for low vision',
                  ),
                  Wrap(
                    spacing: OpenetraSpacing.sm,
                    runSpacing: OpenetraSpacing.sm,
                    children: [
                      for (final opt in const [
                        (mode: ThemeMode.dark, label: 'Dark Aubergine', icon: Icons.dark_mode_outlined),
                        (mode: ThemeMode.light, label: 'Warm White Light', icon: Icons.light_mode_outlined),
                        (mode: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_outlined),
                      ])
                        ChoiceChip(
                          selected: settingsState.themeMode == opt.mode,
                          label: Text(opt.label),
                          avatar: Icon(opt.icon, size: 18),
                          selectedColor: palette.secondary,
                          labelStyle: TextStyle(
                            color: settingsState.themeMode == opt.mode
                                ? palette.onAccent
                                : palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => context
                              .read<SettingsBloc>()
                              .add(UpdateThemeMode(opt.mode)),
                        ),
                    ],
                  ),
                  const SizedBox(height: OpenetraSpacing.xl),
                  const OpenetraSectionHeader(
                    title: 'Voice & Language',
                    subtitle: 'Active offline speech language and speed',
                  ),
                  AccessibleActionTile(
                    title: 'Language: ${activeLangEntry.label}',
                    subtitle: activeOfflineOk
                        ? 'Offline voice verified • Tap to ${_languagesExpanded ? "hide" : "change"} language'
                        : 'Offline voice unverified • Tap to ${_languagesExpanded ? "hide" : "change"} language',
                    semanticHint: 'Double tap to expand or collapse all 8 supported languages',
                    icon: _languagesExpanded
                        ? Icons.expand_less_rounded
                        : Icons.translate_outlined,
                    filledAccent: true,
                    onPressed: () => setState(
                      () => _languagesExpanded = !_languagesExpanded,
                    ),
                  ),
                  if (_languagesExpanded) ...[
                    const SizedBox(height: OpenetraSpacing.sm),
                    ..._languages.map((lang) {
                      final selected = prefs.preferredLanguage == lang.locale;
                      final offlineOk =
                          resState.offlineVoiceSupport[lang.locale] ?? false;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: OpenetraSpacing.sm),
                        child: AccessibleActionTile(
                          title: '${lang.label}${selected ? " (Active)" : ""}',
                          subtitle: offlineOk
                              ? 'Offline voice verified on device'
                              : 'Offline voice unverified — check device TTS settings',
                          semanticHint: 'Double tap to select ${lang.label}',
                          icon: selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          minHeight: 66,
                          filledAccent: selected,
                          onPressed: () {
                            context
                                .read<SettingsBloc>()
                                .add(UpdatePreferredLanguage(lang.locale));
                            context
                                .read<AudioBloc>()
                                .add(UpdateSpeechConfig(locale: lang.locale));
                            setState(() => _languagesExpanded = false);
                          },
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: OpenetraSpacing.lg),
                  Text(
                    'Speech Speed (${prefs.speechRate.toStringAsFixed(2)}x)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: prefs.speechRate,
                    min: 0.35,
                    max: 0.90,
                    divisions: 11,
                    label: '${prefs.speechRate.toStringAsFixed(2)}x',
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(UpdateSpeechRate(value));
                      context
                          .read<AudioBloc>()
                          .add(UpdateSpeechConfig(speechRate: value));
                    },
                  ),
                  const SizedBox(height: OpenetraSpacing.lg),
                  const OpenetraSectionHeader(
                    title: 'Power & Operating Mode',
                  ),
                  ...OperatingMode.values.map((m) {
                    final active = mode == m;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AccessibleActionTile(
                        title: '${m.name.toUpperCase()}${active ? " (Active)" : ""}',
                        subtitle:
                            'Recommended threads: ${m == OperatingMode.eco ? 2 : "Auto"}',
                        semanticHint: 'Switch operating mode to ${m.name}',
                        icon: active ? Icons.bolt : Icons.tune,
                        filledAccent: active,
                        minHeight: 66,
                        onPressed: () {
                          context
                              .read<DeviceResourceBloc>()
                              .add(ChangeOperatingMode(m));
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  if (widget.coordinator != null) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        'Continuous Scene Understanding',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AccessibleActionTile(
                      title: widget.coordinator!.isContinuousSceneActive
                          ? 'Continuous Scene Mode: Active (Tap to Stop)'
                          : 'Continuous Scene Mode: Off (Tap to Start)',
                      subtitle:
                          'Continuously describes surroundings after each statement finishes speaking',
                      semanticHint:
                          'Double tap to toggle continuous scene understanding',
                      icon: Icons.autorenew_rounded,
                      filledAccent: widget.coordinator!.isContinuousSceneActive,
                      onPressed: () async {
                        await widget.coordinator!
                            .toggleContinuousSceneUnderstanding();
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Break Between Scene Descriptions: ${widget.coordinator!.continuousSceneBreakSeconds} seconds',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: widget.coordinator!.continuousSceneBreakSeconds
                          .toDouble(),
                      min: 3,
                      max: 30,
                      divisions: 27,
                      label:
                          '${widget.coordinator!.continuousSceneBreakSeconds}s',
                      onChanged: (v) async {
                        await widget.coordinator!
                            .setContinuousSceneBreakSeconds(v.round());
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.emergencyBloc != null) ...[
                    AccessibleActionTile(
                      title: 'Emergency Assistance & Trusted Contacts',
                      subtitle: 'Configure AES-encrypted trusted contacts & test flow',
                      semanticHint: 'Double tap to configure emergency assistance',
                      icon: Icons.emergency_outlined,
                      accentBorderColor: palette.warning,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: widget.emergencyBloc!,
                              child: EmergencyAssistanceScreen(
                                locale: prefs.preferredLanguage,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.flashlightController != null) ...[
                    AccessibleActionTile(
                      title: 'Intelligent Flashlight Controls',
                      subtitle: 'Manual torch toggle and opt-in low-light auto mode',
                      semanticHint: 'Double tap to open flashlight settings',
                      icon: Icons.flashlight_on_outlined,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FlashlightSettingsScreen(
                              controller: widget.flashlightController!,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.gestureBloc != null) ...[
                    AccessibleActionTile(
                      title: 'Custom Hand Gestures',
                      subtitle: 'Enrol personal gestures to trigger Openetra actions offline',
                      semanticHint: 'Double tap to configure custom hand gestures',
                      icon: Icons.pan_tool_outlined,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: widget.gestureBloc!,
                              child: const GestureAutomationScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.floatingCompanionBloc != null) ...[
                    AccessibleActionTile(
                      title: 'Floating Assistive Companion',
                      subtitle: 'Optional overlay orb with calm task-state glow above other apps',
                      semanticHint: 'Double tap to configure floating assistive companion',
                      icon: Icons.assistant_outlined,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: widget.floatingCompanionBloc!,
                              child: const FloatingWidgetSettingsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.dialBloc != null) ...[
                    BlocBuilder<AssistiveDialBloc, AssistiveDialState>(
                      bloc: widget.dialBloc,
                      builder: (context, dialState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Dial Interaction, Haptics & Motion',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AccessibleActionTile(
                              title: dialState.hapticsEnabled
                                  ? 'Dial Haptics: Enabled'
                                  : 'Dial Haptics: Disabled',
                              subtitle:
                                  'Distinctive vibration patterns for focus, selection, back, and alerts',
                              semanticHint: 'Double tap to toggle dial haptic feedback',
                              icon: Icons.vibration_outlined,
                              filledAccent: dialState.hapticsEnabled,
                              onPressed: () => widget.dialBloc!.add(
                                DialUpdatePreferences(
                                  hapticsEnabled: !dialState.hapticsEnabled,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AccessibleActionTile(
                              title: dialState.detailedAnnouncements
                                  ? 'Dial Voice Verbosity: Detailed'
                                  : 'Dial Voice Verbosity: Concise',
                              subtitle:
                                  'Detailed speaks option name and purpose; Concise speaks option title only',
                              semanticHint: 'Double tap to switch dial voice verbosity',
                              icon: Icons.record_voice_over_outlined,
                              filledAccent: dialState.detailedAnnouncements,
                              onPressed: () => widget.dialBloc!.add(
                                DialUpdatePreferences(
                                  detailedAnnouncements:
                                      !dialState.detailedAnnouncements,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AccessibleActionTile(
                              title: dialState.reducedMotion
                                  ? 'Dial Reduced Motion: Enabled'
                                  : 'Dial Reduced Motion: Follow System',
                              subtitle:
                                  'Disables glow pulse and waveform animations during operations',
                              semanticHint: 'Double tap to toggle dial reduced motion',
                              icon: Icons.motion_photos_off_outlined,
                              filledAccent: dialState.reducedMotion,
                              onPressed: () => widget.dialBloc!.add(
                                DialUpdatePreferences(
                                  reducedMotion: !dialState.reducedMotion,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ],
                  const OpenetraSectionHeader(
                    title: 'Privacy & Data',
                  ),
                  AccessibleActionTile(
                    title: 'Delete All Personal Data',
                    subtitle:
                        'Wipes saved objects, scanned documents, history, and safety logs',
                    semanticHint:
                        'Double tap to open confirmation dialog before deleting personal data',
                    icon: Icons.delete_forever,
                    accentBorderColor: palette.error,
                    onPressed: () async {
                      final settingsBloc = context.read<SettingsBloc>();
                      final confirmed = await showOpenetraConfirmDialog(
                        context,
                        title: 'Delete All Personal Data?',
                        message:
                            'This permanently removes saved personal items, scanned documents, conversation history, and safety logs. Built-in product staples remain offline.',
                        confirmLabel: 'Permanently Delete',
                        isDestructive: true,
                      );
                      if (confirmed) {
                        settingsBloc.add(const DeleteAllUserDataRequested());
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
