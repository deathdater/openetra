import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/assistive/audio_arbitrator.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../bloc/emergency_bloc.dart';
import '../domain/trusted_contact.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({
    super.key,
    this.audioArbitrator,
    this.locale = 'en-IN',
  });

  final AudioArbitrator? audioArbitrator;
  final String locale;

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Emergency Contacts')),
      body: BlocBuilder<EmergencyBloc, EmergencyState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.statusMessage != null) ...[
                SpokenStatusBanner(
                  statusText: state.statusMessage!,
                  isDegraded: false,
                  isBusy: false,
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Trusted contacts are encrypted locally using Android Keystore AES-256-GCM and never uploaded or logged.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: OpenetraTheme.primaryText, fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Trusted Contact Name',
                  labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: OpenetraTheme.primaryText, fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g. +9198XXXXXXXX)',
                  labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _relationController,
                style: const TextStyle(color: OpenetraTheme.primaryText, fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional, e.g. Sister, Caregiver)',
                  labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AccessibleActionTile(
                title: 'Save Trusted Contact',
                subtitle: 'Encrypts offline and sets as primary if none selected',
                semanticHint: 'Double tap to save trusted emergency contact locally',
                icon: Icons.person_add_alt_1,
                filledAccent: true,
                onPressed: () {
                  context.read<EmergencyBloc>().add(
                        AddOrUpdateTrustedContact(
                          name: _nameController.text,
                          phoneNumber: _phoneController.text,
                          relationship: _relationController.text,
                          makePrimary: state.contacts.isEmpty,
                        ),
                      );
                  _nameController.clear();
                  _phoneController.clear();
                  _relationController.clear();
                },
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Emergency Action Preference',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              AccessibleActionTile(
                title:
                    'Open Phone Dialer (Recommended)${state.actionMode == EmergencyActionMode.openDialer ? " — Active" : ""}',
                subtitle:
                    'Populates number in Android phone dialer after confirmation',
                semanticHint: 'Double tap to select dialer handoff mode',
                icon: Icons.call,
                filledAccent: state.actionMode == EmergencyActionMode.openDialer,
                onPressed: () => context.read<EmergencyBloc>().add(
                      const UpdateEmergencyActionMode(
                        EmergencyActionMode.openDialer,
                      ),
                    ),
              ),
              const SizedBox(height: 8),
              AccessibleActionTile(
                title:
                    'Verification Test Mode Only${state.actionMode == EmergencyActionMode.dryRunVerificationOnly ? " — Active" : ""}',
                subtitle: 'Practices audio flow without opening phone dialer',
                semanticHint: 'Double tap to set dry-run verification mode',
                icon: Icons.shield_outlined,
                filledAccent:
                    state.actionMode == EmergencyActionMode.dryRunVerificationOnly,
                onPressed: () => context.read<EmergencyBloc>().add(
                      const UpdateEmergencyActionMode(
                        EmergencyActionMode.dryRunVerificationOnly,
                      ),
                    ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Saved Contacts (${state.contacts.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              if (state.contacts.isEmpty)
                const Text('No trusted contacts saved yet.')
              else
                ...state.contacts.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        AccessibleActionTile(
                          title: '${c.name}${c.isPrimary ? " (Primary)" : ""}',
                          subtitle:
                              'Ending in ${c.maskedPhone()}${c.relationship != null ? " • ${c.relationship}" : ""}',
                          semanticHint: 'Double tap to set ${c.name} as primary',
                          icon: c.isPrimary
                              ? Icons.star
                              : Icons.star_border_outlined,
                          filledAccent: c.isPrimary,
                          onPressed: () => context
                              .read<EmergencyBloc>()
                              .add(SelectPrimaryTrustedContact(c.id)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                widget.audioArbitrator?.announceTransition(
                                  categoryKey: 'contact_verify_${c.id}',
                                  spokenText:
                                      'Contact ${c.name}, number ${c.phoneNumber.split('').join(' ')}.',
                                  locale: widget.locale,
                                  cooldown: Duration.zero,
                                );
                              },
                              icon: const Icon(Icons.volume_up),
                              label: const Text('Read Digit Check'),
                            ),
                            TextButton.icon(
                              onPressed: () => context
                                  .read<EmergencyBloc>()
                                  .add(RemoveTrustedContact(c.id)),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: OpenetraTheme.hazardCritical,
                              ),
                              label: const Text(
                                'Remove',
                                style: TextStyle(color: OpenetraTheme.hazardCritical),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
