import '../domain/entities/entities.dart';
import 'indic_scene_lexicon.dart';

/// Direct native localization across all 8 Openetra Indian languages:
/// English (en-IN), Hindi (hi-IN), Kannada (kn-IN), Tamil (ta-IN),
/// Telugu (te-IN), Malayalam (ml-IN), Marathi (mr-IN), and Bengali (bn-IN).
class OpenetraLocalizer {
  const OpenetraLocalizer();

  static String langCode(String locale) {
    final lower = locale.toLowerCase();
    if (lower.startsWith('hi')) return 'hi';
    if (lower.startsWith('kn')) return 'kn';
    if (lower.startsWith('ta')) return 'ta';
    if (lower.startsWith('te')) return 'te';
    if (lower.startsWith('ml')) return 'ml';
    if (lower.startsWith('mr')) return 'mr';
    if (lower.startsWith('bn')) return 'bn';
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

  static String continuousSceneStarted(int breakSeconds, String locale) {
    return switch (langCode(locale)) {
      'hi' =>
        'लगातार दृश्य विवरण शुरू हो गया है। हर विवरण के बाद $breakSeconds सेकंड का विराम रहेगा।',
      'kn' =>
        'ನಿರಂತರ ದೃಶ್ಯ ವಿವರಣೆ ಪ್ರಾರಂಭವಾಗಿದೆ. ಪ್ರತಿ ವಿವರಣೆಯ ನಂತರ $breakSeconds ಸೆಕೆಂಡುಗಳ ವಿರಾಮ ಇರುತ್ತದೆ.',
      'ta' =>
        'தொடர் காட்சி விளக்கம் தொடங்கியது. ஒவ்வொரு விளக்கத்திற்குப் பிறகும் $breakSeconds வினாடி இடைவெளி இருக்கும்.',
      'te' =>
        'నిరంతర దృశ్య వివరణ ప్రారంభమైంది. ప్రతి వివరణ తర్వాత $breakSeconds సెకన్ల విరామం ఉంటుంది.',
      'ml' =>
        'തുടർച്ചയായ ദൃശ്യ വിവരണം ആരംഭിച്ചു. ഓരോ വിവരണത്തിനും ശേഷം $breakSeconds സെക്കൻഡ് ഇടവേള ഉണ്ടാകും.',
      'mr' =>
        'सतत दृश्य वर्णन सुरू झाले आहे. प्रत्येक वर्णनानंतर $breakSeconds सेकंदांचा विराम राहील.',
      'bn' =>
        'ধারাবাহিক দৃশ্য বর্ণনা শুরু হয়েছে। প্রতিটি বর্ণনার পর $breakSeconds সেকেন্ডের বিরতি থাকবে।',
      _ =>
        'Continuous scene description started, with a $breakSeconds second break after each description.',
    };
  }

  static String continuousSceneStopped(String locale) {
    return switch (langCode(locale)) {
      'hi' => 'लगातार दृश्य विवरण बंद कर दिया गया है।',
      'kn' => 'ನಿರಂತರ ದೃಶ್ಯ ವಿವರಣೆಯನ್ನು ನಿಲ್ಲಿಸಲಾಗಿದೆ.',
      'ta' => 'தொடர் காட்சி விளக்கம் நிறுத்தப்பட்டது.',
      'te' => 'నిరంతర దృశ్య వివరణ ఆపివేయబడింది.',
      'ml' => 'തുടർച്ചയായ ദൃശ്യ വിവരണം നിർത്തി.',
      'mr' => 'सतत दृश्य वर्णन थांबवले आहे.',
      'bn' => 'ধারাবাহিক দৃশ্য বর্ণনা বন্ধ করা হয়েছে।',
      _ => 'Continuous scene description stopped.',
    };
  }

  static String _joinIndicList(List<String> items, String lang) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    final conj = switch (lang) {
      'hi' => 'और',
      'kn' => 'ಮತ್ತು',
      'ta' => 'மற்றும்',
      'te' => 'మరియు',
      'ml' => 'കൂടാതെ',
      'mr' => 'आणि',
      'bn' => 'এবং',
      _ => 'and',
    };
    if (items.length == 2) return '${items[0]} $conj ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(", ")} $conj ${items.last}';
  }

