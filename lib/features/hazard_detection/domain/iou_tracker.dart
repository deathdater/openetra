import '../../../core/domain/entities/entities.dart';

class TrackedBox {
  const TrackedBox({
    required this.trackId,
    required this.label,
    required this.boundingBox,
    required this.consecutiveHits,
    required this.missedFrames,
    required this.areaGrowthRatio,
    required this.temporalPersistenceScore,
  });

  final int trackId;
  final String label;
  final BoundingBox boundingBox;
  final int consecutiveHits;
  final int missedFrames;
  final double areaGrowthRatio;
  final double temporalPersistenceScore;

  bool get isApproaching => consecutiveHits >= 2 && areaGrowthRatio >= 1.15;
}

/// Lightweight MIT-style pure-Dart multi-object IoU tracker providing persistent
/// track IDs, consecutive frame persistence, and bounding-box growth looming cues.
class IoUTracker {
  IoUTracker({
    this.iouThreshold = 0.30,
    this.maxMissedFrames = 2,
  });

  final double iouThreshold;
  final int maxMissedFrames;

  int _nextTrackId = 1;
  final List<TrackedBox> _activeTracks = [];

  List<TrackedBox> get activeTracks => List.unmodifiable(_activeTracks);

  void reset() {
    _nextTrackId = 1;
    _activeTracks.clear();
  }

  /// Associates [detections] against active tracks and returns one [TrackedBox]
  /// per input detection.
  List<TrackedBox> update(List<({String label, BoundingBox box})> detections) {
    final matchedTrackIndices = <int>{};
    final output = <TrackedBox>[];

    for (final det in detections) {
      int bestIdx = -1;
      double bestIou = iouThreshold;

      for (int i = 0; i < _activeTracks.length; i++) {
        if (matchedTrackIndices.contains(i)) continue;
        final track = _activeTracks[i];
        if (track.label != det.label.toLowerCase()) continue;
        final score = track.boundingBox.iou(det.box);
        if (score >= bestIou) {
          bestIou = score;
          bestIdx = i;
        }
      }

      if (bestIdx >= 0) {
        matchedTrackIndices.add(bestIdx);
        final prev = _activeTracks[bestIdx];
        final prevArea = prev.boundingBox.areaRatio;
        final currArea = det.box.areaRatio;
        final growth = prevArea > 0.0001 ? currArea / prevArea : 1.0;
        final hits = prev.consecutiveHits + 1;
        final persistence = (hits / 3.0).clamp(0.35, 1.0);
        final updated = TrackedBox(
          trackId: prev.trackId,
          label: prev.label,
          boundingBox: det.box,
          consecutiveHits: hits,
          missedFrames: 0,
          areaGrowthRatio: growth,
          temporalPersistenceScore: persistence,
        );
        _activeTracks[bestIdx] = updated;
        output.add(updated);
      } else {
        final created = TrackedBox(
          trackId: _nextTrackId++,
          label: det.label.toLowerCase(),
          boundingBox: det.box,
          consecutiveHits: 1,
          missedFrames: 0,
          areaGrowthRatio: 1.0,
          temporalPersistenceScore: 0.35,
        );
        _activeTracks.add(created);
        matchedTrackIndices.add(_activeTracks.length - 1);
        output.add(created);
      }
    }

    // Age unmatched tracks and prune expired ones.
    final retained = <TrackedBox>[];
    for (int i = 0; i < _activeTracks.length; i++) {
      final t = _activeTracks[i];
      if (matchedTrackIndices.contains(i)) {
        retained.add(t);
      } else if (t.missedFrames + 1 <= maxMissedFrames) {
        retained.add(
          TrackedBox(
            trackId: t.trackId,
            label: t.label,
            boundingBox: t.boundingBox,
            consecutiveHits: t.consecutiveHits,
            missedFrames: t.missedFrames + 1,
            areaGrowthRatio: t.areaGrowthRatio,
            temporalPersistenceScore: (t.temporalPersistenceScore * 0.7).clamp(0.1, 1.0),
          ),
        );
      }
    }
    _activeTracks
      ..clear()
      ..addAll(retained);

    return output;
  }
}
