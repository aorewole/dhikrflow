import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/app/app.dart';
import 'package:dhikr_counter/app/app_scope.dart';

void main() {
  testWidgets('App launches to onboarding and navigates to home', (
    WidgetTester tester,
  ) async {
    final deps = AppDependencies.forTesting();

    await tester.pumpWidget(DhikrCounterApp(dependencies: deps));
    await tester.pumpAndSettle();

    // Verify Onboarding / Tutorial screen content
    expect(find.text('Welcome to DhikrFlow'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap Skip to navigate straight to Home
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify Home screen rendered
    expect(find.text('Peace be upon you'), findsOneWidget);
    expect(find.text('Daily Adhkar'), findsOneWidget);
    expect(find.text('Start Dhikr'), findsOneWidget);
  });
}
