import 'dart:math' as math;

import 'arabic_normalizer.dart';
import 'phrase_matcher.dart';
import 'recitation_cadence_tracker.dart';

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

/// Result of scanning a token list for occurrences and trailing unconsumed tokens.
class ScanResult {
  final List<RepetitionOccurrence> occurrences;
  final int lastMatchedEndIndex;
  final int totalCandidateTokens;

  const ScanResult({
    required this.occurrences,
    required this.lastMatchedEndIndex,
    required this.totalCandidateTokens,
  });

  bool get hasUnconsumedTrailingTokens =>
      lastMatchedEndIndex < totalCandidateTokens;

  List<String> getTrailingTokens(List<String> allTokens) {
    if (lastMatchedEndIndex >= allTokens.length) return const [];
    return allTokens.sublist(lastMatchedEndIndex);
  }
}

/// Detects repetitions of a target dhikr in continuous or streaming speech transcripts.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 9, 10, 11:
/// - Reconciles evolving partial hypotheses without double-counting.
/// - Detects multiple repetitions in a single continuous transcript (e.g. +4 from rapid recitation).
/// - Rejects unrelated speech (+0).
/// - Operates deterministically without artificial time delays.
/// - Supports multi-segment rolling accumulation for multi-word phrases (e.g. "Subhanallahi wa bihamdihi")
///   with prefix restart detection and staleness timeouts.
/// - Integrates with [RecitationCadenceTracker] to rescue near-misses during rhythmic recitation.
class StreamingRepetitionDetector {
  final PhraseMatcher _matcher;
  final String targetPhrase;
  final List<String> targetAliases;
  final Duration maxStalenessDuration;
  final RecitationCadenceTracker? cadenceTracker;

  int _previouslyCommittedOccurrences = 0;
  final List<RepetitionOccurrence> _allOccurrences = [];

  List<String> _pendingPrefixTokens = [];
  DateTime? _pendingPrefixTimestamp;

  StreamingRepetitionDetector({
    required this.targetPhrase,
    this.targetAliases = const [],
    this.maxStalenessDuration = const Duration(milliseconds: 3500),
    PhraseMatcher? matcher,
    this.cadenceTracker,
  }) : _matcher = matcher ?? const PhraseMatcher();

  int get totalAcceptedOccurrences => _allOccurrences.length;
  List<RepetitionOccurrence> get occurrences =>
      List.unmodifiable(_allOccurrences);

  /// Active pending partial prefix tokens awaiting phrase completion.
  List<String> get pendingPrefixTokens =>
      List.unmodifiable(_pendingPrefixTokens);

  /// Timestamp when the current pending prefix was buffered.
  DateTime? get pendingPrefixTimestamp => _pendingPrefixTimestamp;

