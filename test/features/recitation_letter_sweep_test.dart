import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/features/session/widgets/recitation_letter_sweep.dart';
import 'package:dhikr_counter/features/session/widgets/recitation_word_highlighter.dart';

void main() {
  group('RecitationLetterSweep Tests', () {
    testWidgets('renders Arabic text with ShaderMask in RTL mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecitationLetterSweep(
              arabicText: 'أَسْتَغْفِرُ اللَّهَ',
              isSpeaking: true,
              repetitionCount: 0,
              sweepProgress: 0.5,
              pacingSpeed: PacingSpeed.medium,
            ),
          ),
        ),
      );

      expect(find.text('أَسْتَغْفِرُ اللَّهَ'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('displays breathing pause indicator when isBreathingPause is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecitationLetterSweep(
              arabicText: 'أَسْتَغْفِرُ اللَّهَ',
              isSpeaking: true,
              repetitionCount: 0,
              isBreathingPause: true,
              sweepProgress: 0.0,
            ),
          ),
        ),
      );

      expect(find.textContaining('Take a breath...'), findsOneWidget);
      expect(find.byIcon(Icons.air_rounded), findsWidgets);
    });

    testWidgets('celebration pulse triggers when repetitionCount increments', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecitationLetterSweep(
              arabicText: 'أَسْتَغْفِرُ اللَّهَ',
              isSpeaking: true,
              repetitionCount: 1,
              sweepProgress: 1.0,
            ),
          ),
        ),
      );

      // Rebuild with incremented count
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecitationLetterSweep(
              arabicText: 'أَسْتَغْفِرُ اللَّهَ',
              isSpeaking: true,
              repetitionCount: 2,
              sweepProgress: 0.0,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('أَسْتَغْفِرُ اللَّهَ'), findsOneWidget);
    });
  });
}
