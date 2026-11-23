import 'package:uuid/uuid.dart';
import '../../../core/domain/entities/entities.dart';
import '../../scene_understanding/domain/scene_understanding_engine.dart';
import 'hazard_taxonomy.dart';
import 'iou_tracker.dart';

/// Independent safety-critical hazard evaluation pipeline.
/// Strictly separates object detection confidence, hazard classification
/// confidence, spatial path relevance, distance confidence, and temporal
/// persistence; never equates a raw detector score to safety probability.
class HazardIntelligenceEngine {
  HazardIntelligenceEngine({
    HazardTaxonomy? taxonomy,
    IoUTracker? tracker,
    this.alertCooldown = const Duration(seconds: 4),
    DateTime Function()? clock,
  })  : _taxonomy = taxonomy ?? const HazardTaxonomy(),
        _tracker = tracker ?? IoUTracker(),
        _clock = clock ?? DateTime.now;

  final HazardTaxonomy _taxonomy;
  final IoUTracker _tracker;
  final Duration alertCooldown;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  final Map<String, ({DateTime spokenAt, HazardSeverity severity})>
      _cooldownCache = {};

  void reset() {
    _tracker.reset();
    _cooldownCache.clear();
  }

  HazardAssessment evaluate(
    VisionObservation observation, {
    double? calibratedDepthConfidence,
    bool deviceResourceDegraded = false,
    String? deviceDegradationReason,
  }) {
    final now = _clock();
    final degradationReasons = <String>[];
    if (observation.imageQuality.isDegraded) {
      degradationReasons.addAll(observation.imageQuality.degradationReasons);
    }
    if (deviceResourceDegraded && deviceDegradationReason != null) {
      degradationReasons.add(deviceDegradationReason);
    }
    final degradedMode = degradationReasons.isNotEmpty;

    final rawCandidates = <({
      String label,
      BoundingBox box,
      double detConf,
      HazardMatch match,
    })>[];

    for (final obj in observation.objects) {
      if (obj.confidence < 0.25) continue;
      final match = _taxonomy.classifyObject(obj);
      if (match != null) {
        rawCandidates.add((
          label: obj.name,
          box: obj.boundingBox,
          detConf: obj.confidence,
          match: match,
        ));
      }
    }

    for (final span in observation.textSpans) {
      if (span.confidence < 0.35) continue;
      final match = _taxonomy.classifyWarningText(span);
      if (match != null) {
        rawCandidates.add((
          label: 'warning sign: ${span.text}',
          box: span.boundingBox,
          detConf: span.confidence,
          match: match,
        ));
      }
    }

    final tracked = _tracker.update(
      rawCandidates.map((c) => (label: c.label, box: c.box)).toList(),
    );

    final hazardObservations = <HazardObservation>[];
    for (int i = 0; i < rawCandidates.length; i++) {
      final cand = rawCandidates[i];
      final track = tracked[i];
      final relPos = SceneUnderstandingEngine.deriveRelativePosition(cand.box);
      final inWalkingPath = _isInWalkingPath(cand.box, cand.match.category);
      final spatialConf = _computeSpatialConfidence(cand.box, inWalkingPath);

      hazardObservations.add(
        HazardObservation(
          observationId: _uuid.v4(),
          label: cand.label,
          category: cand.match.category,
          boundingBox: cand.box,
          relativePosition: relPos,
          confidenceBreakdown: HazardConfidenceBreakdown(
            detectionConfidence: cand.detConf,
            hazardClassificationConfidence: cand.match.classificationConfidence,
            spatialConfidence: spatialConf,
            distanceConfidence: calibratedDepthConfidence,
            temporalPersistenceScore: track.temporalPersistenceScore,
          ),
          trackId: track.trackId,
          consecutiveFrames: track.consecutiveHits,
          isInWalkingPath: inWalkingPath,
          isApproaching: track.isApproaching,
          sourceModelId: observation.provenance.modelId,
          observedAt: now,
          evidenceSummary: cand.match.reason,
        ),
      );
    }

    hazardObservations.sort((a, b) {
      final sevA = _effectiveSeverity(a).index;
      final sevB = _effectiveSeverity(b).index;
      if (sevA != sevB) return sevB.compareTo(sevA);
      return (b.isInWalkingPath ? 1 : 0).compareTo(a.isInWalkingPath ? 1 : 0);
    });

    final overallSeverity = hazardObservations.isEmpty
        ? (degradedMode ? HazardSeverity.caution : HazardSeverity.info)
        : _effectiveSeverity(hazardObservations.first);

    final advisory = _composeAdvisory(
      now: now,
      observations: hazardObservations,
      degradedMode: degradedMode,
      degradationReasons: degradationReasons,
    );

    final policyNotes = <String>[
      'Openetra evaluates object confidence separately from hazard risk.',
      if (calibratedDepthConfidence == null)
        'Calibrated physical distance sensor is inactive; only image-relative position is reported.',
      if (degradedMode)
        'Degraded observation state: ${degradationReasons.join(", ")}.',
    ];

    return HazardAssessment(
      assessmentId: _uuid.v4(),
      timestamp: now,
      overallSeverity: overallSeverity,
      observations: hazardObservations,
      degradedModeActive: degradedMode,
      spokenAdvisory: advisory,
      policyNotes: policyNotes,
      degradationReasons: degradationReasons,
    );
  }

