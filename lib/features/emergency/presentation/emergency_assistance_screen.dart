import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/assistive/audio_arbitrator.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
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
          final palette = OpenetraTheme.paletteOf(context);
          final primary = state.primaryContact;
          return ListView(
            padding: const EdgeInsets.all(OpenetraSpacing.lg),
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
              const SizedBox(height: OpenetraSpacing.lg),
              if (state.capabilities.airplaneMode ||
                  !state.capabilities.telephonyAvailable)
                OpenetraCard(
                  borderColor: palette.warning,
                  child: const Text(
                    'Notice: Airplane mode is enabled or cellular telephony is unavailable on this device. Openetra cannot guarantee external emergency call delivery offline.',
                  ),
                ),
              const OpenetraSectionHeader(title: 'Emergency Actions'),
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
                  accentBorderColor: palette.error,
                  filledAccent: true,
                  onPressed: () => context
                      .read<EmergencyBloc>()
                      .add(const ConfirmEmergencyInitiation()),
                ),
                const SizedBox(height: OpenetraSpacing.md),
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
                  accentBorderColor: palette.error,
                  filledAccent: primary != null,
                  onPressed: () => context
                      .read<EmergencyBloc>()
                      .add(const RequestEmergencyInitiation(isDryRun: false)),
                ),
                const SizedBox(height: OpenetraSpacing.md),
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
              const SizedBox(height: OpenetraSpacing.lg),
              const OpenetraSectionHeader(title: 'Trusted Contacts'),
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
