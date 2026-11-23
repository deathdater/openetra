import '../domain/entities/entities.dart';

/// Direct native trilingual localization for English (en-IN), Hindi (hi-IN),
/// and Kannada (kn-IN). Safety advisories and core guidance are authored
/// directly per language rather than routed through multi-stage translation.
class OpenetraLocalizer {
  const OpenetraLocalizer();

  static String langCode(String locale) {
    final lower = locale.toLowerCase();
    if (lower.startsWith('hi')) return 'hi';
    if (lower.startsWith('kn')) return 'kn';
    return 'en';
  }

  static String relativePosition(RelativePosition pos, String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      final h = switch (pos.horizontal) {
        HorizontalZone.farLeft => 'बाईं ओर दूर',
        HorizontalZone.left => 'बाईं ओर',
        HorizontalZone.center => 'सामने बीच में',
        HorizontalZone.right => 'दाईं ओर',
        HorizontalZone.farRight => 'दाईं ओर दूर',
      };
      final v = switch (pos.vertical) {
        VerticalZone.overhead => 'ऊपर',
        VerticalZone.middle => '',
        VerticalZone.groundLevel => 'पास नीचे',
      };
      return v.isEmpty ? h : '$h ($v)';
    }
    if (lang == 'kn') {
      final h = switch (pos.horizontal) {
        HorizontalZone.farLeft => 'ಎಡಭಾಗದ ತುದಿಯಲ್ಲಿ',
        HorizontalZone.left => 'ಎಡಭಾಗದಲ್ಲಿ',
        HorizontalZone.center => 'ಮುಂದೆ ಮಧ್ಯಭಾಗದಲ್ಲಿ',
        HorizontalZone.right => 'ಬಲಭಾಗದಲ್ಲಿ',
        HorizontalZone.farRight => 'ಬಲಭಾಗದ ತುದಿಯಲ್ಲಿ',
      };
      final v = switch (pos.vertical) {
        VerticalZone.overhead => 'ಮೇಲ್ಭಾಗದಲ್ಲಿ',
        VerticalZone.middle => '',
        VerticalZone.groundLevel => 'ಹತ್ತಿರ ಕೆಳಭಾಗದಲ್ಲಿ',
      };
      return v.isEmpty ? h : '$h ($v)';
    }
    return pos.toSpokenPhrase();
  }

  static String severityPrefix(HazardSeverity severity, String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      return switch (severity) {
        HazardSeverity.critical => 'तत्काल चेतावनी:',
        HazardSeverity.warning => 'सावधान:',
        HazardSeverity.caution => 'ध्यान दें:',
        HazardSeverity.info => 'सूचना:',
      };
    }
    if (lang == 'kn') {
      return switch (severity) {
        HazardSeverity.critical => 'ತುರ್ತು ಎಚ್ಚರಿಕೆ:',
        HazardSeverity.warning => 'ಎಚ್ಚರಿಕೆ:',
        HazardSeverity.caution => 'ಗಮನಿಸಿ:',
        HazardSeverity.info => 'ಮಾಹಿತಿ:',
      };
    }
    return switch (severity) {
      HazardSeverity.critical => 'Urgent warning:',
      HazardSeverity.warning => 'Caution:',
      HazardSeverity.caution => 'Notice:',
      HazardSeverity.info => 'Info:',
    };
  }

  static String degradedNotice(List<String> reasons, String locale) {
    final lang = langCode(locale);
    final reasonStr = reasons.join(', ');
    if (lang == 'hi') {
      return 'सावधान: दृश्य गुणवत्ता या स्कैनिंग सीमित है ($reasonStr)।';
    }
    if (lang == 'kn') {
      return 'ಎಚ್ಚರಿಕೆ: ದೃಶ್ಯ ಸ್ಪಷ್ಟತೆ ಅಥವಾ ಸ್ಕ್ಯಾನಿಂಗ್ ಸೀಮಿತವಾಗಿದೆ ($reasonStr).';
    }
    return 'Caution: visibility or scanning is degraded ($reasonStr).';
  }

  static String noHazardsAdvisory(String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      return 'कैमरे के सामने कोई स्पष्ट खतरा नहीं दिखा; कृपया अपनी सफेद छड़ी और सावधानी का उपयोग जारी रखें।';
    }
    if (lang == 'kn') {
      return 'ಕ್ಯಾಮೆರಾ ನೋಟದಲ್ಲಿ ಸ್ಪಷ್ಟ ಅಪಾಯ ಕಂಡುಬಂದಿಲ್ಲ; ದಯವಿಟ್ಟು ನಿಮ್ಮ ಬಿಳಿ ಕೋಲು ಮತ್ತು ಎಚ್ಚರಿಕೆಯನ್ನು ಬಳಸುವುದನ್ನು ಮುಂದುವರಿಸಿ.';
    }
    return 'No obvious hazards detected in the camera view; continue using your white cane and caution.';
  }

  static String hazardObservationPhrase(
    HazardObservation obs,
    HazardSeverity sev,
    String locale,
  ) {
    final lang = langCode(locale);
    final prefix = severityPrefix(sev, locale);
    final pos = relativePosition(obs.relativePosition, locale);
    final lowConf = obs.confidenceBreakdown.detectionConfidence < 0.45;

    if (lang == 'hi') {
      final approaching = obs.isApproaching ? ', पास आ रहा है' : '';
      final unc = lowConf ? 'संभावित ' : '';
      return '$prefix $unc${obs.label} $pos$approaching';
    }
    if (lang == 'kn') {
      final approaching = obs.isApproaching ? ', ಹತ್ತಿರ ಬರುತ್ತಿದೆ' : '';
      final unc = lowConf ? 'ಸಂಭಾವ್ಯ ' : '';
      return '$prefix $unc${obs.label} $pos$approaching';
    }
    final approaching = obs.isApproaching ? ', appearing closer' : '';
    final unc = lowConf ? 'possible ' : '';
    return '$prefix $unc${obs.label} in the $pos$approaching';
  }

  static String safetyCrossingReplacement(String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      return 'सड़क पार करने की सुरक्षा की पुष्टि नहीं की जा सकती—कृपया अपनी गतिशीलता प्रशिक्षण और यातायात संकेतों पर भरोसा करें';
    }
    if (lang == 'kn') {
      return 'ರಸ್ತೆ ದಾಟುವ ಸುರಕ್ಷತೆಯನ್ನು ದೃಢೀಕರಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ—ದಯವಿಟ್ಟು ನಿಮ್ಮ ಚಲನಶೀಲತಾ ತರಬೇತಿ ಮತ್ತು ಸಂಚಾರ ಶಬ್ದಗಳನ್ನು ಅವಲಂಬಿಸಿ';
    }
    return 'cannot confirm crossing safety—rely on mobility training and traffic cues';
  }

  static String safetyClearPathReplacement(String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      return 'कैमरे में कोई स्पष्ट बाधा नहीं दिखी; कृपया अपनी सफेद छड़ी का उपयोग जारी रखें';
    }
    if (lang == 'kn') {
      return 'ಕ್ಯಾಮೆರಾದಲ್ಲಿ ಸ್ಪಷ್ಟ ಅಡಚಣೆ ಕಂಡುಬಂದಿಲ್ಲ; ದಯವಿಟ್ಟು ನಿಮ್ಮ ಬಿಳಿ ಕೋಲನ್ನು ಬಳಸುವುದನ್ನು ಮುಂದುವರಿಸಿ';
    }
    return 'no obvious hazards detected in the camera view; continue using your white cane';
  }

  static String safetyDistanceReplacement(String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') return 'कैमरे के दृश्य में पास';
    if (lang == 'kn') return 'ಕ್ಯಾಮೆರಾ ನೋಟದಲ್ಲಿ ಹತ್ತಿರ';
    return 'in camera view';
  }

  static String currencyNonCounterfeitDisclaimer(String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      return 'ओपननेत्रा यह जांच नहीं कर सकता कि नोट असली है या नकली।';
    }
    if (lang == 'kn') {
      return 'ನೋಟು ಅಸಲಿಯೇ ಅಥವಾ ನಕಲಿಯೇ ಎಂಬುದನ್ನು ಓಪನ್‌ನೆಟ್ರಾ ಪರಿಶೀಲಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ.';
    }
    return 'Openetra cannot verify whether a currency note is genuine or counterfeit.';
  }

  static String currencyIdentified(
    InrDenomination denom,
    int confidencePct,
    int? ocrValue,
    String locale,
  ) {
    final lang = langCode(locale);
    final disclaimer = currencyNonCounterfeitDisclaimer(locale);
    if (lang == 'hi') {
      final ocrNote = ocrValue != null ? ', अंक $ocrValue की पुष्टि के साथ' : '';
      return 'यह ${denom.value} रुपये का नोट प्रतीत होता है ($confidencePct% विश्वास$ocrNote)। $disclaimer';
    }
    if (lang == 'kn') {
      final ocrNote = ocrValue != null ? ', ಮುದ್ರಿತ ಸಂಖ್ಯೆ $ocrValue ದೃಢೀಕರಣದೊಂದಿಗೆ' : '';
      return 'ಇದು ${denom.value} ರೂಪಾಯಿ ನೋಟು ಎಂದು ತೋರುತ್ತದೆ ($confidencePct% ವಿಶ್ವಾಸ$ocrNote). $disclaimer';
    }
    final ocrNote = ocrValue != null ? ', confirmed by printed number $ocrValue' : '';
    return 'This appears to be a ${denom.spokenLabel} note ($confidencePct% confidence$ocrNote). $disclaimer';
  }

  static String currencyUncertain(String locale, {int? ocrValue}) {
    final lang = langCode(locale);
    final disclaimer = currencyNonCounterfeitDisclaimer(locale);
    if (lang == 'hi') {
      final hint = ocrValue != null ? ' अंक $ocrValue दिखा, पर विश्वास कम है।' : '';
      return 'नोट का मूल्य स्पष्ट रूप से पहचाना नहीं जा सका।$hint नोट को सीधा रखकर अच्छी रोशनी में दोबारा प्रयास करें। $disclaimer';
    }
    if (lang == 'kn') {
      final hint = ocrValue != null ? ' ಸಂಖ್ಯೆ $ocrValue ಕಂಡರೂ ವಿಶ್ವಾಸ ಕಡಿಮೆಯಿದೆ.' : '';
      return 'ನೋಟಿನ ಮೌಲ್ಯವನ್ನು ಖಚಿತವಾಗಿ ಗುರುತಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.$hint ನೋಟನ್ನು ನೇರವಾಗಿ ಹಿಡಿದು ಉತ್ತಮ ಬೆಳಕಿನಲ್ಲಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ. $disclaimer';
    }
    final hint = ocrValue != null
        ? ' Text numeral $ocrValue was spotted, though confidence is low.'
        : '';
    return 'Unable to identify the currency denomination confidently.$hint Hold the note flat in good light and try again. $disclaimer';
  }

  static String sceneIntro({
    required String environment,
    String? surface,
    String? lighting,
    required String locale,
  }) {
    final lang = langCode(locale);
    if (lang == 'hi') {
      final surf = (surface != null && surface.isNotEmpty) ? ', सतह $surface' : '';
      final light = (lighting != null && lighting.isNotEmpty) ? ', रोशनी $lighting' : '';
      return 'यह दृश्य $environment जैसा प्रतीत होता है$surf$light।';
    }
    if (lang == 'kn') {
      final surf = (surface != null && surface.isNotEmpty) ? ', ನೆಲ $surface' : '';
      final light = (lighting != null && lighting.isNotEmpty) ? ', ಬೆಳಕು $lighting' : '';
      return 'ಈ ದೃಶ್ಯ $environment ನಂತೆ ತೋರುತ್ತದೆ$surf$light.';
    }
    final surf = (surface != null && surface.isNotEmpty) ? ' on a $surface surface' : '';
    final light = (lighting != null && lighting.isNotEmpty) ? ' with $lighting lighting' : '';
    return 'You appear to be in a $environment$surf$light.';
  }

  static String sceneItemsLead(String itemsSummary, String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') return 'मुख्य वस्तुएं: $itemsSummary।';
    if (lang == 'kn') return 'ಪ್ರಮುಖ ವಸ್ತುಗಳು: $itemsSummary.';
    return 'Key items visible: $itemsSummary.';
  }

  static String sceneTextLead(String textSummary, String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') return 'दिखाई देने वाला पाठ: $textSummary।';
    if (lang == 'kn') return 'ಕಾಣುವ ಪಠ್ಯ: $textSummary.';
    return 'Visible text reads: $textSummary.';
  }

  static String sceneUncertainLead(String uncertainSummary, String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') return 'कम निश्चितता के साथ संभवतः मौजूद: $uncertainSummary।';
    if (lang == 'kn') return 'ಕಡಿಮೆ ಖಚಿತತೆಯೊಂದಿಗೆ ಬಹುಶಃ ಇರುವುದು: $uncertainSummary.';
    return 'Possibly also present, with lower certainty: $uncertainSummary.';
  }

  static String micGatedNotice(String locale) {
    final lang = langCode(locale);
    if (lang == 'hi') return 'बोलना समाप्त होने की प्रतीक्षा करें या पहले स्टॉप दबाएं।';
    if (lang == 'kn') return 'ಮಾತು ಮುಗಿಯುವವರೆಗೆ ಕಾಯಿರಿ ಅಥವಾ ಮೊದಲು ನಿಲ್ಲಿಸಿ ಒತ್ತಿರಿ.';
    return 'Assistant is currently speaking; tap Stop Speaking before recording a command.';
  }
}
