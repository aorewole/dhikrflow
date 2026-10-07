import 'dart:math' as math;

import 'arabic_normalizer.dart';

/// Confidence tiers conforming to `docs/RECOGNITION_SPEC.md` Section 11.
enum MatchConfidenceLevel { accept, uncertain, ignore }

/// The result of comparing candidate speech text against a target dhikr.
class MatchResult {
  final bool isMatch;
  final double confidence;
  final MatchConfidenceLevel level;
  final String matchedText;
  final String targetPhrase;

  const MatchResult({
    required this.isMatch,
    required this.confidence,
    required this.level,
    required this.matchedText,
    required this.targetPhrase,
  });

  @override
  String toString() =>
      'MatchResult(isMatch: $isMatch, confidence: ${confidence.toStringAsFixed(2)}, level: $level)';
}

/// High-precision Arabic phrase matcher with Levenshtein-based controlled fuzzy tolerance.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 8:
/// - Layer 1: Exact normalized text comparison (confidence 1.0)
/// - Layer 2: Controlled fuzzy edit-distance comparison
/// - Strict policy: Uncertain candidates do not increment counter automatically.
class PhraseMatcher {
  final double acceptThreshold;
  final double uncertainThreshold;

  const PhraseMatcher({
    this.acceptThreshold = 0.74,
    this.uncertainThreshold = 0.55,
  });

  /// Evaluates how closely [candidate] matches [target].
  ///
  /// If [isCadenceMatched] is true and acoustic confidence is in the near-match band
  /// (`uncertainThreshold` <= score < `acceptThreshold`), [cadenceBonus] is applied
  /// to promote the candidate to accepted status, eliminating user frustration while
  /// maintaining strict noise rejection.
  MatchResult evaluate({
    required String candidate,
    required String target,
    List<String> targetAliases = const [],
    bool isCadenceMatched = false,
    double cadenceBonus = 0.18,
  }) {
    final normCandidate = ArabicNormalizer.normalize(candidate);
    final normTarget = ArabicNormalizer.normalize(target);

    if (normCandidate.isEmpty || normTarget.isEmpty) {
      return MatchResult(
        isMatch: false,
        confidence: 0.0,
        level: MatchConfidenceLevel.ignore,
        matchedText: candidate,
        targetPhrase: target,
      );
    }

    // 1. Check exact match with target or any aliases
    if (normCandidate == normTarget) {
      return MatchResult(
        isMatch: true,
        confidence: 1.0,
        level: MatchConfidenceLevel.accept,
        matchedText: candidate,
        targetPhrase: target,
      );
    }

    for (final alias in targetAliases) {
      final normAlias = ArabicNormalizer.normalize(alias);
      if (normCandidate == normAlias) {
        return MatchResult(
          isMatch: true,
          confidence: 0.98,
          level: MatchConfidenceLevel.accept,
          matchedText: candidate,
          targetPhrase: target,
        );
      }
    }

    // 2. Controlled fuzzy similarity incorporating word-level alignment, phonetics, joined tokens & anchors
    double bestConfidence = calculateBestSimilarity(
      candidate: normCandidate,
      target: normTarget,
    );

    for (final alias in targetAliases) {
      final normAlias = ArabicNormalizer.normalize(alias);
      final sim = calculateBestSimilarity(
        candidate: normCandidate,
        target: normAlias,
      );
      if (sim > bestConfidence) {
        bestConfidence = sim;
      }
    }

    MatchConfidenceLevel level;
    bool isMatch;
    double finalConfidence = bestConfidence;

    if (bestConfidence >= acceptThreshold) {
      level = MatchConfidenceLevel.accept;
      isMatch = true;
    } else if (isCadenceMatched && bestConfidence >= uncertainThreshold) {
      // Cadence-assisted near-miss rescue:
      // The user is reciting in rhythm, and acoustic score is in the plausible near-match range.
      finalConfidence = math.min(1.0, bestConfidence + cadenceBonus);
      if (finalConfidence >= acceptThreshold) {
        level = MatchConfidenceLevel.accept;
        isMatch = true;
      } else {
        level = MatchConfidenceLevel.uncertain;
        isMatch = false;
      }
    } else if (bestConfidence >= uncertainThreshold) {
      level = MatchConfidenceLevel.uncertain;
      isMatch = false; // Under MVP policy, uncertain does not count
    } else {
      level = MatchConfidenceLevel.ignore;
      isMatch = false;
    }

    return MatchResult(
      isMatch: isMatch,
      confidence: finalConfidence,
      level: level,
      matchedText: candidate,
      targetPhrase: target,
    );
  }

