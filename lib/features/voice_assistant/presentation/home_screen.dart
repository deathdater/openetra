import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/openetra_coordinator.dart';
import '../../../app/theme.dart';
import '../../../core/audio/bloc/audio_bloc.dart';
import '../../../core/resource_management/bloc/device_resource_bloc.dart';
import '../../../core/safety/bloc/safety_bloc.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../model_manager/presentation/model_manager_screen.dart';
import '../../object_memory/presentation/object_memory_screen.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vision_explorer/bloc/vision_bloc.dart';
import '../bloc/voice_assistant_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.coordinator});

  final OpenetraCoordinator coordinator;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _voicePromptController = TextEditingController();

  @override
  void dispose() {
    _voicePromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Openetra Assistant'),
        actions: [
          Semantics(
            button: true,
            label: 'Model Manager',
            hint: 'Inspect offline AI models and verify integrity',
            child: IconButton(
              icon: const Icon(Icons.memory, size: 28),
              tooltip: 'Model Manager',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ModelManagerScreen(),
                  ),
                );
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Settings',
            hint: 'Language, speech speed, operating mode, and data deletion',
            child: IconButton(
              icon: const Icon(Icons.settings, size: 28),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<VoiceAssistantBloc, VoiceAssistantState>(
          builder: (context, voiceState) {
            return BlocBuilder<VisionBloc, VisionState>(
              builder: (context, visionState) {
                return BlocBuilder<SafetyBloc, SafetyBlocState>(
                  builder: (context, safetyState) {
                    return BlocBuilder<DeviceResourceBloc, DeviceResourceBlocState>(
                      builder: (context, resourceState) {
                        final isBusy = visionState is VisionProcessing;
                        final lastText = voiceState.lastResponse?.spokenText ??
                            'Openetra ready offline. Tap Describe Surroundings or enter a voice command.';
                        final isDegraded = safetyState.isDegraded ||
                            (voiceState.lastResponse?.isDegraded ?? false) ||
                            resourceState.resourceState.isDegradedCapability;
                        final prefs = context.watch<SettingsBloc>().state.preferences;

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            SpokenStatusBanner(
                              statusText: lastText,
                              isDegraded: isDegraded,
                              isBusy: isBusy,
                            ),
                            const SizedBox(height: 10),
                            Semantics(
                              label:
                                  'Mode ${resourceState.resourceState.operatingMode.name}, '
                                  'Language ${prefs.preferredLanguage}, '
                                  'Battery ${resourceState.resourceState.batteryPercent} percent',
                              child: Text(
                                'Mode: ${resourceState.resourceState.operatingMode.name.toUpperCase()}  •  '
                                'Lang: ${prefs.preferredLanguage}  •  '
                                'Battery: ${resourceState.resourceState.batteryPercent}%',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AccessibleActionTile(
                              title: 'Stop Speaking / Interrupt',
                              subtitle: 'Silences current speech and pauses continuous scan',
                              semanticHint: 'Double tap to immediately stop audio output',
                              icon: Icons.stop_circle_outlined,
                              accentBorderColor: OpenetraTheme.hazardCritical,
                              minHeight: 68,
                              onPressed: () {
                                context
                                    .read<AudioBloc>()
                                    .add(const InterruptSpeechRequested());
                              },
                            ),
                            const SizedBox(height: 14),
                            AccessibleActionTile(
                              title: 'Describe Surroundings',
                              subtitle: 'Captures view and summarizes objects & layout',
                              semanticHint: 'Double tap to describe what is in front of you',
                              icon: Icons.visibility,
                              filledAccent: true,
                              onPressed: isBusy
                                  ? null
                                  : () => widget.coordinator.runDescribeSurroundings(),
                            ),
                            const SizedBox(height: 12),
                            AccessibleActionTile(
                              title: 'Hazard Awareness Scan',
                              subtitle:
                                  'Checks path for obstacles, stairs, vehicles & low light',
                              semanticHint: 'Double tap to scan for potential hazards',
                              icon: Icons.warning_amber_rounded,
                              accentBorderColor: OpenetraTheme.hazardWarning,
                              onPressed: isBusy
                                  ? null
                                  : () => widget.coordinator.runHazardScan(),
                            ),
                            const SizedBox(height: 12),
                            AccessibleActionTile(
                              title: 'Read Text (Smart Reader)',
                              subtitle:
                                  'Reads signs, labels & documents with script routing',
                              semanticHint: 'Double tap to read printed text',
                              icon: Icons.menu_book,
                              onPressed: isBusy
                                  ? null
                                  : () => widget.coordinator.runSmartReader(),
                            ),
                            const SizedBox(height: 12),
                            AccessibleActionTile(
                              title: 'Identify Currency Note',
                              subtitle:
                                  'Checks Indian rupee denomination with uncertainty notice',
                              semanticHint: 'Double tap to identify an Indian currency note',
                              icon: Icons.currency_rupee,
                              onPressed: isBusy
                                  ? null
                                  : () => widget.coordinator.runIdentifyCurrency(),
                            ),
                            const SizedBox(height: 12),
                            AccessibleActionTile(
                              title: 'Personal Object Memory',
                              subtitle: 'Register or locate saved items like wallet or keys',
                              semanticHint: 'Double tap to open personal object memory',
                              icon: Icons.search,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ObjectMemoryScreen(
                                      onFindObjectRequested: (item) =>
                                          widget.coordinator.runFindObject(item),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _voicePromptController,
                                    style: const TextStyle(
                                      color: OpenetraTheme.primaryText,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Offline Command / Follow-up (EN/HI/KN)',
                                      labelStyle: TextStyle(
                                        color: OpenetraTheme.secondaryText,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: OpenetraTheme.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: OpenetraTheme.accent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        widget.coordinator.handleVoiceCommand(value);
                                        _voicePromptController.clear();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Semantics(
                                  button: true,
                                  label: 'Run Command',
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(84, 60),
                                      backgroundColor: OpenetraTheme.accent,
                                      foregroundColor: OpenetraTheme.accentText,
                                    ),
                                    onPressed: () {
                                      final txt = _voicePromptController.text.trim();
                                      if (txt.isEmpty) return;
                                      widget.coordinator.handleVoiceCommand(txt);
                                      _voicePromptController.clear();
                                    },
                                    child: const Text('Run'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