  /// Processes an incoming continuous streaming transcript (partial or final)
  /// and returns newly committed occurrences.
  List<RepetitionOccurrence> processTranscript(
    String transcript, {
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final allFound = findAllOccurrences(transcript, now);

    final totalFoundCount = allFound.length;
    if (totalFoundCount <= _previouslyCommittedOccurrences) {
      return const [];
    }

    final newlyCommitted = allFound.sublist(_previouslyCommittedOccurrences);
    _previouslyCommittedOccurrences = totalFoundCount;
    _allOccurrences.addAll(newlyCommitted);

    return newlyCommitted;
  }

  /// Processes a complete discrete speech segment transcript.
  ///
  /// Supports multi-segment recitation where long phrases (e.g. "Subhanallahi wa bihamdihi")
  /// are recited across multiple segments separated by natural micro-pauses.
  ///
  /// Implements lifecycle rules:
  /// - Case A (Continuation): Buffers partial prefix and joins with continuation to emit +1.
  /// - Case B (Staleness/Timeout): Discards stale partial prefixes after [maxStalenessDuration].
  /// - Case C (Prefix Restart): If a new segment begins with the target prefix, discards any previous partial prefix.
  /// - Case D (Irrelevant speech): Discards partial buffer if input cannot form continuation or prefix.
  /// Processes a complete discrete speech segment transcript.
  ///
  /// Supports multi-segment recitation where long phrases (e.g. "Subhanallahi wa bihamdihi")
  /// are recited across multiple segments separated by natural micro-pauses.
  ///
  /// Implements lifecycle rules:
  /// - Case A (Continuation): Buffers partial prefix and joins with continuation to emit +1.
  /// - Case B (Staleness/Timeout): Discards stale partial prefixes after [maxStalenessDuration].
  /// - Case C (Prefix Restart): If a new segment begins with the target prefix, discards any previous partial prefix.
  /// - Case D (Irrelevant speech): Discards partial buffer if input cannot form continuation or prefix.
  List<RepetitionOccurrence> processSegment(
    String segmentTranscript, {
    DateTime? timestamp,
    Duration? segmentDuration,
  }) {
    final now = timestamp ?? DateTime.now();

    // 1. Check for staleness timeout (Case B)
    if (_pendingPrefixTokens.isNotEmpty && _pendingPrefixTimestamp != null) {
      if (now.difference(_pendingPrefixTimestamp!) > maxStalenessDuration) {
        _pendingPrefixTokens = [];
        _pendingPrefixTimestamp = null;
      }
    }

    final candidateTokens = ArabicNormalizer.tokenize(
      ArabicNormalizer.normalize(segmentTranscript),
    );
    if (candidateTokens.isEmpty) return const [];

    // 2. Check for Prefix Restart (Case C)
    // If we have an existing partial buffer, but the incoming segment starts from the beginning
    // of the dhikr again, the user restarted/repeated Segment 1 -> discard stale previous buffer.
    if (_pendingPrefixTokens.isNotEmpty &&
        startsWithTargetPrefix(candidateTokens)) {
      _pendingPrefixTokens = [];
      _pendingPrefixTimestamp = null;
    }

    // 3. Assemble tokens to scan (combining pending prefix if available)
    final List<String> tokensToScan;
    if (_pendingPrefixTokens.isNotEmpty) {
      tokensToScan = [..._pendingPrefixTokens, ...candidateTokens];
    } else {
      tokensToScan = candidateTokens;
    }

    // 4. Scan combined tokens for complete repetitions (with cadence assist if segmentDuration provided)
    final scanResult = scanTokens(
      tokensToScan,
      now,
      segmentDuration: segmentDuration,
    );

    if (scanResult.occurrences.isNotEmpty) {
      // Completed one or more repetitions!
      if (segmentDuration != null) {
        cadenceTracker?.recordDuration(
          segmentDuration,
          repetitionCount: scanResult.occurrences.length,
        );
      }
      final trailing = scanResult.getTrailingTokens(tokensToScan);

      // In continuous rapid recitation, a trailing root verb (e.g. "أستغفر" after "أستغفر الله")
      // in a concluded discrete speech segment represents a complete repetition.
      if (trailing.isNotEmpty && isPlausibleRapidRoot(trailing)) {
        final trailingText = trailing.join(' ');
        final occ = RepetitionOccurrence(
          occurrenceIndex: scanResult.occurrences.length + 1,
          matchedText: trailingText,
          confidence: 0.88,
          timestamp: now,
        );
        final combined = [...scanResult.occurrences, occ];
        _allOccurrences.addAll(combined);
        _pendingPrefixTokens = [];
        _pendingPrefixTimestamp = null;
        if (segmentDuration != null) {
          cadenceTracker?.recordDuration(
            segmentDuration,
            repetitionCount: combined.length,
          );
        }
        return combined;
      }

      if (isPrefixOfTarget(trailing)) {
        _pendingPrefixTokens = trailing;
        _pendingPrefixTimestamp = now;
      } else {
        _pendingPrefixTokens = [];
        _pendingPrefixTimestamp = null;
      }
      _allOccurrences.addAll(scanResult.occurrences);
      return scanResult.occurrences;
    }

    // 5. No full repetitions found in combined tokens:
    // Check if the current segment alone is a valid partial prefix of the target
    if (isPrefixOfTarget(candidateTokens)) {
      _pendingPrefixTokens = candidateTokens;
      _pendingPrefixTimestamp = now;
    } else {
      // Conversational or unrelated words: discard buffer completely (Case D)
      _pendingPrefixTokens = [];
      _pendingPrefixTimestamp = null;
    }

    return const [];
  }

  /// Scans a list of [candidateTokens] and returns all non-overlapping accepted occurrences
  /// along with token consumption indices.
  ScanResult scanTokens(
    List<String> candidateTokens,
    DateTime timestamp, {
    Duration? segmentDuration,
  }) {
    final normTarget = ArabicNormalizer.normalize(targetPhrase);
    if (normTarget.isEmpty || candidateTokens.isEmpty) {
      return ScanResult(
        occurrences: const [],
        lastMatchedEndIndex: 0,
        totalCandidateTokens: candidateTokens.length,
      );
    }

    final targetTokens = ArabicNormalizer.tokenize(normTarget);
    final targetTokenCount = targetTokens.length;
    final normTargetJoined = normTarget.replaceAll(' ', '');

    final isCadenceMatched = segmentDuration != null &&
        cadenceTracker != null &&
        cadenceTracker!.hasEstablishedCadence &&
        cadenceTracker!.matchesCadence(segmentDuration, allowMultiples: true);

    final List<RepetitionOccurrence> occurrences = [];
    int i = 0;
    int lastMatchedEndIndex = 0;

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
          isCadenceMatched: isCadenceMatched,
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
          lastMatchedEndIndex = i;
          matched = true;
          continue;
        }
      }