  static bool _isInWalkingPath(BoundingBox box, HazardCategory category) {
    final centerOverlap = box.x2 > 220 && box.x1 < 780;
    if (!centerOverlap) return false;
    if (category == HazardCategory.verticalOverhead) {
      return box.y2 > 180 && box.y1 < 650;
    }
    return box.y2 > 420 || box.areaRatio > 0.08;
  }

  static double _computeSpatialConfidence(BoundingBox box, bool inPath) {
    double base = inPath ? 0.80 : 0.55;
    if (box.areaRatio < 0.01) base -= 0.15;
    if (box.areaRatio > 0.12) base += 0.10;
    return base.clamp(0.30, 0.95);
  }

  HazardSeverity _effectiveSeverity(HazardObservation h) {
    if (h.category == HazardCategory.fireSmokeGlassWarning &&
        h.confidenceBreakdown.detectionConfidence >= 0.45) {
      return HazardSeverity.critical;
    }
    if (h.isApproaching && h.isInWalkingPath) {
      return HazardSeverity.critical;
    }
    if (h.isInWalkingPath &&
        (h.category == HazardCategory.traffic ||
            h.category == HazardCategory.elevationChange ||
            h.category == HazardCategory.groundLevel ||
            h.category == HazardCategory.verticalOverhead)) {
      return HazardSeverity.warning;
    }
    return HazardSeverity.caution;
  }

  String _composeAdvisory({
    required DateTime now,
    required List<HazardObservation> observations,
    required bool degradedMode,
    required List<String> degradationReasons,
  }) {
    final buffer = StringBuffer();
    if (degradedMode) {
      buffer.write(
        'Caution: visibility or scanning is degraded (${degradationReasons.join(", ")}). ',
      );
    }

    if (observations.isEmpty) {
      buffer.write(
        'No obvious hazards detected in the camera view; continue using your white cane and caution.',
      );
      return buffer.toString().trim();
    }

    final spokenAlerts = <String>[];
    for (final h in observations.take(3)) {
      final sev = _effectiveSeverity(h);
      final key = '${h.category.name}:${h.label}:${h.relativePosition.horizontal.name}';
      final cached = _cooldownCache[key];
      final withinCooldown = cached != null &&
          now.difference(cached.spokenAt) < alertCooldown &&
          sev.index <= cached.severity.index;
      if (!withinCooldown || observations.length == 1) {
        _cooldownCache[key] = (spokenAt: now, severity: sev);
        final prefix = switch (sev) {
          HazardSeverity.critical => 'Urgent warning:',
          HazardSeverity.warning => 'Caution:',
          HazardSeverity.caution => 'Notice:',
          HazardSeverity.info => 'Info:',
        };
        final looming = h.isApproaching ? ', appearing closer' : '';
        final uncertain = h.confidenceBreakdown.detectionConfidence < 0.45
            ? 'possible '
            : '';
        spokenAlerts.add(
          '$prefix $uncertain${h.label} in the ${h.relativePosition.toSpokenPhrase()}$looming',
        );
      }
    }

    if (spokenAlerts.isEmpty) {
      final top = observations.first;
      spokenAlerts.add(
        'Ongoing hazard in view: ${top.label} in the ${top.relativePosition.toSpokenPhrase()}',
      );
    }

    buffer.write('${spokenAlerts.join(". ")}.');
    return buffer.toString().trim();
  }
}
