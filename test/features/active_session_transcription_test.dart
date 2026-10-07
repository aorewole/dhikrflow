import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/app/app_scope.dart';
import 'package:dhikr_counter/features/session/active_session_screen.dart';
import 'package:dhikr_counter/recognition/mock_recognition_engine.dart';

void main() {
  testWidgets(
    'ActiveSessionScreen live transcription callout displays and expands',
    (WidgetTester tester) async {
      final mockEngine = MockRecognitionEngine();
      final deps = AppDependencies.forTesting(recognitionEngine: mockEngine);

      final allDhikr = deps.dhikrRepository.getAll();
      final dhikr = allDhikr.first;
      await deps.settingsController.setHasCompletedSessionTutorial(true);
      await deps.sessionController.startSession(dhikr: dhikr);

      // Launch ActiveSessionScreen directly
      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            dependencies: deps,
            child: const ActiveSessionScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // By default, Acoustic Telemetry is hidden for a clean, calm user experience
      expect(find.text('Acoustic Telemetry'), findsNothing);

      // Tap AppBar diagnostics button to reveal
      await tester.tap(find.byTooltip('Show Recognition Diagnostics'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify ActiveSessionScreen is displayed with Acoustic Telemetry callout
      expect(find.text('Acoustic Telemetry'), findsOneWidget);
      expect(find.text('Awaiting speech...'), findsOneWidget);

      // Expanded state shows guidance when empty
      expect(find.textContaining('Recite your dhikr at your natural pace'), findsOneWidget);

      // Simulate a voice count recognition event
      mockEngine.simulateVoiceCount(confidence: 0.94);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify latest recognized utterance is displayed with Arabic and confidence
      expect(find.text('LATEST RECOGNIZED'), findsOneWidget);
      expect(find.text(dhikr.arabic), findsAtLeastNWidgets(1));
      expect(find.text('94%'), findsOneWidget);
      expect(find.textContaining('Voiced repetition confirmed'), findsOneWidget);

      // Verify "Copy Log" button works
      expect(find.text('Copy Log'), findsOneWidget);
      await tester.ensureVisible(find.text('Copy Log'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Copy Log'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Transcription log copied! Paste it into the chat.'), findsOneWidget);

      // Verify "Clear" button clears items
      await tester.ensureVisible(find.text('Clear'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Clear'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Recite your dhikr at your natural pace'), findsOneWidget);

      // Clean up session and timer
      await deps.sessionController.endCurrentSessionSilently();
    },
  );
}
