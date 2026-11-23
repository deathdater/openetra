import 'package:uuid/uuid.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/localization/openetra_localizer.dart';

/// Workflow E: Offline Indian currency recognition fusing optional LiteRT
/// banknote classifier, Mirage constrained `form` probability, and Mirage OCR
/// printed numeral cross-check. Never uses color alone and never claims
/// counterfeit authentication.
class CurrencyRecognitionService {
  const CurrencyRecognitionService({this.classifier});

  final CurrencyClassifierProvider? classifier;
  static const _uuid = Uuid();

  static const String nonCounterfeitDisclaimer =
      'Openetra cannot verify whether a currency note is genuine or counterfeit.';

  static const Map<String, dynamic> mirageCurrencyFormSchema = {
    'denomination': {
      'enum': ['10', '20', '50', '100', '200', '500', 'none'],
    },
  };

  static const Set<int> _validDenominations = {10, 20, 50, 100, 200, 500};

  Future<CurrencyRecognitionResult> identify({
    required CapturedFrame frame,
    required VisionObservation mirageObservation,
    VisionObservation? formObservation,
    String locale = 'en-IN',
  }) async {
    final disclaimer = OpenetraLocalizer.currencyNonCounterfeitDisclaimer(locale);
    if (frame.qualityMetrics.isDegraded) {
      final reasons = frame.qualityMetrics.degradationReasons.join(' and ');
      final msg = OpenetraLocalizer.langCode(locale) == 'en'
          ? 'Image quality is too poor to read the currency note due to $reasons. Please improve lighting and hold steady. $disclaimer'
          : '${OpenetraLocalizer.degradedNotice(frame.qualityMetrics.degradationReasons, locale)} $disclaimer';
      return CurrencyRecognitionResult(
        provenance: mirageObservation.provenance,
        denomination: InrDenomination.uncertain,
        classifierConfidence: 0.0,
        ocrMatchedValue: null,
        isUncertain: true,
        spokenAdvisory: msg,
        nonCounterfeitDisclaimer: disclaimer,
      );
    }

    final ocrNumeral = _extractDenominationFromOcr(mirageObservation.textSpans);
    final formPick = _extractFromMirageForm(formObservation?.formResult);

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

    // Fuse Mirage constrained form if dedicated LiteRT classifier is not installed.
    if (bestDenom == InrDenomination.uncertain && formPick != null) {
      final formDenom = formPick.denomination;
      final formProb = formPick.probability;
      if (formDenom != InrDenomination.uncertain && formProb >= 0.55) {
        final disagreesWithOcr =
            ocrNumeral != null && ocrNumeral != formDenom.value;
        if (disagreesWithOcr) {
          return CurrencyRecognitionResult(
            provenance: formObservation!.provenance,
            denomination: InrDenomination.uncertain,
            classifierConfidence: formProb,
            ocrMatchedValue: ocrNumeral,
            isUncertain: true,
            spokenAdvisory:
                'Uncertain result: visual form suggests ${formDenom.spokenLabel}, '
                'but printed numeral looks like $ocrNumeral. Flip the note and scan again. $disclaimer',
            nonCounterfeitDisclaimer: disclaimer,
          );
        }
        final uncertain = ocrNumeral == null || formProb < 0.75;
        return CurrencyRecognitionResult(
          provenance: formObservation!.provenance,
          denomination: formDenom,
          classifierConfidence: formProb,
          ocrMatchedValue: ocrNumeral,
          isUncertain: uncertain,
          spokenAdvisory: OpenetraLocalizer.currencyIdentified(
            formDenom,
            (formProb * 100).round(),
            ocrNumeral,
            locale,
          ),
          nonCounterfeitDisclaimer: disclaimer,
        );
      }
    }

    // Cross-validate specialist classifier vs OCR numeral evidence.
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
        spokenAdvisory: OpenetraLocalizer.langCode(locale) == 'en'
            ? 'Printed numeral ${bestDenom.spokenLabel} detected via text check, '
                'without dedicated banknote classifier confirmation. Flip or flatten the note to double check. $disclaimer'
            : OpenetraLocalizer.currencyIdentified(
                bestDenom,
                (ocrConfidence * 100).round(),
                ocrNumeral,
                locale,
              ),
        nonCounterfeitDisclaimer: disclaimer,
      );
    }

    if (bestDenom == InrDenomination.uncertain || bestScore < 0.65) {
      return CurrencyRecognitionResult(
        provenance: mirageObservation.provenance,
        denomination: InrDenomination.uncertain,
        classifierConfidence: bestScore,
        ocrMatchedValue: ocrNumeral,
        isUncertain: true,
        spokenAdvisory:
            OpenetraLocalizer.currencyUncertain(locale, ocrValue: ocrNumeral),
        nonCounterfeitDisclaimer: disclaimer,
      );
    }

    final disagreesWithOcr =
        ocrNumeral != null && ocrNumeral != bestDenom.value;
    final uncertain = disagreesWithOcr || bestScore < 0.80;
    final advisory = disagreesWithOcr
        ? 'Uncertain result: visual classifier suggests ${bestDenom.spokenLabel}, '
            'but printed number looks like $ocrNumeral. Flip the note and scan again. $disclaimer'
        : OpenetraLocalizer.currencyIdentified(
            bestDenom,
            (bestScore * 100).round(),
            ocrNumeral,
            locale,
          );

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
      nonCounterfeitDisclaimer: disclaimer,
    );
  }

  static ({InrDenomination denomination, double probability})? _extractFromMirageForm(
    Map<String, dynamic>? formResult,
  ) {
    if (formResult == null || formResult.isEmpty) return null;
    final entry = formResult['denomination'];
    if (entry is! Map) return null;
    final valueStr = entry['value']?.toString();
    final parsed = int.tryParse(valueStr ?? '');
    if (parsed == null || !_validDenominations.contains(parsed)) {
      return null;
    }
    double prob = 0.6;
    final probs = entry['probabilities'];
    if (probs is Map && probs[valueStr] is num) {
      prob = (probs[valueStr] as num).toDouble().clamp(0.0, 1.0);
    }
    final denom = InrDenomination.values.firstWhere(
      (d) => d.value == parsed,
      orElse: () => InrDenomination.uncertain,
    );
    return (denomination: denom, probability: prob);
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
