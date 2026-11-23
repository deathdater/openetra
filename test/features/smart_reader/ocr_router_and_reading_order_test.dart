import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/ai_model_orchestrator.dart';
import 'package:openetra/core/inference/ai_model_registry.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/inference/unloaded_vision_provider.dart';
import 'package:openetra/core/resource_management/device_resource_manager.dart';
import 'package:openetra/features/smart_reader/domain/ocr_router.dart';
import 'package:openetra/features/smart_reader/domain/reading_order_reconstructor.dart';
import 'package:openetra/features/smart_reader/domain/script_detector.dart';

class _FakeHindiOcrProvider implements OcrProvider {
  @override
  String get providerId => 'ppocrv5-devanagari-mobile';

  @override
  List<DetectedScript> get supportedScripts => [DetectedScript.devanagari];

  @override
  Future<bool> isPackInstalled(DetectedScript script) async =>
      script == DetectedScript.devanagari;

  @override
  Future<TextRecognitionResult> recognize(
    CapturedFrame frame, {
    required DetectedScript targetScript,
    required String targetLocale,
  }) async {
    return TextRecognitionResult(
      provenance: ObservationProvenance(
        observationId: 'indic-1',
        timestamp: DateTime(2026, 11, 23),
        modelId: providerId,
        modelVersion: '1.0',
        confidence: 0.91,
        inputWidth: frame.width,
        inputHeight: frame.height,
        processingDurationMs: 85,
        sourceCapability: 'indic_ocr',
        validationStatus: ValidationStatus.verified,
      ),
      detectedScript: DetectedScript.devanagari,
      orderedLines: const [
        TextLineObservation(
          text: 'बाहर',
          boundingBox: BoundingBox(x1: 300, y1: 100, x2: 500, y2: 160),
          confidence: 0.91,
          script: DetectedScript.devanagari,
        ),
        TextLineObservation(
          text: 'निकास',
          boundingBox: BoundingBox(x1: 100, y1: 105, x2: 260, y2: 162),
          confidence: 0.92,
          script: DetectedScript.devanagari,
        ),
      ],
      fullText: 'निकास बाहर',
      targetLocale: targetLocale,
      engineUsed: providerId,
    );
  }
}

void main() {
  const detector = ScriptDetector();
  const reconstructor = ReadingOrderReconstructor();

  test('detects Latin and all 7 target Indic scripts plus mixed script text', () {
    expect(detector.detectFromText('Exit Pharmacy'), DetectedScript.latin);
    expect(detector.detectFromText('दवाखाना खुले है'), DetectedScript.devanagari);
    expect(detector.detectFromText('ಬೆಂಗಳೂರು ಮೆಟ್ರೋ'), DetectedScript.kannada);
    expect(detector.detectFromText('சென்னை மெட்ரோ'), DetectedScript.tamil);
    expect(detector.detectFromText('హైదరాబాద్'), DetectedScript.telugu);
    expect(detector.detectFromText('കൊച്ചി'), DetectedScript.malayalam);
    expect(detector.detectFromText('কলকাতা'), DetectedScript.bengali);
    expect(detector.detectFromText('Exit बाहर'), DetectedScript.mixed);
  });

  test('reconstructs top-to-bottom left-to-right reading order across rows', () {
    const shuffled = [
      TextLineObservation(
        text: 'Second Row',
        boundingBox: BoundingBox(x1: 50, y1: 220, x2: 240, y2: 270),
        confidence: 0.9,
        script: DetectedScript.latin,
      ),
      TextLineObservation(
        text: 'World',
        boundingBox: BoundingBox(x1: 200, y1: 62, x2: 340, y2: 112),
        confidence: 0.9,
        script: DetectedScript.latin,
      ),
      TextLineObservation(
        text: 'Hello',
        boundingBox: BoundingBox(x1: 40, y1: 60, x2: 160, y2: 110),
        confidence: 0.9,
        script: DetectedScript.latin,
      ),
    ];

    final sorted = reconstructor.sort(shuffled);
    expect(sorted.map((l) => l.text).toList(), ['Hello', 'World', 'Second Row']);
  });

  test('OcrRouter routes Devanagari to installed Indic provider and discloses missing Kannada pack', () async {
    final orchestrator = AIModelOrchestrator(
      registry: AIModelRegistry(),
      resourceManager: DeviceResourceManager(),
      visionProvider: UnloadedVisionProvider(),
      indicOcrProviders: [_FakeHindiOcrProvider()],
    );
    final router = OcrRouter(orchestrator: orchestrator);

    final emptyMirageObs = VisionObservation(
      provenance: ObservationProvenance(
        observationId: 'm-1',
        timestamp: DateTime(2026, 11, 23),
        modelId: AIModelRegistry.mirageId,
        modelVersion: '4.1.4',
        confidence: 0.0,
        inputWidth: 640,
        inputHeight: 480,
        processingDurationMs: 90,
        sourceCapability: 'mirage_ocr',
        validationStatus: ValidationStatus.uncertain,
      ),
      imageQuality: ImageQualityMetrics.nominal,
    );
    final frame = CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics.nominal,
      rgbBytes: Uint8List(4),
    );

    final hiResult = await router.processObservation(
      mirageObservation: emptyMirageObs,
      targetLocale: 'hi-IN',
      rawFrame: frame,
    );
    expect(hiResult.packAvailable, isTrue);
    expect(hiResult.engineUsed, 'ppocrv5-devanagari-mobile');
    expect(hiResult.fullText, 'निकास बाहर');

    final knResult = await router.processObservation(
      mirageObservation: emptyMirageObs,
      targetLocale: 'kn-IN',
      rawFrame: frame,
    );
    expect(knResult.packAvailable, isFalse);
    expect(knResult.detectedScript, DetectedScript.kannada);
    expect(knResult.missingPackNotice, contains('kannada'));
  });
}
