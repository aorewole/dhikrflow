import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/app/app.dart';
import 'package:dhikr_counter/app/app_scope.dart';
import 'package:dhikr_counter/features/session/widgets/session_tutorial_overlay.dart';

void main() {
  testWidgets('SessionTutorialOverlay shows on first session and advances through steps', (
    WidgetTester tester,
  ) async {
    final deps = AppDependencies.forTesting();

    await tester.pumpWidget(DhikrCounterApp(dependencies: deps));
    await tester.pumpAndSettle();

    // Skip onboarding
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Start Dhikr from Home screen to open detail screen
    expect(find.text('Start Dhikr'), findsOneWidget);
    await tester.tap(find.text('Start Dhikr'));
    await tester.pumpAndSettle();

    // Tap Start Hands-Free Session to enter ActiveSessionScreen
    expect(find.text('Start Hands-Free Session'), findsOneWidget);
    await tester.tap(find.text('Start Hands-Free Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Session Tutorial Overlay is visible on first session
    expect(find.byType(SessionTutorialOverlay), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Recitation Pacing & Audio Guide'), findsOneWidget);

    // Advance to Step 2
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Hands-Free Counting'), findsOneWidget);

    // Advance to Step 3
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.text('Mindful Breath Cadence'), findsOneWidget);

    // Advance to Step 4
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('Manual +1 & Thumb Settings'), findsOneWidget);
    expect(find.text('Start Reciting'), findsOneWidget);

    // Complete tutorial
    await tester.tap(find.text('Start Reciting'));
    await tester.pump(const Duration(milliseconds: 300));

    // Overlay should be gone and counting active
    expect(find.byType(SessionTutorialOverlay), findsNothing);
    expect(deps.settingsController.hasCompletedSessionTutorial, isTrue);

    // Test re-opening tutorial via Help icon in AppBar
    final helpButton = find.byTooltip('Counting Screen Guide');
    expect(helpButton, findsOneWidget);
    await tester.tap(helpButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SessionTutorialOverlay), findsOneWidget);

    // Skip Tour button dismisses it
    await tester.tap(find.text('Skip Tour'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SessionTutorialOverlay), findsNothing);

    // End session to clean up periodic session timer
    await deps.sessionController.completeSession();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
