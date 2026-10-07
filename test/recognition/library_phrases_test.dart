import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/data/repositories/dhikr_repository.dart';
import 'package:dhikr_counter/recognition/text/arabic_normalizer.dart';
import 'package:dhikr_counter/recognition/text/phrase_matcher.dart';
import 'package:dhikr_counter/recognition/text/streaming_repetition_detector.dart';

void main() {
  group('Phase 9: Canonical Dhikr Library Phrase-Level Tests', () {
    const matcher = PhraseMatcher();
    final allAdhkar = kCanonicalAdhkar;

    test('Library contains authentic, unique canonical adhkar', () {
      expect(allAdhkar.length, 27);
      final ids = allAdhkar.map((d) => d.id).toSet();
      expect(ids.length, 27, reason: 'All Dhikr IDs must be unique');
    });

    test('Every entry has an exact match between ArabicNormalizer and normalizedArabic', () {
      for (final dhikr in allAdhkar) {
        final computed = ArabicNormalizer.normalize(dhikr.arabic);
        expect(
          computed,
          dhikr.normalizedArabic,
          reason:
              'Normalized form for ${dhikr.id} must be deterministic and identical to ArabicNormalizer output',
        );
      }
    });

    test('PhraseMatcher accepts each canonical dhikr with 1.0 confidence', () {
      for (final dhikr in allAdhkar) {
        final result = matcher.evaluate(
          candidate: dhikr.arabic,
          target: dhikr.arabic,
        );
        expect(result.isMatch, isTrue);
        expect(result.confidence, 1.0);
        expect(result.level, MatchConfidenceLevel.accept);
      }
    });

    test('StreamingRepetitionDetector counts repetitions for every dhikr in the library', () {
      for (final dhikr in allAdhkar) {
        final detector = StreamingRepetitionDetector(
          targetPhrase: dhikr.arabic,
          targetAliases: dhikr.aliases,
        );

        // 1 repetition
        final res1 = detector.processTranscript(dhikr.arabic);
        expect(
          res1.length,
          1,
          reason: 'Single recitation of ${dhikr.id} must count +1',
        );

        // Reset and test 3 continuous repetitions
        detector.reset();
        final continuous3x = '${dhikr.arabic} ${dhikr.arabic} ${dhikr.arabic}';
        final res3 = detector.processTranscript(continuous3x);
        expect(
          res3.length,
          3,
          reason: 'Triple continuous recitation of ${dhikr.id} must count +3',
        );
        expect(detector.totalAcceptedOccurrences, 3);
      }
    });

    test('Cross-phrase discrimination: distinct adhkar never trigger false positive counts', () {
      for (int i = 0; i < allAdhkar.length; i++) {
        final targetDhikr = allAdhkar[i];
        final otherDhikr = allAdhkar[(i + 1) % allAdhkar.length];

        // If otherDhikr is an extension/continuation that literally contains the target phrase
        // (e.g. "Astaghfirullah wa atubu ilayh" begins with "Astaghfirullah"),
        // the streaming detector is designed to recognize the subphrase.
        if (otherDhikr.normalizedArabic.startsWith(targetDhikr.normalizedArabic)) {
          continue;
        }

        final detector = StreamingRepetitionDetector(
          targetPhrase: targetDhikr.arabic,
          targetAliases: targetDhikr.aliases,
        );

        // Recite the other dhikr
        final occurrences = detector.processTranscript(otherDhikr.arabic);
        expect(
          occurrences.isEmpty,
          isTrue,
          reason:
              'Reciting "${otherDhikr.transliteration}" while targeting "${targetDhikr.transliteration}" must produce +0',
        );
        expect(detector.totalAcceptedOccurrences, 0);
      }
    });
  });
}
