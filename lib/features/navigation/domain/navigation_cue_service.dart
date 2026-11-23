import '../../../core/domain/entities/entities.dart';

/// Provides cautious, non-directional-claim spatial orientation cues derived
/// strictly from grounded SceneGraph observations.
class NavigationCueService {
  const NavigationCueService();

  String summarizeOrientationCues(SceneGraph graph) {
    final doorways = graph.nodes.where(
      (n) =>
          n.name.toLowerCase().contains('door') ||
          n.name.toLowerCase().contains('exit') ||
          n.name.toLowerCase().contains('stairs') ||
          n.name.toLowerCase().contains('gate'),
    );
    if (doorways.isEmpty) {
      return 'No obvious doorway, exit, or stair landmark identified in the current camera view. Pan slowly and rely on your white cane.';
    }
    final cues = doorways
        .take(3)
        .map((d) => '${d.name} in the ${d.relativePosition.toSpokenPhrase()}')
        .join('; ');
    return 'Visible landmarks: $cues. Continue verifying surfaces with your white cane.';
  }
}