      // 2. Try multi-token windows (exact target length first, then aliases, then contracted, then expanded)
      final Set<int> aliasLengths = {};
      for (final alias in targetAliases) {
        final aCount = ArabicNormalizer.tokenize(alias).length;
        if (aCount >= 2 && aCount <= targetTokenCount + 3 && aCount != targetTokenCount) {
          aliasLengths.add(aCount);
        }
      }

      final List<int> windowLengths = [
        targetTokenCount,
        if (targetTokenCount == 2) 1,
        if (targetTokenCount >= 4) targetTokenCount - 1,
        if (targetTokenCount >= 5) targetTokenCount - 2,
        ...aliasLengths,
        if (targetTokenCount > 1) targetTokenCount + 1,
        if (targetTokenCount > 2) targetTokenCount + 2,
      ];

      for (final winLen in windowLengths) {
        if (i + winLen <= candidateTokens.length) {
          final windowPhrase = candidateTokens.sublist(i, i + winLen).join(' ');
          final windowMatch = _matcher.evaluate(
            candidate: windowPhrase,
            target: normTarget,
            targetAliases: targetAliases,
            isCadenceMatched: isCadenceMatched,
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
            i += winLen;
            lastMatchedEndIndex = i;
            matched = true;
            break;
          }
        }
      }