  static String _localizedNodeLabel(SceneGraphNode n, String lang) {
    final term = IndicSceneLexicon.translateTerm(n.name, lang);
    return n.instanceCount > 1 ? '${n.instanceCount} $term' : term;
  }

  static String _indicZoneSentence(
    String zone,
    List<SceneGraphNode> nodes,
    String lang,
  ) {
    final items = _joinIndicList(
      nodes.map((n) => _localizedNodeLabel(n, lang)).toList(),
      lang,
    );
    final isPlural = nodes.length > 1 || nodes.first.instanceCount > 1;
    switch (lang) {
      case 'hi':
        final verb = isPlural ? 'हैं' : 'है';
        return switch (zone) {
          'ahead' => 'आपके ठीक सामने $items $verb।',
          'left' => 'आपकी बाईं ओर $items $verb।',
          'right' => 'आपकी दाईं ओर $items $verb।',
          _ => 'ऊपर की ओर $items $verb।',
        };
      case 'kn':
        final verb = isPlural ? 'ಇವೆ' : 'ಇದೆ';
        return switch (zone) {
          'ahead' => 'ನಿಮ್ಮ ನೇರ ಮುಂದೆ $items $verb.',
          'left' => 'ನಿಮ್ಮ ಎಡಭಾಗದಲ್ಲಿ $items $verb.',
          'right' => 'ನಿಮ್ಮ ಬಲಭಾಗದಲ್ಲಿ $items $verb.',
          _ => 'ಮೇಲ್ಭಾಗದಲ್ಲಿ $items $verb.',
        };
      case 'ta':
        final verb = isPlural ? 'உள்ளன' : 'உள்ளது';
        return switch (zone) {
          'ahead' => 'உங்கள் நேர் முன்னால் $items $verb.',
          'left' => 'உங்கள் இடதுபுறத்தில் $items $verb.',
          'right' => 'உங்கள் வலதுபுறத்தில் $items $verb.',
          _ => 'மேலே $items $verb.',
        };
      case 'te':
        final verb = isPlural ? 'ఉన్నాయి' : 'ఉంది';
        return switch (zone) {
          'ahead' => 'మీ నేరుగా ముందు $items $verb.',
          'left' => 'మీ ఎడమవైపు $items $verb.',
          'right' => 'మీ కుడివైపు $items $verb.',
          _ => 'పైభాగంలో $items $verb.',
        };
      case 'ml':
        return switch (zone) {
          'ahead' => 'നിങ്ങളുടെ നേരെ മുന്നിൽ $items ഉണ്ട്.',
          'left' => 'നിങ്ങളുടെ ഇടതുവശത്ത് $items ഉണ്ട്.',
          'right' => 'നിങ്ങളുടെ வலതുവശത്ത് $items ഉണ്ട്.',
          _ => 'മുകളിൽ $items ഉണ്ട്.',
        };
      case 'mr':
        final verb = isPlural ? 'आहेत' : 'आहे';
        return switch (zone) {
          'ahead' => 'तुमच्या अगदी समोर $items $verb.',
          'left' => 'तुमच्या डाव्या बाजूला $items $verb.',
          'right' => 'तुमच्या उजव्या बाजूला $items $verb.',
          _ => 'वरच्या बाजूला $items $verb.',
        };
      case 'bn':
        return switch (zone) {
          'ahead' => 'আপনার ঠিক সামনে $items আছে।',
          'left' => 'আপনার বাম দিকে $items আছে।',
          'right' => 'আপনার ডান দিকে $items আছে।',
          _ => 'উপরের দিকে $items আছে।',
        };
      default:
        return items;
    }
  }

