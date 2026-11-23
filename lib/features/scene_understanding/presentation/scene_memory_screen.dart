import 'package:flutter/material.dart';
import '../../../app/openetra_coordinator.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../domain/recorded_scene_memory.dart';

/// Accessible offline screen for recording multi-frame scene clips, reviewing
/// stored scene breakdowns, editing spoken notes/modifications, and speaking
/// them aloud in the user's active language.
class SceneMemoryScreen extends StatefulWidget {
  const SceneMemoryScreen({
    super.key,
    required this.coordinator,
  });

  final OpenetraCoordinator coordinator;

  @override
  State<SceneMemoryScreen> createState() => _SceneMemoryScreenState();
}

class _SceneMemoryScreenState extends State<SceneMemoryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<RecordedSceneRecord> _scenes = const [];
  bool _isLoading = true;
  bool _isRecording = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadScenes() async {
    final rows = await widget.coordinator.listRecordedScenes();
    if (!mounted) return;
    setState(() {
      _scenes = rows;
      _isLoading = false;
    });
  }

  Future<void> _recordNewScene() async {
    if (_isRecording) return;
    setState(() {
      _isRecording = true;
      _statusMessage = 'Recording scene pan: capturing frame 1 of 4...';
    });
    try {
      final saved = await widget.coordinator.recordAndSaveSceneClip(
        title: _titleController.text.trim(),
        customNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        onProgress: (captured, total) {
          if (!mounted) return;
          setState(() {
            _statusMessage =
                'Recording scene pan: analyzed frame $captured of $total...';
          });
        },
      );
      _titleController.clear();
      _noteController.clear();
      await _loadScenes();
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Saved "${saved.title}" (${saved.frameCount} frames). Speaking breakdown.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Unable to record scene right now: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _openEditDialog(RecordedSceneRecord record) async {
    final result = await showDialog<({String title, String note})>(
      context: context,
      builder: (_) => _EditSceneNoteDialog(
        initialTitle: record.title,
        initialNote: record.customNote ?? '',
      ),
    );

    if (result != null) {
      await widget.coordinator.updateRecordedSceneNote(
        record.id,
        title: result.title.isNotEmpty ? result.title : record.title,
        customNote: result.note,
        speakUpdated: true,
      );
      await _loadScenes();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Updated scene note and speaking in active language.';
      });
    }
  }

  Future<void> _deleteScene(RecordedSceneRecord record) async {
    await widget.coordinator.deleteRecordedScene(record.id);
    await _loadScenes();
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Deleted "${record.title}".';
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLocale =
        widget.coordinator.settingsBloc.state.preferences.preferredLanguage;

    return Scaffold(
      appBar: AppBar(title: const Text('Recorded Scene Memories')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_statusMessage != null) ...[
            SpokenStatusBanner(
              statusText: _statusMessage!,
              isDegraded: false,
              isBusy: _isRecording,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _titleController,
            style: const TextStyle(
              color: OpenetraTheme.primaryText,
              fontSize: 18,
            ),
            decoration: const InputDecoration(
              labelText: 'Scene title (optional, e.g., Living room, Desk)',
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
          TextField(
            controller: _noteController,
            style: const TextStyle(
              color: OpenetraTheme.primaryText,
              fontSize: 18,
            ),
            decoration: const InputDecoration(
              labelText: 'Spoken note to attach (optional)',
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
            title: _isRecording
                ? 'Recording Scene Pan...'
                : 'Record Scene Clip & Save Breakdown',
            subtitle:
                'Captures 4 keyframes offline, fuses the full scene + registered items, and speaks in $activeLocale',
            semanticHint:
                'Double tap to record a short camera pan and save its complete spoken scene breakdown offline',
            icon: Icons.videocam_outlined,
            filledAccent: true,
            onPressed: _isRecording ? null : _recordNewScene,
          ),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: Text(
              'Saved Scene Breakdowns (${_scenes.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_scenes.isEmpty)
            const Text(
              'No recorded scenes stored yet. Tap Record Scene Clip above while slowly panning the camera across your surroundings.',
            )
          else
            ..._scenes.map((scene) {
              final breakdownPreview = scene.buildSpokenBreakdown(activeLocale);
              final regNames = scene.recognizedRegisteredObjects
                  .map((m) => m.objectName)
                  .join(', ');
              return Card(
                color: OpenetraTheme.surface,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: OpenetraTheme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: OpenetraTheme.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${scene.environment} · ${scene.frameCount} frames · ${scene.items.length} items',
                        style: const TextStyle(
                          color: OpenetraTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      if (regNames.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Registered items spotted: $regNames',
                          style: const TextStyle(
                            color: OpenetraTheme.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (scene.customNote != null &&
                          scene.customNote!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Note: ${scene.customNote}',
                          style: const TextStyle(
                            color: OpenetraTheme.primaryText,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        breakdownPreview,
                        style: const TextStyle(
                          color: OpenetraTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AccessibleActionTile(
                        title: 'Speak Full Breakdown ($activeLocale)',
                        subtitle: 'Reads the stored scene and your note aloud',
                        semanticHint:
                            'Double tap to hear the complete breakdown for ${scene.title}',
                        icon: Icons.volume_up_outlined,
                        onPressed: () =>
                            widget.coordinator.speakRecordedScene(scene),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openEditDialog(scene),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: OpenetraTheme.accent,
                            ),
                            label: const Text(
                              'Modify Note',
                              style: TextStyle(color: OpenetraTheme.accent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _deleteScene(scene),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: OpenetraTheme.hazardCritical,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(
                                color: OpenetraTheme.hazardCritical,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EditSceneNoteDialog extends StatefulWidget {
  const _EditSceneNoteDialog({
    required this.initialTitle,
    required this.initialNote,
  });

  final String initialTitle;
  final String initialNote;

  @override
  State<_EditSceneNoteDialog> createState() => _EditSceneNoteDialogState();
}

class _EditSceneNoteDialogState extends State<_EditSceneNoteDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _noteCtrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: OpenetraTheme.surface,
      title: const Text(
        'Modify Scene & Spoken Note',
        style: TextStyle(color: OpenetraTheme.primaryText),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                color: OpenetraTheme.primaryText,
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                labelText: 'Scene title',
                labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: OpenetraTheme.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: OpenetraTheme.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              style: const TextStyle(
                color: OpenetraTheme.primaryText,
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                labelText: 'Custom note (spoken in active language)',
                labelStyle: TextStyle(color: OpenetraTheme.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: OpenetraTheme.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: OpenetraTheme.accent, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            (title: _titleCtrl.text.trim(), note: _noteCtrl.text.trim()),
          ),
          child: const Text('Save & Speak'),
        ),
      ],
    );
  }
}
