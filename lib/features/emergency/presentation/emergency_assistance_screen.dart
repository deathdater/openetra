import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/assistive/audio_arbitrator.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../bloc/emergency_bloc.dart';
import 'emergency_contacts_screen.dart';

class EmergencyAssistanceScreen extends StatelessWidget {
  const EmergencyAssistanceScreen({
    super.key,
    this.audioArbitrator,
    this.locale = 'en-IN',
  });

  final AudioArbitrator? audioArbitrator;
  final String locale;

  void _announceIfEnabled(String? msg) {
    if (msg != null && msg.isNotEmpty) {
      audioArbitrator?.speakPriorityEmergency(msg, locale: locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Assistance')),
      body: BlocConsumer<EmergencyBloc, EmergencyState>(
        listener: (context, state) {
          _announceIfEnabled(state.statusMessage);
        },
        builder: (context, state) {
          final primary = state.primaryContact;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SpokenStatusBanner(
                statusText: state.statusMessage ??
                    (primary != null
                        ? 'Primary contact ready: ${primary.name} (${primary.maskedPhone()}).'
                        : 'No trusted emergency contact configured yet.'),
                isDegraded: state.capabilities.airplaneMode ||
                    !state.capabilities.dialerAvailable,
                isBusy: state.awaitingConfirmation,
              ),
              const SizedBox(height: 16),
              if (state.capabilities.airplaneMode ||
                  !state.capabilities.telephonyAvailable)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: OpenetraTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: OpenetraTheme.hazardWarning, width: 1.5),
                  ),
                  child: const Text(
                    'Notice: Airplane mode is enabled or cellular telephony is unavailable on this device. Openetra cannot guarantee external emergency call delivery offline.',
                  ),
                ),
              if (state.awaitingConfirmation) ...[
                AccessibleActionTile(
                  title: state.pendingIsDryRun
                      ? 'Confirm Safe Test (No Call Placed)'
                      : 'Confirm: Open Phone Dialer Now',
                  subtitle: primary != null
                      ? '${primary.name} (${primary.maskedPhone()})'
                      : 'No contact selected',
                  semanticHint: 'Double tap to confirm emergency action',
                  icon: Icons.phone_forwarded,
                  accentBorderColor: OpenetraTheme.hazardCritical,
                  filledAccent: true,
                  onPressed: () => context
                      .read<EmergencyBloc>()
                      .add(const ConfirmEmergencyInitiation()),
                ),
                const SizedBox(height: 12),
                AccessibleActionTile(
                  title: 'Cancel Emergency Action',
                  subtitle: 'Aborts dialer handoff immediately',
                  semanticHint: 'Double tap to cancel emergency action',
                  icon: Icons.cancel_outlined,
                  onPressed: () => context
                      .read<EmergencyBloc>()
                      .add(const CancelEmergencyInitiation()),
                ),
              ] else ...[
                AccessibleActionTile(
                  title: 'Call Trusted Contact (Open Dialer)',
                  subtitle: primary != null
                      ? '${primary.name} (${primary.maskedPhone()}) — asks confirmation first'
                      : 'Add a trusted contact first',
                  semanticHint:
                      'Double tap to start confirmed emergency contact flow',
                  icon: Icons.emergency_outlined,
                  accentBorderColor: OpenetraTheme.hazardCritical,
                  filledAccent: primary != null,
                  onPressed: () => context
                      .read<EmergencyBloc>()
                      .add(const RequestEmergencyInitiation(isDryRun: false)),
                ),
                const SizedBox(height: 12),
                AccessibleActionTile(
                  title: 'Test Emergency Flow (No Real Call)',
                  subtitle: 'Exercises confirmation and audio without dialing',
                  semanticHint: 'Double tap to safely test emergency workflow',
                  icon: Icons.verified_outlined,
                  onPressed: () => context
                      .read<EmergencyBloc>()
                      .add(const RequestEmergencyInitiation(isDryRun: true)),
                ),
              ],
              const SizedBox(height: 16),
              AccessibleActionTile(
                title: 'Configure Trusted Contacts',
                subtitle: 'Add, verify digits, select primary, or remove contacts',
                semanticHint: 'Double tap to configure emergency contacts',
                icon: Icons.contacts_outlined,
                onPressed: () {
                  final bloc = context.read<EmergencyBloc>();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: EmergencyContactsScreen(
                          audioArbitrator: audioArbitrator,
                          locale: locale,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
