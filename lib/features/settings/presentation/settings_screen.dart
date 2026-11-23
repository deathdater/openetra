import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/audio/bloc/audio_bloc.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/resource_management/bloc/device_resource_bloc.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../bloc/settings_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
