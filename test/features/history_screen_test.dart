import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/app/app_scope.dart';
import 'package:dhikr_counter/data/repositories/dhikr_repository.dart';
import 'package:dhikr_counter/data/repositories/session_repository.dart';
import 'package:dhikr_counter/domain/models/dhikr_session.dart';
import 'package:dhikr_counter/features/history/history_screen.dart';

void main() {
  testWidgets('HistoryScreen renders long Arabic and English phrases without any overflow', (tester) async {
    // Set a narrow viewport simulating a compact mobile device
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionRepo = LocalSessionRepository();
    // Add sessions with long phrases that previously caused RenderFlex overflow
    await sessionRepo.saveSession(
      DhikrSession(
        id: 'session_long_1',
        dhikrId: 'subhanallahi_wa_bihamdihi_adheem',
        count: 100,
        target: 100,
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        duration: const Duration(minutes: 15),
      ),
    );
    await sessionRepo.saveSession(
      DhikrSession(
        id: 'session_long_2',
        dhikrId: 'la_ilaha_illallah_wahdahu',
        count: 33,
        target: 33,
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 5),
      ),
    );

    final deps = AppDependencies.forTesting(
      dhikrRepo: LocalDhikrRepository(),
      sessionRepo: sessionRepo,
    );

    await tester.pumpWidget(
      AppScope(
        dependencies: deps,
        child: const MaterialApp(
          home: HistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify screen title and banner stats render
    expect(find.text('Recitation History'), findsOneWidget);
    expect(find.text('133'), findsOneWidget); // 100 + 33 total
    expect(find.text('2'), findsOneWidget);   // 2 completed sessions

    // Verify both long dhikr cards rendered without throwing any layout overflow
    expect(find.byType(Card), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
