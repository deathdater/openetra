import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/assistive/assistive_action.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../bloc/gesture_automation_bloc.dart';

class GestureAutomationScreen extends StatefulWidget {
  const GestureAutomationScreen({super.key});

  @override
  State<GestureAutomationScreen> createState() =>
      _GestureAutomationScreenState();
}

class _GestureAutomationScreenState extends State<GestureAutomationScreen> {
  final TextEditingController _nameController = TextEditingController();
  AssistiveActionId _selectedAction = AssistiveActionId.describeScene;

  static const List<({AssistiveActionId id, String label})> _mappableActions = [
    (id: AssistiveActionId.describeScene, label: 'Describe Scene'),
    (id: AssistiveActionId.readText, label: 'Read Text / Document'),
    (id: AssistiveActionId.assessHazardCues, label: 'Check Hazards'),
    (id: AssistiveActionId.toggleFlashlight, label: 'Toggle Flashlight'),
    (id: AssistiveActionId.cancelActiveTask, label: 'Stop / Cancel Active Task'),
    (id: AssistiveActionId.repeatLast, label: 'Repeat Last Result'),
    (
      id: AssistiveActionId.startEmergencyAssistance,
      label: 'Emergency Assistance (Requires Opt-In & Confirmation)',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Hand Gestures')),
      body: BlocBuilder<GestureAutomationBloc, GestureAutomationState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SpokenStatusBanner(
                statusText: state.statusMessage ??
                    (state.isEnabled
                        ? 'Custom hand gestures enabled (foreground opt-in only; ${state.gestures.length} saved).'
                        : 'Custom hand gestures disabled by default for battery and privacy.'),
                isDegraded: false,
                isBusy: state.isListening || state.isEnrolling,
              ),
              const SizedBox(height: 16),
              AccessibleActionTile(
                title: state.isEnabled
                    ? 'Custom Hand Gestures: Enabled'
                    : 'Custom Hand Gestures: Disabled',
                subtitle:
                    'Opt-in foreground recognition using offline MediaPipe hand landmarks (no video stored)',
                semanticHint: 'Double tap to enable or disable custom hand gestures',
                icon: Icons.pan_tool_outlined,
                filledAccent: state.isEnabled,
                onPressed: () => context
                    .read<GestureAutomationBloc>()
                    .add(SetGestureAutomationEnabled(!state.isEnabled)),
              ),
              const SizedBox(height: 12),
              AccessibleActionTile(
                title: state.emergencyGestureOptIn
                    ? 'Emergency Gesture Opt-In: Enabled'
                    : 'Emergency Gesture Opt-In: Disabled (Safest)',
                subtitle:
                    'Even when enabled, matching an emergency gesture only opens confirmation and never dials silently',
                semanticHint:
                    'Double tap to toggle emergency gesture safeguard opt-in',
                icon: Icons.warning_amber_rounded,
                accentBorderColor: OpenetraTheme.hazardWarning,
                filledAccent: state.emergencyGestureOptIn,
                onPressed: () => context.read<GestureAutomationBloc>().add(
                      SetEmergencyGestureOptIn(!state.emergencyGestureOptIn),
                    ),
              ),
              const SizedBox(height: 14),
              if (state.isListening)
                AccessibleActionTile(
                  title: 'Stop Gesture Listening',
                  subtitle: state.testModeOnly
                      ? 'Active in Test Mode (no actions executed)'
                      : 'Active in Foreground',
                  semanticHint: 'Double tap to stop gesture camera listening',
                  icon: Icons.stop_circle_outlined,
                  filledAccent: true,
                  onPressed: () => context
                      .read<GestureAutomationBloc>()
                      .add(const StopForegroundGestureListening()),
                )
              else ...[
                AccessibleActionTile(
                  title: 'Start Foreground Gesture Listening',
                  subtitle: 'Uses shared camera session while screen is active',
                  semanticHint: 'Double tap to start foreground gesture recognition',
                  icon: Icons.play_circle_outline,
                  onPressed: () => context
                      .read<GestureAutomationBloc>()
                      .add(const StartForegroundGestureListening()),
                ),
                const SizedBox(height: 10),
                AccessibleActionTile(
                  title: 'Test Gestures Safely (No Action Triggered)',
                  subtitle: 'Checks match score without running mapped actions',
                  semanticHint: 'Double tap to enter gesture test mode',
                  icon: Icons.science_outlined,
                  onPressed: () => context.read<GestureAutomationBloc>().add(
                        const StartForegroundGestureListening(
                          testModeOnly: true,
                        ),
                      ),
                ),
              ],
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Enrol New Personal Gesture',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: OpenetraTheme.primaryText,
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  labelText: 'Gesture Name (e.g. Open Palm, Peace Sign)',
                  labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AssistiveActionId>(
                value: _selectedAction,
                dropdownColor: OpenetraTheme.surface,
                style: const TextStyle(
                  color: OpenetraTheme.primaryText,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  labelText: 'Mapped Openetra Action',
                  labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.border),
                  ),
                ),
                items: [
                  for (final item in _mappableActions)
                    DropdownMenuItem<AssistiveActionId>(
                      value: item.id,
                      child: Text(item.label),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedAction = v);
                },
              ),
              const SizedBox(height: 12),
              if (state.isEnrolling) ...[
                AccessibleActionTile(
                  title:
                      'Capture Sample (${state.capturedSampleCount}/${state.requiredSampleCount})',
                  subtitle: 'Hold "${state.enrollingName}" steady in front of camera',
                  semanticHint: 'Double tap to capture hand gesture sample',
                  icon: Icons.camera_alt_outlined,
                  filledAccent: true,
                  onPressed: () => context
                      .read<GestureAutomationBloc>()
                      .add(const CaptureEnrollmentSample()),
                ),
                const SizedBox(height: 8),
                AccessibleActionTile(
                  title: 'Cancel Enrolment',
                  subtitle: 'Discards captured samples',
                  semanticHint: 'Double tap to cancel gesture enrolment',
                  icon: Icons.cancel_outlined,
                  onPressed: () => context
                      .read<GestureAutomationBloc>()
                      .add(const CancelGestureEnrollment()),
                ),
              ] else
                AccessibleActionTile(
                  title: 'Start Gesture Enrolment',
                  subtitle: 'Records 5 consistent samples locally on device',
                  semanticHint: 'Double tap to start enrolling new hand gesture',
                  icon: Icons.add_circle_outline,
                  filledAccent: true,
                  onPressed: () => context.read<GestureAutomationBloc>().add(
                        StartGestureEnrollment(
                          name: _nameController.text,
                          actionId: _selectedAction,
                        ),
                      ),
                ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Enrolled Gestures (${state.gestures.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              if (state.gestures.isEmpty)
                const Text('No personal gestures enrolled yet.')
              else
                for (final g in state.gestures)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: OpenetraTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: g.isValidated
                              ? OpenetraTheme.accent
                              : OpenetraTheme.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${g.name} -> ${g.actionId.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Samples: ${g.sampleCount} • ${g.isValidated ? "Active" : "Paused"}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context
                                      .read<GestureAutomationBloc>()
                                      .add(
                                        ToggleGestureEnabled(
                                          gestureId: g.id,
                                          enabled: !g.isValidated,
                                        ),
                                      ),
                                  child: Text(g.isValidated ? 'Pause' : 'Enable'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context
                                      .read<GestureAutomationBloc>()
                                      .add(DeleteCustomGesture(g.id)),
                                  child: const Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
