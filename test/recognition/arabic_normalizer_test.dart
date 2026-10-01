import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/recognition/text/arabic_normalizer.dart';

void main() {
  group('ArabicNormalizer Strict Arabic Enforcement Tests', () {
    test('strips English hallucinated words from Arabic transcripts', () {
      expect(
        ArabicNormalizer.cleanStrictArabic('أستعب في the law'),
        equals('أستعب في'),
      );
      expect(
        ArabicNormalizer.cleanStrictArabic('وعلم like'),
        equals('وعلم'),
      );
      expect(
        ArabicNormalizer.cleanStrictArabic('سبحان الله English test'),
        equals('سبحان الله'),
      );
    });

    test('discards non-Arabic speech completely', () {
      expect(ArabicNormalizer.cleanStrictArabic('1 2 3 4'), isEmpty);
      expect(ArabicNormalizer.cleanStrictArabic('hello how are you'), isEmpty);
      expect(ArabicNormalizer.cleanStrictArabic('one two three'), isEmpty);
      expect(ArabicNormalizer.cleanStrictArabic('!@#\$%^&*()'), isEmpty);
    });

    test('suppresses autoregressive repetition loops on silence', () {
      expect(ArabicNormalizer.cleanStrictArabic('س س س س س س'), isEmpty);
      expect(ArabicNormalizer.cleanStrictArabic('و و و و و و'), isEmpty);
      expect(ArabicNormalizer.cleanStrictArabic('  و   و   و   '), isEmpty);
    });

    test('preserves legitimate Arabic phrases cleanly', () {
      expect(
        ArabicNormalizer.cleanStrictArabic('أَسْتَغْفِرُ اللَّهَ'),
        equals('أَسْتَغْفِرُ اللَّهَ'),
      );
      expect(
        ArabicNormalizer.cleanStrictArabic('سبحان الله وبحمده'),
        equals('سبحان الله وبحمده'),
      );
      expect(
        ArabicNormalizer.cleanStrictArabic('الله أكبر'),
        equals('الله أكبر'),
      );
    });

    test('normalize produces clean normalized comparison string without English', () {
      expect(
        ArabicNormalizer.normalize('أستعب في the law'),
        equals('استعب في'),
      );
      expect(
        ArabicNormalizer.normalize('أَسْتَغْفِرُ اللَّهَ'),
        equals('استغفر الله'),
      );
    });
  });
}
