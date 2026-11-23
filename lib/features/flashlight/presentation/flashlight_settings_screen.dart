import 'package:flutter/material.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../domain/intelligent_flashlight_controller.dart';

class FlashlightSettingsScreen extends StatelessWidget {
  const FlashlightSettingsScreen({
    super.key,
    required this.controller,
  });

  final IntelligentFlashlightController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intelligent Flashlight')),
      body: StreamBuilder<FlashlightControllerState>(
        stream: controller.stream,
        initialData: controller.state,
        builder: (context, snap) {
          final st = snap.data ?? controller.state;
          final hw = st.hardwareStatus;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SpokenStatusBanner(
                statusText: st.statusSummary,
                isDegraded: !hw.hasFlash || st.autoPaused,
                isBusy: hw.torchOn,
              ),
              const SizedBox(height: 16),
              AccessibleActionTile(
                title: hw.torchOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
                subtitle: hw.externalTorchActive
                    ? 'External system torch active — Openetra will not override'
                    : (hw.openetraOwnsTorch
                        ? 'Torch is active and owned by Openetra'
                        : 'Manual toggle always overrides automatic mode'),
                semanticHint: 'Double tap to toggle phone flashlight',
                icon: hw.torchOn ? Icons.flashlight_off : Icons.flashlight_on,
                filledAccent: hw.torchOn,
                onPressed: () => controller.toggleManual(),
              ),
              const SizedBox(height: 14),
              AccessibleActionTile(
                title: st.config.autoModeEnabled
                    ? 'Automatic Low-Light Torch: Enabled'
                    : 'Automatic Low-Light Torch: Disabled',
                subtitle:
                    'Opt-in only during active authorized Openetra tasks (3 min max continuous safety cutoff). Never guarantees obstacle detection or path safety.',
                semanticHint: 'Double tap to toggle automatic low-light flashlight',
                icon: Icons.auto_awesome_outlined,
                filledAccent: st.config.autoModeEnabled,
                onPressed: () =>
                    controller.setAutoModeEnabled(!st.config.autoModeEnabled),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Low-Light Trigger Threshold (${st.config.lowLightTurnOnLux.toStringAsFixed(0)} lux / off at ${st.config.brightTurnOffLux.toStringAsFixed(0)} lux)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Slider(
                value: st.config.lowLightTurnOnLux,
                min: 5.0,
                max: 40.0,
                divisions: 7,
                label: '${st.config.lowLightTurnOnLux.toStringAsFixed(0)} lux',
                onChanged: (v) => controller.setLowLightThresholdLux(v),
              ),
              const SizedBox(height: 12),
              Text(
                'Hardware Status: Flash=${hw.hasFlash ? "Yes" : "No"}, '
                'Ambient Sensor=${hw.hasLightSensor ? "Yes" : "Frame luma fallback"}, '
                'Camera Active=${hw.cameraActive ? "Yes" : "No"}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}
