import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/recognition/text/arabic_normalizer.dart';

void main() {
group('ArabicNormalizer Bilingual Cleaning & Normalization Tests', () {
    test('cleans punctuation and numbers while preserving Arabic and Latin transliterations', () {
      expect(
        ArabicNormalizer.cleanTranscript('أستغفر الله 123!'),
        equals('أستغفر الله'),
      );
      expect(
        ArabicNormalizer.cleanTranscript('Astaghfirullah, 456.'),
        equals('Astaghfirullah'),
      );
      expect(
        ArabicNormalizer.cleanTranscript('سبحان الله / SubhanAllah'),
        equals('سبحان الله SubhanAllah'),
      );
    });

    test('discards pure digits and punctuation', () {
      expect(ArabicNormalizer.cleanTranscript('1 2 3 4'), isEmpty);
      expect(ArabicNormalizer.cleanTranscript('!@#\$%^&*()'), isEmpty);
    });

    test('suppresses autoregressive repetition loops on silence', () {
      expect(ArabicNormalizer.cleanTranscript('س س س س س س'), isEmpty);
      expect(ArabicNormalizer.cleanTranscript('و و و و و و'), isEmpty);
      expect(ArabicNormalizer.cleanTranscript('  و   و   و   '), isEmpty);
      expect(ArabicNormalizer.cleanTranscript('s s s s s'), isEmpty);
    });

    test('preserves legitimate Arabic phrases cleanly', () {
      expect(
        ArabicNormalizer.cleanTranscript('أَسْتَغْفِرُ اللَّهَ'),
        equals('أَسْتَغْفِرُ اللَّهَ'),
      );
      expect(
        ArabicNormalizer.cleanTranscript('سبحان الله وبحمده'),
        equals('سبحان الله وبحمده'),
      );
      expect(
        ArabicNormalizer.cleanTranscript('الله أكبر'),
        equals('الله أكبر'),
      );
    });

    test('normalize produces clean normalized comparison string for both Arabic and Latin', () {
      expect(
        ArabicNormalizer.normalize('أَسْتَغْفِرُ اللَّهَ'),
        equals('استغفر الله'),
      );
      expect(
        ArabicNormalizer.normalize('Astaghfirullah'),
        equals('astaghfirullah'),
      );
      expect(
        ArabicNormalizer.normalize('Allāhu  Akbar'),
        equals('allahu akbar'),
      );
    });
  });
}
