import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/recognition/text/phrase_matcher.dart';
import 'package:dhikr_counter/recognition/text/recitation_cadence_tracker.dart';
import 'package:dhikr_counter/recognition/text/streaming_repetition_detector.dart';

void main() {
  group('RecitationCadenceTracker Tests', () {
    test('initial state has no established cadence', () {
      final tracker = RecitationCadenceTracker();
      expect(tracker.hasEstablishedCadence, isFalse);
      expect(tracker.sampleCount, 0);
      expect(tracker.expectedPace, isNull);
      expect(tracker.matchesCadence(const Duration(milliseconds: 1000)), isFalse);
    });

    test('learns expected pace from confirmed samples (median calculation)', () {
      final tracker = RecitationCadenceTracker();
      tracker.recordDuration(const Duration(milliseconds: 1000));
      expect(tracker.hasEstablishedCadence, isTrue);
      expect(tracker.sampleCount, 1);
      expect(tracker.expectedPace, const Duration(milliseconds: 1000));

      // Add more samples
      tracker.recordDuration(const Duration(milliseconds: 1200));
      tracker.recordDuration(const Duration(milliseconds: 950));
      // Sorted: [950, 1000, 1200] -> median is 1000ms
      expect(tracker.expectedPace, const Duration(milliseconds: 1000));
    });

    test('multi-repetition segment calculates per-repetition duration correctly', () {
      final tracker = RecitationCadenceTracker();
      // 3 repetitions in 3300ms -> 1100ms per repetition
      tracker.recordDuration(const Duration(milliseconds: 3300), repetitionCount: 3);
      expect(tracker.expectedPace, const Duration(milliseconds: 1100));
    });

    test('filters out extreme acoustic anomalies (<250ms or >12000ms)', () {
      final tracker = RecitationCadenceTracker();
      tracker.recordDuration(const Duration(milliseconds: 100)); // transient tap
      tracker.recordDuration(const Duration(milliseconds: 15000)); // runaway noise
      expect(tracker.hasEstablishedCadence, isFalse);
      expect(tracker.sampleCount, 0);
    });

    test('matchesCadence validates durations within tolerance (default +/-35%)', () {
      final tracker = RecitationCadenceTracker(tolerance: 0.35);
      tracker.recordDuration(const Duration(milliseconds: 1000));
      // Acceptable window: 650ms to 1350ms

      expect(tracker.matchesCadence(const Duration(milliseconds: 1000)), isTrue);
      expect(tracker.matchesCadence(const Duration(milliseconds: 700)), isTrue);
      expect(tracker.matchesCadence(const Duration(milliseconds: 1300)), isTrue);

      // Outside tolerance
      expect(tracker.matchesCadence(const Duration(milliseconds: 500)), isFalse);
      expect(tracker.matchesCadence(const Duration(milliseconds: 1500)), isFalse);
    });

    test('matchesCadence dynamically identifies multi-repetition segments', () {
      final tracker = RecitationCadenceTracker(tolerance: 0.35);
      tracker.recordDuration(const Duration(milliseconds: 1000));

      // 2 repetitions (~2000ms) matches k=2 with allowMultiples
      expect(
        tracker.matchesCadence(
          const Duration(milliseconds: 2100),
          allowMultiples: true,
        ),
        isTrue,
      );
      // 3 repetitions (~3000ms) matches k=3 with allowMultiples
      expect(
        tracker.matchesCadence(
          const Duration(milliseconds: 2950),
          allowMultiples: true,
        ),
        isTrue,
      );
      // Unrelated duration (e.g. 500ms) does not match
      expect(tracker.matchesCadence(const Duration(milliseconds: 500)), isFalse);
    });

    test('calculateCadenceSimilarity returns 1.0 on exact match and scales down', () {
      final tracker = RecitationCadenceTracker(tolerance: 0.35);
      tracker.recordDuration(const Duration(milliseconds: 1000));

      expect(
        tracker.calculateCadenceSimilarity(const Duration(milliseconds: 1000)),
        closeTo(1.0, 0.01),
      );
      expect(
        tracker.calculateCadenceSimilarity(const Duration(milliseconds: 1175)),
        closeTo(0.5, 0.05),
      );
      expect(
        tracker.calculateCadenceSimilarity(const Duration(milliseconds: 1500)),
        0.0,
      );
    });

    test('reset clears all history', () {
      final tracker = RecitationCadenceTracker();
      tracker.recordDuration(const Duration(milliseconds: 1000));
      expect(tracker.hasEstablishedCadence, isTrue);

      tracker.reset();
      expect(tracker.hasEstablishedCadence, isFalse);
      expect(tracker.sampleCount, 0);
      expect(tracker.expectedPace, isNull);
    });
  });

  group('Cadence-Aware Phrase Matching Integration Tests', () {
    const matcher = PhraseMatcher(
      acceptThreshold: 0.74,
      uncertainThreshold: 0.55,
    );
    const target = 'أَسْتَغْفِرُ اللَّهَ';

    test('exact match is accepted regardless of cadence', () {
      final result = matcher.evaluate(
        candidate: 'أستغفر الله',
        target: target,
        isCadenceMatched: false,
      );
      expect(result.isMatch, isTrue);
      expect(result.level, MatchConfidenceLevel.accept);
      expect(result.confidence, 1.0);
    });

    test('near-miss candidate without cadence match is held as uncertain', () {
      // "استغفر ربي" has phonetic similarity ~0.60 (between 0.55 and 0.74)
      final rawResult = matcher.evaluate(
        candidate: 'استغفر ربي',
        target: target,
        isCadenceMatched: false,
      );
      expect(rawResult.confidence, greaterThanOrEqualTo(0.55));
      expect(rawResult.confidence, lessThan(0.74));
      expect(rawResult.isMatch, isFalse);
      expect(rawResult.level, MatchConfidenceLevel.uncertain);
    });

    test('near-miss candidate WITH cadence match is rescued and accepted (+1)', () {
      // When cadence matches the user rhythm, cadenceBonus (+0.18) boosts the score
      final boostedResult = matcher.evaluate(
        candidate: 'استغفر ربي',
        target: target,
        isCadenceMatched: true,
        cadenceBonus: 0.18,
      );
      expect(boostedResult.isMatch, isTrue);
      expect(boostedResult.level, MatchConfidenceLevel.accept);
      expect(boostedResult.confidence, greaterThanOrEqualTo(0.74));
    });

    test('completely unrelated speech is rejected even with cadence match', () {
      // Conversational phrase has score ~0.15 (< 0.55) -> cadence bonus cannot rescue it
      final unrelatedResult = matcher.evaluate(
        candidate: 'مرحبا كيف حالك اليوم',
        target: target,
        isCadenceMatched: true,
        cadenceBonus: 0.18,
      );
      expect(unrelatedResult.isMatch, isFalse);
      expect(unrelatedResult.level, MatchConfidenceLevel.ignore);
      expect(unrelatedResult.confidence, lessThan(0.55));
    });
  });

  group('StreamingRepetitionDetector with CadenceTracker', () {
    const target = 'أَسْتَغْفِرُ اللَّهَ';

    test('rescues cadence-timed near-miss in end-to-end segment processing', () {
      final cadenceTracker = RecitationCadenceTracker();
      final detector = StreamingRepetitionDetector(
        targetPhrase: target,
        cadenceTracker: cadenceTracker,
      );

      // Repetition 1: Clear recitation establishes the 1000ms cadence
      final seg1 = detector.processSegment(
        'أستغفر الله',
        segmentDuration: const Duration(milliseconds: 1000),
      );
      expect(seg1.length, 1);
      expect(cadenceTracker.hasEstablishedCadence, isTrue);
      expect(cadenceTracker.expectedPace, const Duration(milliseconds: 1000));

      // Repetition 2: Near-miss "مستوفر الله" recited in 1050ms (within cadence window)
      final seg2 = detector.processSegment(
        'مستوفر الله',
        segmentDuration: const Duration(milliseconds: 1050),
      );
      expect(seg2.length, 1, reason: 'Cadence match should rescue near-miss recitation');
      expect(detector.totalAcceptedOccurrences, 2);

      // Repetition 3: Unrelated noise in 1000ms must still be rejected
      final seg3 = detector.processSegment(
        'شكرا مع السلامة',
        segmentDuration: const Duration(milliseconds: 1000),
      );
      expect(seg3.isEmpty, isTrue, reason: 'Noise must never count despite matching duration');
      expect(detector.totalAcceptedOccurrences, 2);
    });
  });
}
