import 'package:uuid/uuid.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';

/// Workflow E: Offline Indian currency recognition combining a compact
/// classifier interface with Mirage OCR numeral evidence. Never uses color
/// alone and never claims counterfeit authentication.
class CurrencyRecognitionService {
  const CurrencyRecognitionService({this.classifier});

  final CurrencyClassifierProvider? classifier;
  static const _uuid = Uuid();

  static const String nonCounterfeitDisclaimer =
      'Openetra cannot verify whether a currency note is genuine or counterfeit.';

  static const Set<int> _validDenominations = {10, 20, 50, 100, 200, 500};

  Future<CurrencyRecognitionResult> identify({
    required CapturedFrame frame,
    required VisionObservation mirageObservation,
  }) async {
    if (frame.qualityMetrics.isDegraded) {
      final reasons = frame.qualityMetrics.degradationReasons.join(' and ');
      return CurrencyRecognitionResult(
        provenance: mirageObservation.provenance,
        denomination: InrDenomination.uncertain,
        classifierConfidence: 0.0,
        ocrMatchedValue: null,
        isUncertain: true,
        spokenAdvisory:
            'Image quality is too poor to read the currency note due to $reasons. Please improve lighting and hold steady. $nonCounterfeitDisclaimer',
        nonCounterfeitDisclaimer: nonCounterfeitDisclaimer,
      );
    }

    final ocrNumeral = _extractDenominationFromOcr(mirageObservation.textSpans);
    Map<InrDenomination, double> scores = const {};
    String sourceModel = mirageObservation.provenance.modelId;

    if (classifier != null && await classifier!.isAvailable) {
      scores = await classifier!.classifyNote(frame);
      sourceModel = classifier!.modelId;
    }

    InrDenomination bestDenom = InrDenomination.uncertain;
    double bestScore = 0.0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestDenom = entry.key;
      }
    }

    // Cross-validate specialist classifier with OCR numeral evidence.
    if (bestDenom == InrDenomination.uncertain && ocrNumeral != null) {
      bestDenom = InrDenomination.values.firstWhere(
        (d) => d.value == ocrNumeral,
        orElse: () => InrDenomination.uncertain,
      );
      final ocrConfidence = mirageObservation.textSpans
          .map((t) => t.confidence)
          .fold<double>(0.0, (a, b) => a > b ? a : b);
      return CurrencyRecognitionResult(
        provenance: ObservationProvenance(
          observationId: _uuid.v4(),
          timestamp: DateTime.now(),
          modelId: sourceModel,
          modelVersion: mirageObservation.provenance.modelVersion,
          confidence: ocrConfidence,
          inputWidth: frame.width,
          inputHeight: frame.height,
          processingDurationMs:
              mirageObservation.provenance.processingDurationMs,
          sourceCapability: 'currency_ocr_crosscheck',
          validationStatus: ocrConfidence >= 0.6
              ? ValidationStatus.provisional
              : ValidationStatus.uncertain,
        ),
        denomination: bestDenom,
        classifierConfidence: ocrConfidence,
        ocrMatchedValue: ocrNumeral,
        isUncertain: true,
        spokenAdvisory:
            'Printed numeral ${bestDenom.spokenLabel} detected via text check, '
            'without dedicated banknote classifier confirmation. Flip or flatten the note to double check. $nonCounterfeitDisclaimer',
        nonCounterfeitDisclaimer: nonCounterfeitDisclaimer,
      );
    }

    if (bestDenom == InrDenomination.uncertain || bestScore < 0.65) {
      final hint = ocrNumeral != null
          ? ' Text numeral $ocrNumeral was spotted, though confidence is low.'
          : '';
      return CurrencyRecognitionResult(
        provenance: mirageObservation.provenance,
        denomination: InrDenomination.uncertain,
        classifierConfidence: bestScore,
        ocrMatchedValue: ocrNumeral,
        isUncertain: true,
        spokenAdvisory:
            'Unable to identify the currency denomination confidently.$hint Hold the note flat in good light and try again. $nonCounterfeitDisclaimer',
        nonCounterfeitDisclaimer: nonCounterfeitDisclaimer,
      );
    }

    final disagreesWithOcr =
        ocrNumeral != null && ocrNumeral != bestDenom.value;
    final uncertain = disagreesWithOcr || bestScore < 0.80;
    final advisory = disagreesWithOcr
        ? 'Uncertain result: visual classifier suggests ${bestDenom.spokenLabel}, '
            'but printed number looks like $ocrNumeral. Flip the note and scan again. $nonCounterfeitDisclaimer'
        : 'This appears to be a ${bestDenom.spokenLabel} note '
            '(${(bestScore * 100).round()}% confidence'
            '${ocrNumeral != null ? ', confirmed by printed number $ocrNumeral' : ''}). '
            '$nonCounterfeitDisclaimer';

    return CurrencyRecognitionResult(
      provenance: ObservationProvenance(
        observationId: _uuid.v4(),
        timestamp: DateTime.now(),
        modelId: sourceModel,
        modelVersion: '1.0',
        confidence: bestScore,
        inputWidth: frame.width,
        inputHeight: frame.height,
        processingDurationMs: mirageObservation.provenance.processingDurationMs,
        sourceCapability: 'currency_classification',
        validationStatus: uncertain
            ? ValidationStatus.uncertain
            : ValidationStatus.verified,
      ),
      denomination: bestDenom,
      classifierConfidence: bestScore,
      ocrMatchedValue: ocrNumeral,
      isUncertain: uncertain,
      spokenAdvisory: advisory,
      nonCounterfeitDisclaimer: nonCounterfeitDisclaimer,
    );
  }

  static int? _extractDenominationFromOcr(List<PerceivedTextSpan> spans) {
    final regex = RegExp(r'\b(10|20|50|100|200|500)\b');
    for (final span in spans) {
      final matches = regex.allMatches(span.text);
      for (final m in matches) {
        final parsed = int.tryParse(m.group(1) ?? '');
        if (parsed != null && _validDenominations.contains(parsed)) {
          return parsed;
        }
      }
    }
    return null;
  }
}