  /// Computes the best similarity score [0.0, 1.0] across:
  /// 1. Standard string Levenshtein edit distance
  /// 2. Word-by-word token alignment
  /// 3. Dialectal phonetic normalization
  /// 4. Joined unspaced token comparison (handles ASR splitting words e.g. "أسك فر" -> "أسكفر")
  /// 5. Structural anchor matching for multi-word phrases (e.g. Salawat, Hawqalah)
  double calculateBestSimilarity({
    required String candidate,
    required String target,
  }) {
    final normCandidate = ArabicNormalizer.normalize(candidate);
    final normTarget = ArabicNormalizer.normalize(target);
    if (normCandidate == normTarget) return 1.0;
    if (normCandidate.isEmpty || normTarget.isEmpty) return 0.0;

    final stringSim = _calculateSimilarity(normCandidate, normTarget);
    final tokenSim = calculateTokenAlignmentSimilarity(
      normCandidate,
      normTarget,
    );
    final phoneticSim = _calculateSimilarity(
      ArabicNormalizer.normalizePhonetic(normCandidate),
      ArabicNormalizer.normalizePhonetic(normTarget),
    );

    // Joined token comparison (resilient against ASR whitespace splits e.g. "أسك فر الله" vs "استغفر الله")
    final normCandJoined = normCandidate.replaceAll(' ', '');
    final normTgtJoined = normTarget.replaceAll(' ', '');
    final joinedSim = _calculateSimilarity(normCandJoined, normTgtJoined);
    final joinedPhoneticSim = _calculateSimilarity(
      ArabicNormalizer.normalizePhonetic(normCandJoined),
      ArabicNormalizer.normalizePhonetic(normTgtJoined),
    );

    // Structural anchor matching for multi-word liturgical adhkar
    final anchorSim = _calculateAnchorSimilarity(normCandidate, normTarget);

    final cTokens = ArabicNormalizer.tokenize(normCandidate);
    final tTokens = ArabicNormalizer.tokenize(normTarget);
    if (tTokens.length == 3 &&
        cTokens.length == 3 &&
        _calculateSimilarity(cTokens.last, tTokens.last) < 0.60) {
      // Token-level discriminator: if the final distinguishing coda word of a 3-word phrase
      // completely differed (e.g. "الاعلى" vs "العظيم"), prevent prefix overlap ("سبحان ربي")
      // from triggering a false positive match.
      return tokenSim;
    }

    final score1 = math.max(stringSim, tokenSim);
    final score2 = math.max(phoneticSim, joinedSim);
    final score3 = math.max(joinedPhoneticSim, anchorSim);

    return math.max(score1, math.max(score2, score3));
  }

