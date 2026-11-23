import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/bloc/audio_bloc.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../settings/bloc/settings_bloc.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Openetra'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Offline AI Visual Companion',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            const SpokenStatusBanner(
              statusText:
                  'Openetra runs completely offline on your phone after installation. '
                  'Safety notice: Openetra is an assistive aid and never replaces a white cane, '
                  'guide dog, or mobility training. It never guarantees a road is safe to cross.',
              isDegraded: false,
              isBusy: false,
            ),
            const SizedBox(height: 20),
            AccessibleActionTile(
              title: 'Hear Welcome & Safety Overview',
              subtitle: 'Tests offline speech synthesis at your current speed',
              semanticHint: 'Double tap to listen to onboarding instructions',
              icon: Icons.volume_up,
              onPressed: () {
                context.read<AudioBloc>().add(
                      SpeakAssistantResponse(
                        AssistantResponse(
                          responseId: 'onboarding-welcome',
                          spokenText:
                              'Welcome to Openetra. All visual processing stays on your device offline. '
                              'Openetra assists with scene descriptions, text reading, currency, and hazard cues, '
                              'but it never replaces your white cane or mobility training.',
                          displaySummary: 'Onboarding guidance spoken',
                          locale: context.read<SettingsBloc>().state.preferences.preferredLanguage,
                          priority: SpeechPriority.normal,
                          hapticPattern: HapticPattern.confirm,
                          timestamp: DateTime.now(),
                        ),
                      ),
                    );
              },
            ),
            const SizedBox(height: 16),
            AccessibleActionTile(
              title: 'Accept Safety Notice & Start Openetra',
              subtitle: 'Continue to the voice-first home screen',
              semanticHint: 'Double tap to complete setup and open main assistant',
              icon: Icons.check_circle_outline,
              filledAccent: true,
              onPressed: () {
                context.read<SettingsBloc>().add(const CompleteOnboarding());
                onCompleted();
              },
            ),
          ],
        ),
      ),
    );
  }
}
