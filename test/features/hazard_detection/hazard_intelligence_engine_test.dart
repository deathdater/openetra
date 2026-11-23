import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/features/hazard_detection/domain/hazard_intelligence_engine.dart';

VisionObservation _makeObs({
  required List<ObjectDetection> objects,
  List<PerceivedTextSpan> texts = const [],
  ImageQualityMetrics quality = ImageQualityMetrics.nominal,
  DateTime? timestamp,
}) {
  return VisionObservation(
    provenance: ObservationProvenance(
      observationId: 'obs-1',
      timestamp: timestamp ?? DateTime(2026, 11, 23, 10, 0, 0),
      modelId: 'cactus-mirage-2bit',
      modelVersion: '4.1.4',
      confidence: 0.75,
      inputWidth: 640,
      inputHeight: 480,
      processingDurationMs: 120,
      sourceCapability: 'mirage_describe',
      validationStatus: quality.isDegraded
          ? ValidationStatus.degraded
          : ValidationStatus.verified,
    ),
    imageQuality: quality,
    objects: objects,
    textSpans: texts,
  );
}

void main() {
  test('evaluates all 5 hazard categories + warning signs with separated confidences', () {
    final engine = HazardIntelligenceEngine(
      clock: () => DateTime(2026, 11, 23, 10, 0, 0),
    );

    final obs = _makeObs(
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'pothole',
          boundingBox: BoundingBox(x1: 350, y1: 680, x2: 650, y2: 920),
          confidence: 0.70,
        ),
        ObjectDetection(
          entityId: 2,
          name: 'low branch',
          boundingBox: BoundingBox(x1: 380, y1: 120, x2: 640, y2: 320),
          confidence: 0.62,
        ),
        ObjectDetection(
          entityId: 3,
          name: 'stairs',
          boundingBox: BoundingBox(x1: 300, y1: 500, x2: 700, y2: 850),
          confidence: 0.80,
        ),
        ObjectDetection(
          entityId: 4,
          name: 'car',
          boundingBox: BoundingBox(x1: 250, y1: 420, x2: 520, y2: 720),
          confidence: 0.85,
        ),
        ObjectDetection(
          entityId: 5,
          name: 'glass door',
          boundingBox: BoundingBox(x1: 400, y1: 300, x2: 700, y2: 900),
          confidence: 0.58,
          attributes: [ObjectAttribute(key: 'material', value: 'glass')],
        ),
      ],
      texts: const [
        PerceivedTextSpan(
          text: 'DANGER HIGH VOLTAGE',
          boundingBox: BoundingBox(x1: 420, y1: 350, x2: 600, y2: 430),
          confidence: 0.88,
        ),
      ],
    );

    final assessment = engine.evaluate(obs);
    final categories = assessment.observations.map((o) => o.category).toSet();

    expect(categories, containsAll(HazardCategory.values));
    expect(assessment.overallSeverity, HazardSeverity.critical);
    for (final h in assessment.observations) {
      // No calibrated depth provided -> distanceConfidence must stay null.
      expect(h.confidenceBreakdown.distanceConfidence, isNull);
      expect(h.confidenceBreakdown.detectionConfidence, inInclusiveRange(0.25, 1.0));
      expect(h.confidenceBreakdown.temporalPersistenceScore, inInclusiveRange(0.25, 1.0));
    }
  });

  test('IoUTracker tracks persistent looming object across consecutive frames', () {
    var clockTime = DateTime(2026, 11, 23, 10, 0, 0);
    final engine = HazardIntelligenceEngine(clock: () => clockTime);

    final frame1 = _makeObs(
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'motorcycle',
          boundingBox: BoundingBox(x1: 420, y1: 460, x2: 580, y2: 660),
          confidence: 0.72,
        ),
      ],
    );
    final res1 = engine.evaluate(frame1);
    expect(res1.observations.single.consecutiveFrames, 1);
    expect(res1.observations.single.isApproaching, isFalse);

    clockTime = clockTime.add(const Duration(seconds: 1));
    final frame2 = _makeObs(
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'motorcycle',
          boundingBox: BoundingBox(x1: 380, y1: 420, x2: 620, y2: 740),
          confidence: 0.78,
        ),
      ],
    );
    final res2 = engine.evaluate(frame2);
    expect(res2.observations.single.trackId, res1.observations.single.trackId);
    expect(res2.observations.single.consecutiveFrames, 2);
    expect(res2.observations.single.isApproaching, isTrue);
    expect(res2.overallSeverity, HazardSeverity.critical);
    expect(res2.spokenAdvisory, contains('appearing closer'));
  });

  test('explicitly discloses degraded visibility and never claims empty scene is safe', () {
    final engine = HazardIntelligenceEngine();
    const darkBlurry = ImageQualityMetrics(
      meanLuma: 15.0,
      lumaStdDev: 4.0,
      laplacianVariance: 18.0,
      overexposedRatio: 0.0,
      underexposedRatio: 0.85,
    );

    final assessment = engine.evaluate(_makeObs(objects: const [], quality: darkBlurry));
    expect(assessment.degradedModeActive, isTrue);
    expect(assessment.degradationReasons, containsAll(['low lighting', 'camera blur or motion']));
    expect(assessment.spokenAdvisory, contains('degraded'));
    expect(assessment.spokenAdvisory, contains('white cane'));
    expect(assessment.spokenAdvisory.toLowerCase(), isNot(contains('obstacle-free')));
    expect(assessment.spokenAdvisory.toLowerCase(), isNot(contains('safe to cross')));
  });
}
