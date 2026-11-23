import 'package:flutter/material.dart';
import '../../../app/openetra_coordinator.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
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
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;
    final activeLocale =
        widget.coordinator.settingsBloc.state.preferences.preferredLanguage;

    return Scaffold(
      appBar: AppBar(title: const Text('Recorded Scene Memories')),
      body: ListView(
        padding: const EdgeInsets.all(OpenetraSpacing.lg),
        children: [
          if (_statusMessage != null) ...[
            SpokenStatusBanner(
              statusText: _statusMessage!,
              isDegraded: false,
              isBusy: _isRecording,
            ),
            const SizedBox(height: OpenetraSpacing.lg),
          ],
          const OpenetraSectionHeader(
            title: 'Record New Scene Clip',
            subtitle: 'Slowly pan the camera across your surroundings to store a full offline breakdown',
          ),
          OpenetraTextField(
            controller: _titleController,
            labelText: 'Scene title (optional, e.g., Living room, Desk)',
          ),
          const SizedBox(height: OpenetraSpacing.md),
          OpenetraTextField(
            controller: _noteController,
            labelText: 'Spoken note to attach (optional)',
          ),
          const SizedBox(height: OpenetraSpacing.md),
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
          const SizedBox(height: OpenetraSpacing.xl),
          OpenetraSectionHeader(
            title: 'Saved Scene Breakdowns (${_scenes.length})',
          ),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(OpenetraSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_scenes.isEmpty)
            const OpenetraEmptyState(
              icon: Icons.videocam_off_outlined,
              title: 'No recorded scenes stored yet',
              message:
                  'Tap Record Scene Clip above while slowly panning the camera across your surroundings.',
            )
          else
            ..._scenes.map((scene) {
              final breakdownPreview = scene.buildSpokenBreakdown(activeLocale);
              final regNames = scene.recognizedRegisteredObjects
                  .map((m) => m.objectName)
                  .join(', ');
              return OpenetraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: OpenetraSpacing.xs + 2),
                    Text(
                      '${scene.environment} · ${scene.frameCount} frames · ${scene.items.length} items',
                      style: textTheme.bodySmall,
                    ),
                    if (regNames.isNotEmpty) ...[
                      const SizedBox(height: OpenetraSpacing.sm),
                      OpenetraStatusBadge(
                        label: 'Registered items spotted: $regNames',
                        icon: Icons.bookmark_added_outlined,
                        tone: OpenetraBadgeTone.accent,
                      ),
                    ],
                    if (scene.customNote != null &&
                        scene.customNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: OpenetraSpacing.sm),
                      Text(
                        'Note: ${scene.customNote}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: palette.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: OpenetraSpacing.sm),
                    Text(
                      breakdownPreview,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: OpenetraSpacing.md),
                    AccessibleActionTile(
                      title: 'Speak Full Breakdown ($activeLocale)',
                      subtitle: 'Reads the stored scene and your note aloud',
                      semanticHint:
                          'Double tap to hear the complete breakdown for ${scene.title}',
                      icon: Icons.volume_up_outlined,
                      onPressed: () =>
                          widget.coordinator.speakRecordedScene(scene),
                    ),
                    const SizedBox(height: OpenetraSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openEditDialog(scene),
                          icon: Icon(
                            Icons.edit_outlined,
                            color: palette.secondary,
                          ),
                          label: Text(
                            'Modify Note',
                            style: TextStyle(color: palette.secondary),
                          ),
                        ),
                        const SizedBox(width: OpenetraSpacing.sm),
                        TextButton.icon(
                          onPressed: () => _deleteScene(scene),
                          icon: Icon(
                            Icons.delete_outline,
                            color: palette.error,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(color: palette.error),
                          ),
                        ),
                      ],
                    ),
                  ],
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
      title: const Text('Modify Scene & Spoken Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OpenetraTextField(
              controller: _titleCtrl,
              labelText: 'Scene title',
            ),
            const SizedBox(height: OpenetraSpacing.md),
            OpenetraTextField(
              controller: _noteCtrl,
              maxLines: 3,
              labelText: 'Custom note (spoken in active language)',
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
