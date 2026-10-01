import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/app/app.dart';
import 'package:dhikr_counter/app/app_scope.dart';

void main() {
  testWidgets('App launches to onboarding and navigates to home', (
    WidgetTester tester,
  ) async {
    final deps = AppDependencies.initialize();

    await tester.pumpWidget(DhikrCounterApp(dependencies: deps));
    await tester.pumpAndSettle();

    // Verify Onboarding screen content
    expect(find.text('Dhikr Counter'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byIcon(Icons.airplanemode_active_rounded), findsOneWidget);

    // Scroll to and tap Get Started
    await tester.ensureVisible(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify Home screen rendered
    expect(find.text('Peace be upon you'), findsOneWidget);
    expect(find.text('Daily Adhkar'), findsOneWidget);
    expect(find.text('Start Dhikr'), findsOneWidget);
  });
}
