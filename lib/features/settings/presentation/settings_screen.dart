import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/audio/bloc/audio_bloc.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/resource_management/bloc/device_resource_bloc.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.flashlightController,
    this.emergencyBloc,
    this.gestureBloc,
    this.floatingCompanionBloc,
    this.dialBloc,
  });

  final IntelligentFlashlightController? flashlightController;
  final EmergencyBloc? emergencyBloc;
  final GestureAutomationBloc? gestureBloc;
  final FloatingCompanionBloc? floatingCompanionBloc;
  final AssistiveDialBloc? dialBloc;

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

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (settingsState.statusMessage != null) ...[
                    SpokenStatusBanner(
                      statusText: settingsState.statusMessage!,
                      isDegraded: false,
                      isBusy: false,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      'Speech Language & Offline Voice Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._languages.map((lang) {
                    final selected = prefs.preferredLanguage == lang.locale;
                    final offlineOk =
                        resState.offlineVoiceSupport[lang.locale] ?? false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AccessibleActionTile(
                        title: '${lang.label}${selected ? " (Active)" : ""}',
                        subtitle: offlineOk
                            ? 'Offline voice verified on device'
                            : 'Offline voice unverified — check device TTS settings',
                        semanticHint: 'Double tap to select ${lang.label}',
                        icon: selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        filledAccent: selected,
                        onPressed: () {
                          context
                              .read<SettingsBloc>()
                              .add(UpdatePreferredLanguage(lang.locale));
                          context
                              .read<AudioBloc>()
                              .add(UpdateSpeechConfig(locale: lang.locale));
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Speech Speed (${prefs.speechRate.toStringAsFixed(2)})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Power & Operating Mode',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  if (emergencyBloc != null) ...[
                    AccessibleActionTile(
                      title: 'Emergency Assistance & Trusted Contacts',
                      subtitle: 'Configure AES-encrypted trusted contacts & test flow',
                      semanticHint: 'Double tap to configure emergency assistance',
                      icon: Icons.emergency_outlined,
                      accentBorderColor: OpenetraTheme.hazardWarning,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: emergencyBloc!,
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
                  if (flashlightController != null) ...[
                    AccessibleActionTile(
                      title: 'Intelligent Flashlight Controls',
                      subtitle: 'Manual torch toggle and opt-in low-light auto mode',
                      semanticHint: 'Double tap to open flashlight settings',
                      icon: Icons.flashlight_on_outlined,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FlashlightSettingsScreen(
                              controller: flashlightController!,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (gestureBloc != null) ...[
                    AccessibleActionTile(
                      title: 'Custom Hand Gestures',
                      subtitle: 'Enrol personal gestures to trigger Openetra actions offline',
                      semanticHint: 'Double tap to configure custom hand gestures',
                      icon: Icons.pan_tool_outlined,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: gestureBloc!,
                              child: const GestureAutomationScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (floatingCompanionBloc != null) ...[
                    AccessibleActionTile(
                      title: 'Floating Assistive Companion',
                      subtitle: 'Optional overlay orb with calm task-state glow above other apps',
                      semanticHint: 'Double tap to configure floating assistive companion',
                      icon: Icons.assistant_outlined,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: floatingCompanionBloc!,
                              child: const FloatingWidgetSettingsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (dialBloc != null) ...[
                    BlocBuilder<AssistiveDialBloc, AssistiveDialState>(
                      bloc: dialBloc,
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
                              onPressed: () => dialBloc!.add(
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
                              onPressed: () => dialBloc!.add(
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
                              onPressed: () => dialBloc!.add(
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
                  AccessibleActionTile(
                    title: 'Delete All Personal Data',
                    subtitle:
                        'Wipes saved objects, scanned documents, history, and safety logs',
                    semanticHint:
                        'Double tap to open confirmation dialog before deleting personal data',
                    icon: Icons.delete_forever,
                    accentBorderColor: OpenetraTheme.hazardCritical,
                    onPressed: () async {
                      final settingsBloc = context.read<SettingsBloc>();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: OpenetraTheme.surface,
                          title: const Text(
                            'Delete All Personal Data?',
                            style: TextStyle(color: OpenetraTheme.primaryText),
                          ),
                          content: const Text(
                            'This permanently removes saved personal items, scanned documents, conversation history, and safety logs. Built-in product staples remain offline.',
                            style: TextStyle(color: OpenetraTheme.secondaryText),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OpenetraTheme.hazardCritical,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: const Text('Permanently Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
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
