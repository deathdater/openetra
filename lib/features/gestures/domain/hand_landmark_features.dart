import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Raw 21x3 landmark output returned by native LiteRT MediaPipe Hand Landmarks.
class HandLandmarkFrame extends Equatable {
  const HandLandmarkFrame({
    required this.rawLandmarks63,
    required this.handPresenceScore,
    required this.handednessScore,
    this.inferenceMs = 0,
  });

  final List<double> rawLandmarks63;
  final double handPresenceScore;
  final double handednessScore;
  final int inferenceMs;

  bool get isValidShape => rawLandmarks63.length == 63;

  @override
  List<Object?> get props => [
        rawLandmarks63,
        handPresenceScore,
        handednessScore,
        inferenceMs,
      ];
}

/// Converts 21 3D hand landmarks into a translation-, scale-, and palm-normalized
/// 84-dimensional L2-unit feature vector for local personalized gesture matching.
class HandLandmarkFeatureExtractor {
  static const int featureDimension = 84;
  static const List<int> _fingertips = [4, 8, 12, 16, 20];
  static const List<(int tip, int base)> _fingerPairs = [
    (4, 2),
    (8, 5),
    (12, 9),
    (16, 13),
    (20, 17),
  ];

  static double _dist(List<double> raw, int a, int b) {
    final dx = raw[a * 3] - raw[b * 3];
    final dy = raw[a * 3 + 1] - raw[b * 3 + 1];
    final dz = raw[a * 3 + 2] - raw[b * 3 + 2];
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  static List<double> extract(List<double> raw63) {
    if (raw63.length != 63) {
      throw ArgumentError('Expected 63 landmark values (21x3), got ${raw63.length}');
    }
    // Anchor at palm center (mean of wrist + 4 MCP knuckles) so shared palm
    // offset does not inflate cosine similarity across distinct finger poses.
    const palmIndices = [0, 5, 9, 13, 17];
    var cx = 0.0;
    var cy = 0.0;
    var cz = 0.0;
    for (final idx in palmIndices) {
      cx += raw63[idx * 3];
      cy += raw63[idx * 3 + 1];
      cz += raw63[idx * 3 + 2];
    }
    cx /= palmIndices.length;
    cy /= palmIndices.length;
    cz /= palmIndices.length;

    final palmScale = math.max(
      math.max(_dist(raw63, 0, 9), _dist(raw63, 0, 5)),
      1e-4,
    );

    final features = List<double>.filled(featureDimension, 0.0);
    var offset = 0;

    // 1. 63 palm-centered, scale-normalized coordinates.
    for (var i = 0; i < 21; i++) {
      features[offset++] = (raw63[i * 3] - cx) / palmScale;
      features[offset++] = (raw63[i * 3 + 1] - cy) / palmScale;
      features[offset++] = (raw63[i * 3 + 2] - cz) / palmScale;
    }

    // 2. 10 centered pairwise fingertip distances (normalized by palmScale).
    for (var i = 0; i < _fingertips.length; i++) {
      for (var j = i + 1; j < _fingertips.length; j++) {
        features[offset++] =
            (_dist(raw63, _fingertips[i], _fingertips[j]) / palmScale) - 0.85;
      }
    }

    // 3. 5 centered fingertip-to-wrist distances (extended > 0, curled < 0).
    for (final tip in _fingertips) {
      features[offset++] = ((_dist(raw63, 0, tip) / palmScale) - 1.35) * 1.5;
    }

    // 4. 5 centered finger extension ratios (extended > 0, curled < 0) + palm spread.
    for (final (tip, base) in _fingerPairs) {
      final baseDist = math.max(_dist(raw63, 0, base), 1e-4);
      final ratio = (_dist(raw63, 0, tip) / baseDist).clamp(0.0, 3.0);
      features[offset++] = (ratio - 1.35) * 2.0;
    }
    features[offset++] = (_dist(raw63, 5, 17) / palmScale) - 0.75;

    return l2Normalize(features);
  }

  static List<double> l2Normalize(List<double> vec) {
    var sumSq = 0.0;
    for (final v in vec) {
      sumSq += v * v;
    }
    final norm = math.sqrt(sumSq);
    if (norm < 1e-9) return List<double>.filled(vec.length, 0.0);
    return List<double>.generate(vec.length, (i) => vec[i] / norm);
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return -1.0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denom = math.sqrt(na) * math.sqrt(nb);
    if (denom < 1e-9) return -1.0;
    return (dot / denom).clamp(-1.0, 1.0);
  }

  static List<double> computeCentroid(List<List<double>> vectors) {
    if (vectors.isEmpty) return const [];
    final dim = vectors.first.length;
    final mean = List<double>.filled(dim, 0.0);
    for (final v in vectors) {
      for (var i = 0; i < dim; i++) {
        mean[i] += v[i];
      }
    }
    for (var i = 0; i < dim; i++) {
      mean[i] /= vectors.length;
    }
    return l2Normalize(mean);
  }
}
