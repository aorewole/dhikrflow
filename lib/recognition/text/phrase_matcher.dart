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
    this.acceptThreshold = 0.85,
    this.uncertainThreshold = 0.65,
  });

  /// Evaluates how closely [candidate] matches [target].
  MatchResult evaluate({
    required String candidate,
    required String target,
    List<String> targetAliases = const [],
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

    // 2. Controlled fuzzy similarity
    double bestConfidence = _calculateSimilarity(normCandidate, normTarget);

    for (final alias in targetAliases) {
      final normAlias = ArabicNormalizer.normalize(alias);
      final sim = _calculateSimilarity(normCandidate, normAlias);
      if (sim > bestConfidence) {
        bestConfidence = sim;
      }
    }

    MatchConfidenceLevel level;
    bool isMatch;

    if (bestConfidence >= acceptThreshold) {
      level = MatchConfidenceLevel.accept;
      isMatch = true;
    } else if (bestConfidence >= uncertainThreshold) {
      level = MatchConfidenceLevel.uncertain;
      isMatch = false; // Under MVP policy, uncertain does not count
    } else {
      level = MatchConfidenceLevel.ignore;
      isMatch = false;
    }

    return MatchResult(
      isMatch: isMatch,
      confidence: bestConfidence,
      level: level,
      matchedText: candidate,
      targetPhrase: target,
    );
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
