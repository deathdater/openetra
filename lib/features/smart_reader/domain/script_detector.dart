import '../../../core/domain/entities/entities.dart';

/// Unicode-block script classifier covering Latin and 7 priority/target Indic scripts.
class ScriptDetector {
  const ScriptDetector();

  DetectedScript detectFromText(String sample) {
    if (sample.trim().isEmpty) return DetectedScript.unknown;
    final counts = <DetectedScript, int>{};

    for (final rune in sample.runes) {
      final script = _classifyRune(rune);
      if (script != null) {
        counts[script] = (counts[script] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return DetectedScript.unknown;
    if (counts.length > 1) {
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted[1].value >= 2 && sorted[1].value * 4 >= sorted[0].value) {
        return DetectedScript.mixed;
      }
      return sorted.first.key;
    }
    return counts.keys.first;
  }

  DetectedScript expectedScriptForLocale(String locale) {
    final code = locale.toLowerCase();
    if (code.startsWith('hi') || code.startsWith('mr')) {
      return DetectedScript.devanagari;
    }
    if (code.startsWith('kn')) return DetectedScript.kannada;
    if (code.startsWith('ta')) return DetectedScript.tamil;
    if (code.startsWith('te')) return DetectedScript.telugu;
    if (code.startsWith('ml')) return DetectedScript.malayalam;
    if (code.startsWith('bn')) return DetectedScript.bengali;
    return DetectedScript.latin;
  }

  static DetectedScript? _classifyRune(int rune) {
    if ((rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F)) {
      return DetectedScript.latin;
    }
    if (rune >= 0x0900 && rune <= 0x097F) return DetectedScript.devanagari;
    if (rune >= 0x0980 && rune <= 0x09FF) return DetectedScript.bengali;
    if (rune >= 0x0B80 && rune <= 0x0BFF) return DetectedScript.tamil;
    if (rune >= 0x0C00 && rune <= 0x0C7F) return DetectedScript.telugu;
    if (rune >= 0x0C80 && rune <= 0x0CFF) return DetectedScript.kannada;
    if (rune >= 0x0D00 && rune <= 0x0D7F) return DetectedScript.malayalam;
    return null;
  }
}
