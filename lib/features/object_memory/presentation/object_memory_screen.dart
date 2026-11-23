import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../bloc/object_memory_bloc.dart';

class ObjectMemoryScreen extends StatefulWidget {
  const ObjectMemoryScreen({
    super.key,
    required this.onFindObjectRequested,
  });

  final ValueChanged<String> onFindObjectRequested;

  @override
  State<ObjectMemoryScreen> createState() => _ObjectMemoryScreenState();
}

class _ObjectMemoryScreenState extends State<ObjectMemoryScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Object Memory')),
      body: BlocBuilder<ObjectMemoryBloc, ObjectMemoryState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.lastSearchResult != null) ...[
                SpokenStatusBanner(
                  statusText: state.lastSearchResult!,
                  isDegraded: false,
                  isBusy: state.isSearching,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _nameController,
                style: const TextStyle(color: OpenetraTheme.primaryText, fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Personal item name (e.g., wallet, keys, bottle)',
                  labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: OpenetraTheme.accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AccessibleActionTile(
                title: 'Save Item Profile Locally',
                subtitle: 'Stores item label offline in SQLite for fast search',
                semanticHint: 'Double tap to save personal object name',
                icon: Icons.add_circle_outline,
                filledAccent: true,
                onPressed: () {
                  final text = _nameController.text.trim();
                  if (text.isEmpty) return;
                  context
                      .read<ObjectMemoryBloc>()
                      .add(RegisterPersonalObject(name: text));
                  _nameController.clear();
                },
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Saved Personal Belongings (${state.profiles.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (state.profiles.isEmpty)
                const Text(
                  'No personal objects saved yet. Add items like wallet, keys, or water bottle above.',
                )
              else
                ...state.profiles.map((p) {
                  final lastSeen = p.lastSeenSetting != null
                      ? 'Last seen: ${p.lastSeenSetting}'
                      : 'Not searched yet';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        AccessibleActionTile(
                          title: 'Find ${p.name}',
                          subtitle: lastSeen,
                          semanticHint: 'Double tap to scan surroundings for ${p.name}',
                          icon: Icons.search,
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onFindObjectRequested(p.name);
                          },
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: 'Delete ${p.name}',
                            child: TextButton.icon(
                              onPressed: () => context
                                  .read<ObjectMemoryBloc>()
                                  .add(RemovePersonalObject(p.id)),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: OpenetraTheme.hazardCritical,
                              ),
                              label: const Text(
                                'Remove',
                                style: TextStyle(color: OpenetraTheme.hazardCritical),
                              ),
                            ),
                          ),
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
