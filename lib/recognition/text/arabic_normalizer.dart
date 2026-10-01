/// Centralized utility for normalizing Arabic text for offline speech recognition.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 6:
/// - Strips all tashkeel (diacritics: fathah, dammah, kasrah, sukun, shaddah, tanween).
/// - Normalizes all alef variants (أ, إ, آ, ٱ) to plain bare alef (ا).
/// - Normalizes teh marbuta (ة) to heh (ه).
/// - Normalizes alef maksura (ى) to yeh (ي).
/// - Removes tatweel / kashida (ـ).
/// - Strips Arabic and Latin punctuation marks.
/// - Normalizes whitespace (collapsing repeated spaces and trimming).
class ArabicNormalizer {
  // Regex for Arabic diacritics (tashkeel & harakat)
  static final RegExp _tashkeelRegex = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]',
  );

  // Regex for tatweel (kashida)
  static final RegExp _tatweelRegex = RegExp(r'\u0640');

  // Regex for punctuation (Arabic and Latin)
  static final RegExp _punctuationRegex = RegExp(
    r'[\u060C\u061B\u061F\u066A\u066B\u066C\u066D\u06D4.!?,:;"\x27`~()\[\]{}<>/\\|@#$%^&*+=_\-]',
  );

  // Regex for multiple whitespace characters
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// Normalizes an Arabic string into a standardized comparison form.
  ///
  /// Preserves the core semantic characters while eliminating orthographic
  /// variations produced by different ASR model tokenizers.
  static String normalize(String text) {
    if (text.isEmpty) return '';

    String result = text;

    // 1. Remove diacritics (tashkeel)
    result = result.replaceAll(_tashkeelRegex, '');

    // 2. Remove tatweel (kashida)
    result = result.replaceAll(_tatweelRegex, '');

    // 3. Normalize alef variants to bare alef (ا)
    // \u0622 (آ), \u0623 (أ), \u0625 (إ), \u0671 (ٱ) -> \u0627 (ا)
    result = result.replaceAll(RegExp(r'[\u0622\u0623\u0625\u0671]'), '\u0627');

    // 4. Normalize teh marbuta (ة) to heh (ه)
    // \u0629 (ة) -> \u0647 (ه)
    result = result.replaceAll('\u0629', '\u0647');

    // 5. Normalize alef maksura (ى) to yeh (ي)
    // \u0649 (ى) -> \u064A (ي)
    result = result.replaceAll('\u0649', '\u064A');

    // 6. Strip punctuation
    result = result.replaceAll(_punctuationRegex, ' ');

    // 7. Collapse spaces and trim
    result = result.replaceAll(_whitespaceRegex, ' ').trim();

    return result;
  }

  /// Splits normalized Arabic text into individual word tokens.
  static List<String> tokenize(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((w) => w.isNotEmpty).toList();
  }
}
