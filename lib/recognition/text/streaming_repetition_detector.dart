import 'arabic_normalizer.dart';
import 'phrase_matcher.dart';

/// Detected occurrence of a target dhikr phrase in a recognition stream.
class RepetitionOccurrence {
  final int occurrenceIndex;
  final String matchedText;
  final double confidence;
  final DateTime timestamp;

  const RepetitionOccurrence({
    required this.occurrenceIndex,
    required this.matchedText,
    required this.confidence,
    required this.timestamp,
  });

  @override
  String toString() =>
      'RepetitionOccurrence(#$occurrenceIndex, conf: ${confidence.toStringAsFixed(2)}, text: "$matchedText")';
}

/// Detects repetitions of a target dhikr in continuous or streaming speech transcripts.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 9, 10, 11:
/// - Reconciles evolving partial hypotheses without double-counting.
/// - Detects multiple repetitions in a single continuous transcript (e.g. +4 from rapid recitation).
/// - Rejects unrelated speech (+0).
/// - Operates deterministically without artificial time delays.
class StreamingRepetitionDetector {
  final PhraseMatcher _matcher;
  final String targetPhrase;
  final List<String> targetAliases;

  int _previouslyCommittedOccurrences = 0;
  final List<RepetitionOccurrence> _allOccurrences = [];

  StreamingRepetitionDetector({
    required this.targetPhrase,
    this.targetAliases = const [],
    PhraseMatcher? matcher,
  }) : _matcher = matcher ?? const PhraseMatcher();

  int get totalAcceptedOccurrences => _allOccurrences.length;
  List<RepetitionOccurrence> get occurrences =>
      List.unmodifiable(_allOccurrences);

  /// Processes an incoming transcript (partial or final) and returns newly committed occurrences.
  ///
  /// For example, if a previous partial hypothesis contained 1 repetition and the updated
  /// transcript now contains 3 repetitions, this method returns 2 new occurrences.
  List<RepetitionOccurrence> processTranscript(
    String transcript, {
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final allFound = findAllOccurrences(transcript, now);

    final totalFoundCount = allFound.length;
    if (totalFoundCount <= _previouslyCommittedOccurrences) {
      // Evolving partial hypothesis did not add newly completed repetitions
      return const [];
    }

    // Newly committed repetitions
    final newlyCommitted = allFound.sublist(_previouslyCommittedOccurrences);
    _previouslyCommittedOccurrences = totalFoundCount;
    _allOccurrences.addAll(newlyCommitted);

    return newlyCommitted;
  }

  /// Scans [text] and returns all non-overlapping accepted occurrences of the target phrase.
  List<RepetitionOccurrence> findAllOccurrences(
    String text,
    DateTime timestamp,
  ) {
    final normTarget = ArabicNormalizer.normalize(targetPhrase);
    if (normTarget.isEmpty) return const [];

    final targetTokens = ArabicNormalizer.tokenize(normTarget);
    final targetTokenCount = targetTokens.length;
    final normTargetJoined = normTarget.replaceAll(' ', '');

    final candidateTokens = ArabicNormalizer.tokenize(text);
    if (candidateTokens.isEmpty) return const [];

    final List<RepetitionOccurrence> occurrences = [];
    int i = 0;

    while (i < candidateTokens.length) {
      bool matched = false;

      // 1. Try single-token joined form if target is multi-word (e.g. "استغفرالله" without space)
      if (targetTokenCount > 1) {
        final singleToken = candidateTokens[i];
        final singleMatch = _matcher.evaluate(
          candidate: singleToken,
          target: normTargetJoined,
          targetAliases: targetAliases
              .map((a) => a.replaceAll(' ', ''))
              .toList(),
        );

        if (singleMatch.isMatch &&
            singleMatch.level == MatchConfidenceLevel.accept) {
          occurrences.add(
            RepetitionOccurrence(
              occurrenceIndex: occurrences.length + 1,
              matchedText: singleToken,
              confidence: singleMatch.confidence,
              timestamp: timestamp,
            ),
          );
          i += 1;
          matched = true;
          continue;
        }
      }

      // 2. Try window of targetTokenCount tokens (e.g. 2-token window: "استغفر الله")
      if (i + targetTokenCount <= candidateTokens.length) {
        final windowPhrase = candidateTokens
            .sublist(i, i + targetTokenCount)
            .join(' ');
        final windowMatch = _matcher.evaluate(
          candidate: windowPhrase,
          target: normTarget,
          targetAliases: targetAliases,
        );

        if (windowMatch.isMatch &&
            windowMatch.level == MatchConfidenceLevel.accept) {
          occurrences.add(
            RepetitionOccurrence(
              occurrenceIndex: occurrences.length + 1,
              matchedText: windowPhrase,
              confidence: windowMatch.confidence,
              timestamp: timestamp,
            ),
          );
          i += targetTokenCount;
          matched = true;
          continue;
        }
      }

      // 3. Try window of targetTokenCount + 1 tokens if available (handles minor particle/split)
      if (targetTokenCount > 1 &&
          i + targetTokenCount + 1 <= candidateTokens.length) {
        final windowPhrase = candidateTokens
            .sublist(i, i + targetTokenCount + 1)
            .join(' ');
        final windowMatch = _matcher.evaluate(
          candidate: windowPhrase,
          target: normTarget,
          targetAliases: targetAliases,
        );

        if (windowMatch.isMatch &&
            windowMatch.level == MatchConfidenceLevel.accept) {
          occurrences.add(
            RepetitionOccurrence(
              occurrenceIndex: occurrences.length + 1,
              matchedText: windowPhrase,
              confidence: windowMatch.confidence,
              timestamp: timestamp,
            ),
          );
          i += targetTokenCount + 1;
          matched = true;
          continue;
        }
      }

      // No match at index i, advance by 1 token
      if (!matched) {
        i += 1;
      }
    }

    return occurrences;
  }

  /// Resets detector state for a new speech segment or session.
  void reset() {
    _previouslyCommittedOccurrences = 0;
    _allOccurrences.clear();
  }
}
