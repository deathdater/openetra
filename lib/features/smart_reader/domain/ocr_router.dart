import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/ai_model_orchestrator.dart';
import '../../../core/inference/model_provider.dart';
import 'reading_order_reconstructor.dart';
import 'script_detector.dart';

/// Routes captured text to Mirage Latin OCR or an installed Indic OCR pack,
/// reconstructing reading order and cleanly disclosing missing offline packs.
class OcrRouter {
  const OcrRouter({
    required this.orchestrator,
    this.scriptDetector = const ScriptDetector(),
    this.readingOrder = const ReadingOrderReconstructor(),
  });

  final AIModelOrchestrator orchestrator;
  final ScriptDetector scriptDetector;
  final ReadingOrderReconstructor readingOrder;

  Future<TextRecognitionResult> processObservation({
    required VisionObservation mirageObservation,
    required String targetLocale,
    CapturedFrame? rawFrame,
  }) async {
    final expectedIndic = scriptDetector.expectedScriptForLocale(targetLocale);
    final mirageTextJoined =
        mirageObservation.textSpans.map((t) => t.text).join(' ');
    final detectedFromMirage = scriptDetector.detectFromText(mirageTextJoined);

    final targetScript = (mirageObservation.textSpans.isEmpty &&
            expectedIndic != DetectedScript.latin)
        ? expectedIndic
        : (detectedFromMirage == DetectedScript.unknown
            ? expectedIndic
            : detectedFromMirage);

    if (targetScript != DetectedScript.latin &&
        targetScript != DetectedScript.unknown) {
      final indicProvider = await orchestrator.selectOcrProvider(targetScript);
      if (indicProvider != null && rawFrame != null) {
        final indicRes = await indicProvider.recognize(
          rawFrame,
          targetScript: targetScript,
          targetLocale: targetLocale,
        );
        final ordered = readingOrder.sort(indicRes.orderedLines);
        return TextRecognitionResult(
          provenance: indicRes.provenance,
          detectedScript: targetScript,
          orderedLines: ordered,
          fullText: ordered.map((l) => l.text).join(' '),
          targetLocale: targetLocale,
          engineUsed: indicProvider.providerId,
          packAvailable: true,
        );
      }

      // Honest fallback when Indic OCR model pack is not yet provisioned locally.
      final mirageLines = readingOrder.sort(
        mirageObservation.textSpans
            .map((s) => TextLineObservation(
                  text: s.text,
                  boundingBox: s.boundingBox,
                  confidence: s.confidence,
                  script: scriptDetector.detectFromText(s.text),
                ))
            .toList(),
      );
      final latinNote = mirageLines.isEmpty
          ? 'No Latin text detected.'
          : mirageLines.map((l) => l.text).join(' ');
      return TextRecognitionResult(
        provenance: mirageObservation.provenance,
        detectedScript: targetScript,
        orderedLines: mirageLines,
        fullText: latinNote,
        targetLocale: targetLocale,
        engineUsed: mirageObservation.provenance.modelId,
        packAvailable: false,
        missingPackNotice:
            'Offline ${targetScript.name} OCR pack is not installed yet; Mirage supports Latin script only. Install the ${targetScript.name} pack in Model Manager.',
      );
    }

    final lines = readingOrder.sort(
      mirageObservation.textSpans
          .where((s) => s.text.trim().isNotEmpty)
          .map((s) => TextLineObservation(
                text: s.text.trim(),
                boundingBox: s.boundingBox,
                confidence: s.confidence,
                script: DetectedScript.latin,
              ))
          .toList(),
    );

    final lowConfidence =
        lines.isNotEmpty && lines.every((l) => l.confidence < 0.45);
    final rawJoined = lines.map((l) => l.text).join(' ');
    final spoken = lowConfidence
        ? 'Low-confidence text reading: $rawJoined'
        : rawJoined;

    return TextRecognitionResult(
      provenance: mirageObservation.provenance,
      detectedScript: DetectedScript.latin,
      orderedLines: lines,
      fullText: spoken,
      targetLocale: targetLocale,
      engineUsed: mirageObservation.provenance.modelId,
      packAvailable: true,
    );
  }
}