  /// Evaluates structural anchor keywords in multi-word adhkar.
  ///
  /// For instance, in Salawat ("اللهم صل على محمد"), if the opening anchor ("اللهم" / "الله")
  /// and the closing anchor ("محمد") are present with 3 to 6 words, the structural alignment
  /// is unmistakable even if intermediate particles were phonetically garbled by regional accents.
  double _calculateAnchorSimilarity(String candidate, String target) {
    final cTokens = ArabicNormalizer.tokenize(candidate);
    final tTokens = ArabicNormalizer.tokenize(target);
    if (cTokens.isEmpty || tTokens.isEmpty) return 0.0;

    // Anchor: Istighfar ("أستغفر الله")
    if (target.contains('غفر') || target.contains('استغفر')) {
      final hasGhafarRoot = candidate.contains('استغفر') ||
          candidate.contains('استوفر') ||
          candidate.contains('نستغفر') ||
          candidate.contains('استكفر') ||
          candidate.contains('استكفي') ||
          candidate.contains('استنفي') ||
          candidate.contains('استفر') ||
          candidate.contains('غفر');
      if (hasGhafarRoot) {
        // Must be combined with divine name or acoustic variant ("الله" / "لله")
        if (candidate.contains('الله') || candidate.contains('لله')) {
          return 0.88;
        }
      }
    }

    if (cTokens.length < 2 || tTokens.length < 2) return 0.0;

    // Anchor: 2-word Tahmid ("الحمد لله")
    if (target.contains('حمد') && target.contains('لله')) {
      if (candidate.startsWith('الحمد') || candidate.startsWith('حمد') || cTokens.first.contains('حمد')) {
        if (cTokens.length >= 2 && cTokens.length <= 3) {
          return 0.88;
        }
      }
    }

    // Anchor: 2-word Takbir ("الله أكبر")
    if (target.contains('الله') && (target.contains('اكبر') || target.contains('أكبر'))) {
      if (candidate.contains('الله') || candidate.contains('الاه')) {
        final hasAkbarLike = cTokens.any((t) =>
            t.contains('كبر') ||
            t.contains('اكم') ||
            t.contains('حكم') ||
            t.contains('حكن') ||
            t.contains('حكر') ||
            (t.contains('ك') && t.length >= 3));
        if (hasAkbarLike && cTokens.length >= 2 && cTokens.length <= 4) {
          return 0.88;
        }
      }
    }

    // Anchor: Salawat ("اللهم صل على محمد")
    if (target.contains('محمد') && (target.contains('صل') || target.contains('اللهم'))) {
      final hasAllah = candidate.contains('الله') || candidate.contains('اللهم');
      final hasMuhammad = candidate.contains('محمد') ||
          candidate.contains('مفمد') ||
          candidate.contains('محات') ||
          candidate.contains('محم');
      final hasSalli = candidate.contains('صل') ||
          candidate.contains('سلي') ||
          candidate.contains('صالي') ||
          candidate.contains('سلع');

      // Sub-phrase discrimination for distinct Salawat formulas:
      final targetHasAal = target.contains('ال محمد') || target.contains('آل');
      final candHasAal = candidate.contains('ال محمد') || candidate.contains('آل');
      if (targetHasAal != candHasAal) return 0.0;

      final targetHasNabiyyina = target.contains('نبينا') || target.contains('نبيه');
      final candHasNabiyyina = candidate.contains('نبينا') || candidate.contains('نبيه');
      if (targetHasNabiyyina != candHasNabiyyina) return 0.0;

      if (hasAllah && (hasMuhammad || hasSalli) && cTokens.length >= 3 && cTokens.length <= 7) {
        return 0.88;
      }
    }

    // Anchor: Hawqalah ("لا حول ولا قوة إلا بالله")
    if (target.contains('حول') && (target.contains('قوه') || target.contains('قوة') || target.contains('بالله'))) {
      final hasHawla = candidate.contains('لا حول') || candidate.contains('لاحول') || candidate.contains('نحونا');
      final nonHawlaTokens = cTokens.where((t) => !t.contains('حول')).toList();
      final hasBillah = nonHawlaTokens.any((t) =>
          t.contains('بالله') ||
          t == 'بلا' ||
          t.contains('بلاه') ||
          t.contains('كبات') ||
          t.contains('قوات'));
      if (hasHawla && hasBillah && cTokens.length >= 4 && cTokens.length <= 8) {
        return 0.88;
      }
    }

    // Anchor: Tasbih with Hamd ("سبحان الله وبحمده")
    if (target.contains('سبحان') && target.contains('الله') && target.contains('حمده')) {
      final hasSubhanAllah = candidate.contains('سبحان الله') ||
          candidate.contains('سبحانالله') ||
          candidate.contains('سبحان');
      final nonSubhanTokens = cTokens.where((t) => !t.contains('سبحان')).toList();
      final hasHamd = nonSubhanTokens.any((t) =>
          t.contains('حمد') ||
          t.contains('حمل') ||
          t.contains('بحاد') ||
          t.contains('بيحان') ||
          t.contains('وبح'));
      if (hasSubhanAllah && hasHamd && nonSubhanTokens.isNotEmpty) {
        return 0.88;
      }
    }

    // Anchor: Tasbih with Azeem ("سبحان الله العظيم")
    if (target.contains('سبحان') && target.contains('الله') && (target.contains('عظيم') || target.contains('عزيم'))) {
      final hasSubhanAllah = candidate.contains('سبحان الله') ||
          candidate.contains('سبحانالله') ||
          candidate.contains('سبحان');
      final hasAzeem = candidate.contains('عظيم') ||
          candidate.contains('عزيم') ||
          candidate.contains('عبين') ||
          candidate.contains('عالين') ||
          candidate.contains('لعبين') ||
          candidate.contains('ازيم');
      if (hasSubhanAllah && hasAzeem) {
        return 0.88;
      }
    }

    // Anchor: HasbunAllahu wa ni'mal wakeel
    if (target.contains('حسبنا') && target.contains('وكيل')) {
      final hasHasbuna = candidate.contains('حسبنا') ||
          candidate.contains('حسنا') ||
          candidate.contains('حسبن');
      final hasSecondPart = candidate.contains('وكيل') ||
          candidate.contains('وكيد') ||
          candidate.contains('نمي') ||
          candidate.contains('نقمت') ||
          candidate.contains('نعم');
      if (hasHasbuna && hasSecondPart) {
        return 0.88;
      }
    }

    return 0.0;
  }