      // No match at index i, advance by 1 token
      if (!matched) {
        i += 1;
      }
    }

    return ScanResult(
      occurrences: occurrences,
      lastMatchedEndIndex: lastMatchedEndIndex,
      totalCandidateTokens: candidateTokens.length,
    );
  }

  /// Checks whether [tokens] strictly forms an incomplete prefix of the target phrase.
  bool isPrefixOfTarget(List<String> tokens) {
    final normTarget = ArabicNormalizer.normalize(targetPhrase);
    if (normTarget.isEmpty) return false;

    final targetTokens = ArabicNormalizer.tokenize(normTarget);
    if (tokens.isEmpty || tokens.length >= targetTokens.length) {
      return false;
    }

    final prefixCandidate = tokens.join(' ');
    final targetPrefix = targetTokens.sublist(0, tokens.length).join(' ');

    final match = _matcher.evaluate(
      candidate: prefixCandidate,
      target: targetPrefix,
      targetAliases: targetAliases
          .map((a) => ArabicNormalizer.tokenize(ArabicNormalizer.normalize(a)))
          .where((aliasTokens) => aliasTokens.length >= tokens.length)
          .map((aliasTokens) => aliasTokens.sublist(0, tokens.length).join(' '))
          .toList(),
    );

    return match.isMatch && match.level == MatchConfidenceLevel.accept;
  }

  /// Checks whether [candidateTokens] begins with the start of the target phrase
  /// (indicating the user has restarted or repeated from the beginning).
  bool startsWithTargetPrefix(List<String> candidateTokens) {
    if (candidateTokens.isEmpty) return false;
    final normTarget = ArabicNormalizer.normalize(targetPhrase);
    final targetTokens = ArabicNormalizer.tokenize(normTarget);
    if (targetTokens.isEmpty) return false;

    final checkLength = math.min(candidateTokens.length, targetTokens.length);
    final candidateSlice = candidateTokens.sublist(0, checkLength).join(' ');
    final targetSlice = targetTokens.sublist(0, checkLength).join(' ');

    final match = _matcher.evaluate(
      candidate: candidateSlice,
      target: targetSlice,
      targetAliases: targetAliases
          .map((a) => ArabicNormalizer.tokenize(ArabicNormalizer.normalize(a)))
          .where((aliasTokens) => aliasTokens.length >= checkLength)
          .map((aliasTokens) => aliasTokens.sublist(0, checkLength).join(' '))
          .toList(),
    );

    return match.isMatch && match.level == MatchConfidenceLevel.accept;
  }

  /// Evaluates whether [tokens] form a valid rapid-recitation root
  /// (e.g. "أستغفر" or "أستغفرك" trailing after a completed repetition).
  bool isPlausibleRapidRoot(List<String> tokens) {
    if (tokens.isEmpty || tokens.length > 3) return false;
    final text = ArabicNormalizer.normalize(tokens.join(' '));
    final normTarget = ArabicNormalizer.normalize(targetPhrase);

    // Istighfar: root verb "استغفر" / acoustic root variants only
    // Istighfar: root verb "استغفر" / acoustic root variants
    if (normTarget.contains('غفر') || normTarget.contains('استغفر')) {
      return text.contains('استغفر') ||
          text.contains('استوفر') ||
          text.contains('استفر') ||
          text.contains('نستغفر') ||
          text.contains('استكفر') ||
          text.contains('استكفي') ||
          text.contains('استنفي') ||
          text.contains('مستقبل') ||
          text.contains('استاذ في') ||
          text.contains('موستاج') ||
          text.contains('مستر في') ||
          text.contains('غفر');
    }

    // SubhanAllah / Tasbih: "سبحان" root
    if (normTarget.contains('سبحان')) {
      return text.contains('سبحان') ||
          text.contains('سمان') ||
          text.contains('سمحان') ||
          text.contains('سبان');
    }

    // Alhamdulillah / Tahmid: "الحمد" root
    if (normTarget.contains('حمد')) {
      return text.startsWith('الحمد') ||
          text.startsWith('حمد') ||
          text.contains('الحمد');
    }

    // Allahu Akbar / Takbir: "الله" root or "اكبر"
    if (normTarget.contains('اكبر')) {
      return text.contains('اكبر') || text.contains('كبر') || text.contains('الله');
    }

    // La ilaha illallah / Tahlil: "لا اله"
    if (normTarget.contains('لا اله') || normTarget.contains('لا إله')) {
      return text.contains('لا اله') || text.contains('اله الا');
    }

    // Hawqalah: "لا حول"
    if (normTarget.contains('حول')) {
      return text.contains('لا حول') || text.contains('لاحول');
    }

    // Hasbunallah: "حسبنا"
    if (normTarget.contains('حسبنا')) {
      return text.contains('حسبنا') || text.contains('حسنا');
    }

    // Salawat: "اللهم صل"
    if (normTarget.contains('صل') && (normTarget.contains('محمد') || normTarget.contains('اللهم'))) {
      return text.contains('اللهم') || text.contains('صل') || text.contains('صلي');
    }

    return false;
  }

  /// Scans [text] and returns all non-overlapping accepted occurrences of the target phrase.
  List<RepetitionOccurrence> findAllOccurrences(
    String text,
    DateTime timestamp,
  ) {
    final candidateTokens = ArabicNormalizer.tokenize(
      ArabicNormalizer.normalize(text),
    );
    return scanTokens(candidateTokens, timestamp).occurrences;
  }

  /// Resets detector state for a new speech segment or session.
  void reset() {
    _previouslyCommittedOccurrences = 0;
    _allOccurrences.clear();
    _pendingPrefixTokens = [];
    _pendingPrefixTimestamp = null;
    cadenceTracker?.reset();
  }
}