  /// Composes clear, warm, spatially grouped natural scene narration for all
  /// 7 Indian languages (`hi`, `kn`, `ta`, `te`, `ml`, `mr`, `bn`) using
  /// native grammar and the offline [IndicSceneLexicon].
  static String composeNaturalIndicScene({
    required SceneGraph graph,
    required String locale,
  }) {
    final lang = langCode(locale);
    final parts = <String>[];

    // 1. Environment & lighting lead (omit unclassified area cleanly)
    final envRaw = graph.environmentCategory.trim();
    if (envRaw.isNotEmpty && envRaw.toLowerCase() != 'unclassified area') {
      final env = IndicSceneLexicon.translateTerm(envRaw, lang);
      final lightRaw = graph.lighting?.trim() ?? '';
      final light = lightRaw.isNotEmpty
          ? IndicSceneLexicon.translateTerm(lightRaw, lang)
          : '';
      parts.add(switch (lang) {
        'hi' => light.isNotEmpty
            ? 'आप $env में प्रतीत होते हैं, रोशनी $light है।'
            : 'आप $env में प्रतीत होते हैं।',
        'kn' => light.isNotEmpty
            ? 'ನೀವು $env ನಲ್ಲಿ ಇದ್ದೀರಿ ಎಂದು ತೋರುತ್ತದೆ, ಬೆಳಕು $light.'
            : 'ನೀವು $env ನಲ್ಲಿ ಇದ್ದೀರಿ ಎಂದು ತೋರುತ್ತದೆ.',
        'ta' => light.isNotEmpty
            ? 'நீங்கள் $env பகுதியில் இருப்பதாகத் தெரிகிறது, வெளிச்சம் $light உள்ளது.'
            : 'நீங்கள் $env பகுதியில் இருப்பதாகத் தெரிகிறது.',
        'te' => light.isNotEmpty
            ? 'మీరు $env లో ఉన్నట్లు కనిపిస్తోంది, వెలుతురు $light ఉంది.'
            : 'మీరు $env లో ఉన్నట్లు కనిపిస్తోంది.',
        'ml' => light.isNotEmpty
            ? 'നിങ്ങൾ $env ഭാഗത്താണെന്ന് തോന്നുന്നു, വെളിച്ചം $light.'
            : 'നിങ്ങൾ $env ഭാഗത്താണെന്ന് തോന്നുന്നു.',
        'mr' => light.isNotEmpty
            ? 'तुम्ही $env मध्ये आहात असे वाटते, प्रकाश $light आहे.'
            : 'तुम्ही $env मध्ये आहात असे वाटते.',
        'bn' => light.isNotEmpty
            ? 'মনে হচ্ছে আপনি $env এলাকায় আছেন, আলো $light।'
            : 'মনে হচ্ছে আপনি $env এলাকায় আছেন।',
        _ => 'You appear to be in $env.',
      });
    }

    // 2. Spatially grouped objects (ahead -> left -> right -> overhead)
    final confident = graph.nodes.where((n) => !n.isUncertain).take(5).toList();
    if (confident.isNotEmpty) {
      final ahead = <SceneGraphNode>[];
      final left = <SceneGraphNode>[];
      final right = <SceneGraphNode>[];
      final overhead = <SceneGraphNode>[];
      for (final node in confident) {
        if (node.relativePosition.vertical == VerticalZone.overhead) {
          overhead.add(node);
        } else {
          switch (node.relativePosition.horizontal) {
            case HorizontalZone.center:
              ahead.add(node);
            case HorizontalZone.left:
            case HorizontalZone.farLeft:
              left.add(node);
            case HorizontalZone.right:
            case HorizontalZone.farRight:
              right.add(node);
          }
        }
      }
      if (ahead.isNotEmpty) parts.add(_indicZoneSentence('ahead', ahead, lang));
      if (left.isNotEmpty) parts.add(_indicZoneSentence('left', left, lang));
      if (right.isNotEmpty) parts.add(_indicZoneSentence('right', right, lang));
      if (overhead.isNotEmpty) {
        parts.add(_indicZoneSentence('overhead', overhead, lang));
      }
    } else if (graph.nodes.isEmpty) {
      parts.add(switch (lang) {
        'hi' => 'इस दृश्य में कोई स्पष्ट वस्तु दिखाई नहीं दी। कृपया कैमरा धीरे-धीरे घुमाएं।',
        'kn' => 'ಈ ನೋಟದಲ್ಲಿ ಯಾವುದೇ ಸ್ಪಷ್ಟ ವಸ್ತು ಕಾಣಿಸುತ್ತಿಲ್ಲ. ದಯವಿಟ್ಟು ಕ್ಯಾಮೆರಾವನ್ನು ನಿಧಾನವಾಗಿ ತಿರುಗಿಸಿ.',
        'ta' => 'இந்தக் காட்சியில் தெளிவான பொருள் எதுவும் தெரியவில்லை. கேமராவை மெதுவாக நகர்த்தவும்.',
        'te' => 'ఈ దృశ్యంలో స్పష్టమైన వస్తువు ఏదీ కనిపించలేదు. దయచేసి కెమెరాను నెమ్మదిగా తిప్పండి.',
        'ml' => 'ഈ ദൃശ്യത്തിൽ വ്യക്തമായ വസ്തുക്കളൊന്നും കാണുന്നില്ല. ക്യാമറ പതുക്കെ തിരിക്കുക.',
        'mr' => 'या दृश्यात कोणतीही स्पष्ट वस्तू दिसली नाही. कृपया कॅमेरा हळूहळू फिरवा.',
        'bn' => 'এই দৃশ্যে কোনো স্পষ্ট বস্তু দেখা যায়নি। অনুগ্রহ করে ক্যামেরা ধীরে ধীরে ঘোরান।',
        _ => 'Nothing distinct stands out clearly in this frame.',
      });
    }

    // 3. Readable text
    if (graph.readableTexts.isNotEmpty) {
      final textStr = _joinIndicList(graph.readableTexts.take(3).toList(), lang);
      parts.add(switch (lang) {
        'hi' => 'सामने लिखा हुआ है: $textStr।',
        'kn' => 'ಕಾಣಿಸುವ ಪಠ್ಯ: $textStr.',
        'ta' => 'தெரியும் எழுத்து: $textStr.',
        'te' => 'కనిపించే అక్షరాలు: $textStr.',
        'ml' => 'കാണുന്ന എഴുത്ത്: $textStr.',
        'mr' => 'दिसणारा मजकूर: $textStr.',
        'bn' => 'দৃশ্যমান লেখা: $textStr।',
        _ => 'Visible text reads: $textStr.',
      });
    }

    // 4. Lower-certainty items
    final uncertain = graph.uncertainNodes
        .take(2)
        .map((n) => IndicSceneLexicon.translateTerm(n.name, lang))
        .toList();
    if (uncertain.isNotEmpty) {
      final uStr = _joinIndicList(uncertain, lang);
      parts.add(switch (lang) {
        'hi' => 'कम निश्चित रूप से, यहाँ $uStr भी हो सकता है।',
        'kn' => 'ಕಡಿಮೆ ಖಚಿತತೆಯೊಂದಿಗೆ, ಇಲ್ಲಿ $uStr ಕೂಡ ಇರಬಹುದು.',
        'ta' => 'குறைந்த உறுதியுடன், இங்கே $uStr இருக்கலாம்.',
        'te' => 'తక్కువ ఖచ్చితత్వంతో, ఇక్కడ $uStr కూడా ఉండవచ్చు.',
        'ml' => 'കുറഞ്ഞ ഉറപ്പോടെ, ഇവിടെ $uStr ഉണ്ടായേക്കാം.',
        'mr' => 'कमी खात्रीने, येथे $uStr देखील असू शकते.',
        'bn' => 'কম নিশ্চয়তার সাথে, এখানে $uStr থাকতে পারে।',
        _ => 'Less certain, there may also be $uStr.',
      });
    }

    return parts.join(' ');
  }
}