  /// Calculates token-level alignment similarity between candidate and target: [0.0, 1.0].
  ///
  /// Evaluates how well each target word is represented in the candidate speech tokens,
  /// resilient against word reordering, insertion of dialectal particles, or vowel stretching.
  double calculateTokenAlignmentSimilarity(String candidate, String target) {
    final candidateTokens = ArabicNormalizer.tokenize(
      ArabicNormalizer.normalize(candidate),
    );
    final targetTokens = ArabicNormalizer.tokenize(
      ArabicNormalizer.normalize(target),
    );

    if (candidateTokens.isEmpty || targetTokens.isEmpty) return 0.0;

    final usedCandidateIndices = <int>{};
    double totalScore = 0.0;

    for (final tToken in targetTokens) {
      double bestMatch = 0.0;
      int bestCandidateIndex = -1;
      final tPhonetic = ArabicNormalizer.normalizePhonetic(tToken);

      for (int i = 0; i < candidateTokens.length; i++) {
        if (usedCandidateIndices.contains(i)) continue;
        final cToken = candidateTokens[i];
        final sim = _calculateSimilarity(cToken, tToken);
        final phoneticSim = _calculateSimilarity(
          ArabicNormalizer.normalizePhonetic(cToken),
          tPhonetic,
        );
        final bestTokenSim = math.max(sim, phoneticSim);
        if (bestTokenSim > bestMatch) {
          bestMatch = bestTokenSim;
          bestCandidateIndex = i;
        }
      }

      if (bestMatch >= 0.60 && bestCandidateIndex != -1) {
        usedCandidateIndices.add(bestCandidateIndex);
        totalScore += bestMatch;
      }
    }

    final maxLen = math.max(targetTokens.length, candidateTokens.length);
    return (totalScore / maxLen).clamp(0.0, 1.0);
  }

  /// Calculates Levenshtein-based similarity between two normalized strings: [0.0, 1.0].
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLength = math.max(s1.length, s2.length);
    if (maxLength == 0) return 1.0;

    final sim = 1.0 - (distance / maxLength);
    return sim.clamp(0.0, 1.0);
  }

  /// Standard dynamic programming Levenshtein distance algorithm.
  int _levenshteinDistance(String a, String b) {
    final m = a.length;
    final n = b.length;

    // Use two rows instead of full matrix to minimize memory allocation
    List<int> previousRow = List<int>.generate(n + 1, (i) => i);
    List<int> currentRow = List<int>.filled(n + 1, 0);

    for (int i = 0; i < m; i++) {
      currentRow[0] = i + 1;
      final aChar = a.codeUnitAt(i);

      for (int j = 0; j < n; j++) {
        final bChar = b.codeUnitAt(j);
        final cost = (aChar == bChar) ? 0 : 1;

        currentRow[j + 1] = math.min(
          currentRow[j] + 1, // insertion
          math.min(
            previousRow[j + 1] + 1, // deletion
            previousRow[j] + cost, // substitution
          ),
        );
      }

      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[n];
  }
}
