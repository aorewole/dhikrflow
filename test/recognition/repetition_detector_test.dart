import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/recognition/text/arabic_normalizer.dart';
import 'package:dhikr_counter/recognition/text/phrase_matcher.dart';
import 'package:dhikr_counter/recognition/text/streaming_repetition_detector.dart';

void main() {
  group('ArabicNormalizer Tests', () {
    test('strips all diacritics / tashkeel', () {
      const input = 'أَسْتَغْفِرُ ٱللَّٰهَ رَبِّي وَأَتُوبُ إِلَيْهِ';
      final normalized = ArabicNormalizer.normalize(input);
      // Diacritics removed, alef variants unified
      expect(normalized, contains('استغفر'));
      expect(normalized, contains('الله'));
      expect(normalized, isNot(contains('\u064E'))); // fathah
      expect(normalized, isNot(contains('\u0651'))); // shaddah
      expect(normalized, isNot(contains('\u0650'))); // kasrah
    });

    test('normalizes alef variants to bare alef', () {
      expect(ArabicNormalizer.normalize('أ'), 'ا');
      expect(ArabicNormalizer.normalize('إ'), 'ا');
      expect(ArabicNormalizer.normalize('آ'), 'ا');
      expect(ArabicNormalizer.normalize('ٱ'), 'ا');
      expect(ArabicNormalizer.normalize('أستغفر'), 'استغفر');
      expect(ArabicNormalizer.normalize('ٱللَّٰهَ'), 'الله');
    });

    test('normalizes teh marbuta and alef maksura', () {
      expect(ArabicNormalizer.normalize('حياة'), 'حياه');
      expect(ArabicNormalizer.normalize('على'), 'علي');
    });

    test('strips punctuation and collapses whitespace', () {
      const input = '  أستغفر   الله! ، وسبحان الله؟  ';
      final normalized = ArabicNormalizer.normalize(input);
      expect(normalized, 'استغفر الله وسبحان الله');
    });

    test('tokenizes normalized words correctly', () {
      const input = 'أَسْتَغْفِرُ اللَّهَ';
      final tokens = ArabicNormalizer.tokenize(input);
      expect(tokens, ['استغفر', 'الله']);
    });
  });

  group('PhraseMatcher Tests', () {
    const matcher = PhraseMatcher();
    const target = 'أَسْتَغْفِرُ اللَّهَ';

    test('exact match with diacritics variation gives 1.0 confidence', () {
      final result = matcher.evaluate(candidate: 'استغفر الله', target: target);
      expect(result.isMatch, isTrue);
      expect(result.confidence, 1.0);
      expect(result.level, MatchConfidenceLevel.accept);
    });

    test(
      'fuzzy match with minor ASR character omission meets accept threshold',
      () {
        // Missing final 'h' in Allah
        final result = matcher.evaluate(
          candidate: 'استغفر الل',
          target: target,
        );
        expect(result.confidence, greaterThanOrEqualTo(0.85));
        expect(result.isMatch, isTrue);
      },
    );

    test('unrelated phrase is rejected with ignore level', () {
      final result = matcher.evaluate(
        candidate: 'الحمد لله رب العالمين',
        target: target,
      );
      expect(result.isMatch, isFalse);
      expect(result.level, MatchConfidenceLevel.ignore);
    });

    test('supported alias matches with high confidence', () {
      final result = matcher.evaluate(
        candidate: 'استغفر بالله',
        target: target,
        targetAliases: ['أستغفر بالله'],
      );
      expect(result.isMatch, isTrue);
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.level, MatchConfidenceLevel.accept);
    });
  });

  group('StreamingRepetitionDetector Mandatory Tests (docs/BUILD_ROADMAP.md Phase 6)', () {
    const target = 'أَسْتَغْفِرُ اللَّهَ';

    test('Mandatory 1: One Astaghfirullah -> +1', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      final newOccurrences = detector.processTranscript('أستغفر الله');

      expect(newOccurrences.length, 1);
      expect(detector.totalAcceptedOccurrences, 1);
    });

    test('Mandatory 2: Two repetitions -> +2', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      final newOccurrences = detector.processTranscript(
        'أستغفر الله أستغفر الله',
      );

      expect(newOccurrences.length, 2);
      expect(detector.totalAcceptedOccurrences, 2);
    });

    test('Mandatory 3: Four rapid repetitions -> +4', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      const rapidStream = 'أستغفر الله أستغفر الله أستغفر الله أستغفر الله';
      final newOccurrences = detector.processTranscript(rapidStream);

      expect(newOccurrences.length, 4);
      expect(detector.totalAcceptedOccurrences, 4);
    });

    test('Mandatory 4: Ten repetitions -> +10', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      final tenRepetitions = List.filled(10, 'أستغفر الله').join(' ');
      final newOccurrences = detector.processTranscript(tenRepetitions);

      expect(newOccurrences.length, 10);
      expect(detector.totalAcceptedOccurrences, 10);
    });

    test(
      'Mandatory 5: Partial hypothesis updates for one repetition -> still +1',
      () {
        final detector = StreamingRepetitionDetector(targetPhrase: target);

        // P0: Incomplete word
        final p0 = detector.processTranscript('استغ');
        expect(p0.length, 0);
        expect(detector.totalAcceptedOccurrences, 0);

        // P1: Incomplete phrase
        final p1 = detector.processTranscript('استغفر');
        expect(p1.length, 0);
        expect(detector.totalAcceptedOccurrences, 0);

        // P2: Full target committed
        final p2 = detector.processTranscript('استغفر الله');
        expect(p2.length, 1);
        expect(detector.totalAcceptedOccurrences, 1);

        // P3: Repeated same transcript without new words
        final p3 = detector.processTranscript('استغفر الله');
        expect(
          p3.length,
          0,
          reason: 'Duplicate hypothesis must not increment counter',
        );
        expect(detector.totalAcceptedOccurrences, 1);
      },
    );

    test('Mandatory 6: Unrelated speech -> +0', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      final occurrences = detector.processTranscript(
        'صباح الخير كيف حالك اليوم',
      );

      expect(occurrences.isEmpty, isTrue);
      expect(detector.totalAcceptedOccurrences, 0);
    });

    test('Mandatory 7: Target mixed with unrelated words -> count only accepted target occurrences', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      const mixedTranscript =
          'ثم قال أستغفر الله وبعد ذلك جلس وقال أستغفر الله ثم دعا ربه';
      final occurrences = detector.processTranscript(mixedTranscript);

      expect(occurrences.length, 2);
      expect(detector.totalAcceptedOccurrences, 2);
    });

    test('Multi-step streaming evolution with rapid increments', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);

      // Stream Step 1: 1 repetition
      var newOnes = detector.processTranscript('أستغفر الله');
      expect(newOnes.length, 1);

      // Stream Step 2: 1 repetition + partial second
      newOnes = detector.processTranscript('أستغفر الله استغفر');
      expect(newOnes.length, 0); // No new complete repetition yet

      // Stream Step 3: 2 repetitions completed
      newOnes = detector.processTranscript('أستغفر الله استغفر الله');
      expect(newOnes.length, 1);
      expect(detector.totalAcceptedOccurrences, 2);

      // Stream Step 4: Rapid jump to 4 repetitions
      newOnes = detector.processTranscript(
        'أستغفر الله استغفر الله استغفر الله استغفر الله',
      );
      expect(newOnes.length, 2);
      expect(detector.totalAcceptedOccurrences, 4);
    });

    test('Handles joined word form (استغفرالله without space)', () {
      final detector = StreamingRepetitionDetector(targetPhrase: target);
      final occurrences = detector.processTranscript('استغفرالله استغفرالله');

      expect(occurrences.length, 2);
      expect(detector.totalAcceptedOccurrences, 2);
    });
  });

  group('Multi-Segment Rolling Accumulator Tests (Subhanallahi wa bihamdihi)', () {
    const multiTarget = 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';

    test('Case A: Segment 1 (SubhanAllah) + Segment 2 (wa bihamdihi) -> +1', () {
      final detector = StreamingRepetitionDetector(targetPhrase: multiTarget);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Segment 1: "سبحان الله" (partial prefix)
      final seg1 = detector.processSegment('سبحان الله', timestamp: t0);
      expect(seg1.isEmpty, isTrue, reason: 'Incomplete prefix must not count');
      expect(detector.pendingPrefixTokens, ['سبحان', 'الله']);

      // Segment 2: "وبحمده" within 800ms
      final seg2 = detector.processSegment(
        'وبحمده',
        timestamp: t0.add(const Duration(milliseconds: 800)),
      );
      expect(seg2.length, 1, reason: 'Joined segments must complete the phrase');
      expect(detector.pendingPrefixTokens.isEmpty, isTrue);
      expect(detector.totalAcceptedOccurrences, 1);
    });

    test('Single-segment full recitation -> +1 immediately', () {
      final detector = StreamingRepetitionDetector(targetPhrase: multiTarget);
      final seg = detector.processSegment('سبحان الله وبحمده');

      expect(seg.length, 1);
      expect(detector.pendingPrefixTokens.isEmpty, isTrue);
      expect(detector.totalAcceptedOccurrences, 1);
    });

    test('Case C: Prefix restart discards stale partial buffer', () {
      final detector = StreamingRepetitionDetector(targetPhrase: multiTarget);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Segment 1: "سبحان الله"
      detector.processSegment('سبحان الله', timestamp: t0);
      expect(detector.pendingPrefixTokens, ['سبحان', 'الله']);

      // Segment 2: User repeats Segment 1 ("سبحان الله") instead of Segment 2
      final seg2 = detector.processSegment(
        'سبحان الله',
        timestamp: t0.add(const Duration(milliseconds: 600)),
      );
      expect(seg2.isEmpty, isTrue);
      // Stale previous buffer was discarded and replaced with new Segment 1
      expect(detector.pendingPrefixTokens, ['سبحان', 'الله']);
      expect(detector.totalAcceptedOccurrences, 0);

      // Segment 3: Now user finishes with "وبحمده"
      final seg3 = detector.processSegment(
        'وبحمده',
        timestamp: t0.add(const Duration(milliseconds: 1200)),
      );
      expect(seg3.length, 1);
      expect(detector.pendingPrefixTokens.isEmpty, isTrue);
      expect(detector.totalAcceptedOccurrences, 1);
    });

    test('Case B: Timeout / abandonment discards stale buffer after maxStalenessDuration', () {
      final detector = StreamingRepetitionDetector(
        targetPhrase: multiTarget,
        maxStalenessDuration: const Duration(seconds: 3),
      );
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Segment 1: "سبحان الله"
      detector.processSegment('سبحان الله', timestamp: t0);
      expect(detector.pendingPrefixTokens, ['سبحان', 'الله']);

      // Segment 2 arrives after 4 seconds (timeout expired) with "وبحمده"
      final seg2 = detector.processSegment(
        'وبحمده',
        timestamp: t0.add(const Duration(seconds: 4)),
      );
      expect(seg2.isEmpty, isTrue, reason: 'Stale prefix must be discarded on timeout');
      expect(detector.totalAcceptedOccurrences, 0);
      expect(detector.pendingPrefixTokens.isEmpty, isTrue);
    });

    test('Case D: Irrelevant / conversational speech discards partial buffer', () {
      final detector = StreamingRepetitionDetector(targetPhrase: multiTarget);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Segment 1: "سبحان الله"
      detector.processSegment('سبحان الله', timestamp: t0);
      expect(detector.pendingPrefixTokens, ['سبحان', 'الله']);

      // Segment 2: Conversational speech "شكرا جزيلا كيف حالك"
      final seg2 = detector.processSegment(
        'شكرا جزيلا كيف حالك',
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );
      expect(seg2.isEmpty, isTrue);
      expect(detector.pendingPrefixTokens.isEmpty, isTrue);
      expect(detector.totalAcceptedOccurrences, 0);
    });

    test('Multi-word dhikr with 6 tokens: La hawla wa la quwwata illa billah', () {
      const hawqala = 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ';
      final detector = StreamingRepetitionDetector(targetPhrase: hawqala);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Chunk 1: "لا حول ولا قوة" (4 tokens)
      final c1 = detector.processSegment(
        'لا حول ولا قوة',
        timestamp: t0,
      );
      expect(c1.isEmpty, isTrue);
      expect(detector.pendingPrefixTokens, ['لا', 'حول', 'ولا', 'قوه']);

      // Chunk 2: "إلا بالله" (2 tokens)
      final c2 = detector.processSegment(
        'الا بالله',
        timestamp: t0.add(const Duration(milliseconds: 900)),
      );
      expect(c2.length, 1);
      expect(detector.pendingPrefixTokens.isEmpty, isTrue);
      expect(detector.totalAcceptedOccurrences, 1);
    });
  });
}
