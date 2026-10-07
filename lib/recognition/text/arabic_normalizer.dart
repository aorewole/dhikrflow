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

  // Regex matching repetitive single-letter loops produced by autoregressive decoders on silence (e.g. "س س س س" or "و و و و")
  static final RegExp _repetitionLoopRegex = RegExp(r'(?:^|\s)([\u0600-\u06FFa-zA-Z])(?:\s+\1){2,}(?:\s|$)');

  /// Cleans raw speech recognition transcript (supporting Arabic script and Latin transliteration):
  /// 1. Strips numeric digits.
  /// 2. Removes decoder repetition loops on silence (e.g. "و و و و" or "s s s").
  /// 3. Strips punctuation marks.
  /// 4. Normalizes whitespace.
  static String cleanTranscript(String text) {
    if (text.isEmpty) return '';

    // Strip numbers
    String cleaned = text.replaceAll(RegExp(r'[0-9\u0660-\u0669]'), ' ');

    // Remove repetitive single-character hallucination loops
    cleaned = cleanHallucinations(cleaned);

    // Strip punctuation
    cleaned = cleaned.replaceAll(_punctuationRegex, ' ');

    // Normalize whitespace
    cleaned = cleaned.replaceAll(_whitespaceRegex, ' ').trim();

    return cleaned;
  }

  /// Backward-compatible alias for [cleanTranscript].
  static String cleanStrictArabic(String text) => cleanTranscript(text);

  /// Removes repetitive single-character loops generated during low volume or silence.
  static String cleanHallucinations(String text) {
    String prev = text;
    String curr = text.replaceAll(_repetitionLoopRegex, ' ');
    while (curr != prev) {
      prev = curr;
      curr = curr.replaceAll(_repetitionLoopRegex, ' ');
    }
    return curr;
  }

  /// Checks whether [text] contains at least one Arabic letter.
  static bool containsArabicLetters(String text) {
    return RegExp(r'[\u0621-\u064A\u0671]').hasMatch(text);
  }

  /// Normalizes a string (Arabic script or Latin transliteration) into a standardized comparison form.
  static String normalize(String text) {
    if (text.isEmpty) return '';

    if (containsArabicLetters(text)) {
      // 1. Remove diacritics (tashkeel)
      String result = text.replaceAll(_tashkeelRegex, '');

      // 2. Remove tatweel (kashida)
      result = result.replaceAll(_tatweelRegex, '');

      // 3. Normalize alef variants to bare alef (ا)
      result = result.replaceAll(RegExp(r'[\u0622\u0623\u0625\u0671]'), '\u0627');

      // 4. Normalize teh marbuta (ة) to heh (ه)
      result = result.replaceAll('\u0629', '\u0647');

      // 5. Normalize alef maksura (ى) to yeh (ي)
      result = result.replaceAll('\u0649', '\u064A');

      // 6. Strip punctuation and non-Arabic symbols
      result = result.replaceAll(_punctuationRegex, ' ');
      result = result.replaceAll(RegExp(r'[^\u0621-\u064A\s]'), ' ');

      // 7. Collapse spaces and trim
      result = result.replaceAll(_whitespaceRegex, ' ').trim();

      return result.toLowerCase();
    } else {
      // Latin transliteration: strip diacritics/macrons, lowercase, collapse spaces
      String result = text.toLowerCase();
      result = result
          .replaceAll(RegExp(r'[āáàâä]'), 'a')
          .replaceAll(RegExp(r'[īíìîï]'), 'i')
          .replaceAll(RegExp(r'[ūúùûü]'), 'u')
          .replaceAll(RegExp(r'[ḍđ]'), 'd')
          .replaceAll(RegExp(r'[ẓżźž]'), 'z')
          .replaceAll(RegExp(r'[ṭţť]'), 't')
          .replaceAll(RegExp(r'[ṣśšş]'), 's')
          .replaceAll(RegExp(r'[ḥh́]'), 'h');
      result = result.replaceAll(_punctuationRegex, ' ');
      result = result.replaceAll(RegExp(r'[^a-z\s]'), ' ');
      result = result.replaceAll(_whitespaceRegex, ' ').trim();
      return result;
    }
  }

  /// Splits normalized Arabic text into individual word tokens.
  static List<String> tokenize(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((w) => w.isNotEmpty).toList();
  }

  // Regex matching repeated identical words produced by autoregressive loops (e.g. "عليم عليم عليم" -> "عليم")
  static final RegExp _repeatedWordRegex = RegExp(r'(?:^|\s)(\S+)(?:\s+\1)+(?:\s|$)');

  /// Phonetically normalizes Arabic dialectal variations and sound-alikes:
  /// - Collapses inter-consonant elongation vowels (e.g. "حسيبنا" -> "حسبنا")
  /// - Normalizes dialectal consonant shifts:
  ///   - ث, ص -> س
  ///   - ط -> ت
  ///   - ظ, ذ -> ز
  ///   - ق, ج -> ك
  ///   - ء, ئ, ؤ -> ا
  /// - Normalizes softened coda endings (e.g. الواكيد <-> الوكيل)
  static String normalizePhonetic(String text) {
    if (text.isEmpty) return '';
    String s = normalize(text);

    // 1. Collapse repeating word loops (e.g. "عليم عليم عليم" -> "عليم")
    s = s.replaceAllMapped(_repeatedWordRegex, (m) => ' ${m[1]} ');

    // 2. Normalize dialectal consonant shifts
    s = s.replaceAll(RegExp(r'[ثص]'), 'س');
    s = s.replaceAll(RegExp(r'[ط]'), 'ت');
    s = s.replaceAll(RegExp(r'[ظذض]'), 'ز');
    s = s.replaceAll(RegExp(r'[قجغخ]'), 'ك');
    s = s.replaceAll(RegExp(r'[ءئؤآأإ]'), 'ا');

    // 2b. Normalize bilabial nasalization in tasbih (e.g. سمان / سمحان <-> سبحان)
    s = s.replaceAll('سمان', 'سبحان').replaceAll('سمحان', 'سبحان');

    // 3. Normalize softened codas (e.g. الواكيد <-> الوكيل)
    s = s.replaceAll(RegExp(r'كيد$|كيد\s'), 'كيل ');

    // 4. Collapse elongated vowels between consonants (e.g. حسيبنا -> حسبنا)
    s = s.replaceAllMapped(
      RegExp(r'([\u0621-\u064A])ي([\u0621-\u064A])'),
      (m) => '${m[1]}${m[2]}',
    );

    return s.replaceAll(_whitespaceRegex, ' ').trim();
  }

  /// Ensures an Arabic phrase ends with liturgical waqf (coda stop with explicit sukūn)
  /// and sanitizes any erroneous redundant diacritics (such as misplaced fatha on the Lafdh al-Jalalah ligature).
  ///
  /// In liturgical dhikr recitation, stopping at phrase boundaries (waqf) silences
  /// the grammatical vowel ending (i'rab: fathah, kasrah, dammah, tanween) into pausal silence.
  /// For instance: "أَسْتَغْفِرُ ٱللَّٰهَ" -> "أَسْتَغْفِرُ ٱللّٰهْ".
  static String enforceSukunCoda(String text) {
    if (text.isEmpty) return text;
    // 1. Remove redundant fatha before shadda + superscript dagger alif (0x64E + 0x651 + 0x670 -> 0x651 + 0x670)
    String sanitized = text.replaceAll('\u064e\u0651\u0670', '\u0651\u0670');
    // 2. Strip any trailing short vowels/tashkeel at the very end of the string
    sanitized = sanitized
        .replaceAll(
          RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]+$'),
          '',
        )
        .trim();
    if (sanitized.isEmpty) return '';
    // 3. Attach explicit Arabic sukūn (ْ \u0652) to the final consonant to guarantee pausal silence
    // across both Android Google/Samsung TTS and Apple AVSpeechSynthesizer.
    return '$sanitized\u0652';
  }
}
