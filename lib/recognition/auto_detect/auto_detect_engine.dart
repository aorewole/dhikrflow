import '../../domain/events/count_events.dart';
import '../../domain/models/dhikr_definition.dart';
import '../text/arabic_normalizer.dart';
import '../text/phrase_matcher.dart';
import '../text/streaming_repetition_detector.dart';

/// Candidate match evaluated during auto-detect phrase matching.
class AutoDetectCandidate {
  final DhikrDefinition dhikr;
  final double confidence;
  final int occurrences;

  const AutoDetectCandidate({
    required this.dhikr,
    required this.confidence,
    required this.occurrences,
  });
}

/// Experimental recognition layer that automatically identifies which dhikr
/// the user is reciting from the local dhikr library.
///
/// Follows specifications in `AGENTS.md` and `docs/BUILD_ROADMAP.md` Phase 13:
/// - Experimental mode; selected-dhikr mode remains default.
/// - Requires elevated confidence (>= 0.88) before locking to a detected target.
/// - Strictly prevents accidental silent target switching while reciting.
/// - 100% on-device local matching against canonical library adhkar.
class AutoDetectEngine {
  final List<DhikrDefinition> supportedLibrary;
  final PhraseMatcher matcher;
  final double lockConfidenceThreshold;

  DhikrDefinition? _lockedTarget;
  StreamingRepetitionDetector? _activeDetector;

  AutoDetectEngine({
    required this.supportedLibrary,
    this.matcher = const PhraseMatcher(),
    this.lockConfidenceThreshold = 0.88,
  });

  /// The currently locked dhikr, or null if still awaiting user recitation.
  DhikrDefinition? get lockedTarget => _lockedTarget;

  /// Whether a specific dhikr has been identified and locked.
  bool get isTargetLocked => _lockedTarget != null;

  /// Resets auto-detect state to allow detecting a new target phrase.
  void reset() {
    _lockedTarget = null;
    _activeDetector?.reset();
    _activeDetector = null;
  }

  /// Manually locks the engine to a specific [dhikr] (e.g. user confirmed).
  void lockToTarget(DhikrDefinition dhikr) {
    _lockedTarget = dhikr;
    _activeDetector = StreamingRepetitionDetector(
      targetPhrase: dhikr.arabic,
      targetAliases: dhikr.aliases,
      matcher: matcher,
    );
  }

  /// Evaluates an incoming [transcript] from ASR:
  /// - If target is not yet locked: scans the library to identify and lock the target.
  /// - If target is locked: increments repetitions and rejects silent target switching.
  List<DhikrCountEvent> processTranscript(
    String transcript, {
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    if (_lockedTarget == null) {
      // 1. Scan supported library to identify candidate match
      final candidate = _findBestCandidate(transcript, now);
      if (candidate == null || candidate.confidence < lockConfidenceThreshold) {
        // Insufficient confidence or unrelated speech: do not lock
        return const [];
      }

      // 2. Lock to the detected target dhikr
      lockToTarget(candidate.dhikr);

      // 3. Process through active detector so evolving hypotheses remain synchronized
      final occurrences = _activeDetector!.processTranscript(
        transcript,
        timestamp: now,
      );

      if (occurrences.isNotEmpty) {
        return occurrences
            .map(
              (occ) => DhikrCountEvent(
                phraseId: candidate.dhikr.id,
                confidence: occ.confidence,
                timestamp: occ.timestamp,
                source: CountSource.voice,
                increment: 1,
              ),
            )
            .toList();
      }

      final count = candidate.occurrences > 0 ? candidate.occurrences : 1;
      return [
        DhikrCountEvent(
          phraseId: candidate.dhikr.id,
          confidence: candidate.confidence,
          timestamp: now,
          source: CountSource.voice,
          increment: count,
        ),
      ];
    } else {
      // Target is already locked: count repetitions for locked target only
      // Safeguard: strictly prevents accidental silent target switching
      final occurrences =
          _activeDetector?.processTranscript(transcript, timestamp: now) ??
          const [];

      return occurrences
          .map(
            (occ) => DhikrCountEvent(
              phraseId: _lockedTarget!.id,
              confidence: occ.confidence,
              timestamp: occ.timestamp,
              source: CountSource.voice,
              increment: 1,
            ),
          )
          .toList();
    }
  }

  AutoDetectCandidate? _findBestCandidate(String transcript, DateTime now) {
    final normTranscript = ArabicNormalizer.normalize(transcript);
    if (normTranscript.isEmpty) return null;

    AutoDetectCandidate? bestCandidate;

    for (final dhikr in supportedLibrary) {
      final normTarget = ArabicNormalizer.normalize(dhikr.arabic);
      final match = matcher.evaluate(
        candidate: normTranscript,
        target: normTarget,
        targetAliases: dhikr.aliases,
      );

      if (match.isMatch && match.confidence >= lockConfidenceThreshold) {
        // Check repetition count for this candidate
        final tempDetector = StreamingRepetitionDetector(
          targetPhrase: dhikr.arabic,
          targetAliases: dhikr.aliases,
          matcher: matcher,
        );
        final occurrences = tempDetector.findAllOccurrences(
          normTranscript,
          now,
        );

        if (bestCandidate == null || match.confidence > bestCandidate.confidence) {
          bestCandidate = AutoDetectCandidate(
            dhikr: dhikr,
            confidence: match.confidence,
            occurrences: occurrences.length,
          );
        }
      }
    }

    return bestCandidate;
  }
}
