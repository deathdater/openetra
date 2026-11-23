import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
import '../bloc/model_manager_bloc.dart';

class ModelManagerScreen extends StatelessWidget {
  const ModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline AI Model Manager')),
      body: BlocBuilder<ModelManagerBloc, ModelManagerState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.statusMessage != null) ...[
                SpokenStatusBanner(
                  statusText: state.statusMessage!,
                  isDegraded: false,
                  isBusy: state.isWorking,
                ),
                const SizedBox(height: 16),
              ],
              AccessibleActionTile(
                title: 'Verify & Load Mirage Vision Model',
                subtitle: 'Checks SHA-256 checksum and loads into Cactus native runtime',
                semanticHint: 'Double tap to verify Mirage model integrity and load',
                icon: Icons.verified_user,
                filledAccent: true,
                onPressed: state.isWorking
                    ? null
                    : () => context
                        .read<ModelManagerBloc>()
                        .add(const VerifyAndLoadVisionModel()),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Registered On-Device Models (${state.models.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              ...state.models.map((m) {
                final palette = OpenetraTheme.paletteOf(context);
                final mb = (m.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
                final ready = m.status == ModelStatus.loadedInMemory ||
                    m.status == ModelStatus.verifiedReady;
                return OpenetraCard(
                  borderColor: ready ? palette.success : palette.border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      OpenetraStatusBadge(
                        label: '${m.status.name} · ${m.runtime.name}',
                        icon: ready
                            ? Icons.check_circle_outline
                            : Icons.pending_outlined,
                        tone: ready
                            ? OpenetraBadgeTone.success
                            : OpenetraBadgeTone.neutral,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Size: $mb MB | Licence: ${m.licence} | Quant: ${m.quantization}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Languages: ${m.languages.join(", ")}',
                        style: Theme.of(context).textTheme.bodyMedium,
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
