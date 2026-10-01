import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr_counter/data/repositories/dhikr_repository.dart';
import 'package:dhikr_counter/data/repositories/session_repository.dart';
import 'package:dhikr_counter/data/repositories/settings_repository.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/domain/models/dhikr_session.dart';
import 'package:dhikr_counter/domain/session/session_controller.dart';
import 'package:dhikr_counter/recognition/mock_recognition_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Local Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'SharedPrefsSettingsRepository persists and restores preferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = SharedPrefsSettingsRepository(prefs);

        // Default values
        expect(await repo.getHapticsEnabled(), isTrue);
        expect(await repo.getThemeMode(), equals(ThemeMode.system));
        expect(await repo.getAutoSimulateVoice(), isFalse);

        // Mutate
        await repo.setHapticsEnabled(false);
        await repo.setThemeMode(ThemeMode.dark);
        await repo.setAutoSimulateVoice(true);

        // Verify on fresh repository instance reading the same prefs
        final freshRepo = SharedPrefsSettingsRepository(prefs);
        expect(await freshRepo.getHapticsEnabled(), isFalse);
        expect(await freshRepo.getThemeMode(), equals(ThemeMode.dark));
        expect(await freshRepo.getAutoSimulateVoice(), isTrue);
      },
    );

    test('LocalDhikrRepository persists favorites and custom adhkar', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalDhikrRepository(prefs);

      // Initial state
      final initialFavorites = repo.getFavorites();
      expect(initialFavorites.any((d) => d.id == 'astaghfirullah'), isTrue);

      // Toggle favorite on an un-favorited item
      expect(repo.getById('la_ilaha_illallah')?.isFavorite, isFalse);
      await repo.toggleFavorite('la_ilaha_illallah');
      expect(repo.getById('la_ilaha_illallah')?.isFavorite, isTrue);

      // Verify persistence across fresh repository instance
      final freshRepo = LocalDhikrRepository(prefs);
      expect(freshRepo.getById('la_ilaha_illallah')?.isFavorite, isTrue);

      // Add custom dhikr
      const customDhikr = DhikrDefinition(
        id: 'custom_salawat',
        arabic: 'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
        transliteration: 'Allahumma salli ala Muhammad',
        translation: 'O Allah, send blessings upon Muhammad',
        category: 'Salawat',
        defaultTarget: 100,
        normalizedArabic: 'اللهم صل على محمد',
      );

      await repo.addCustomDhikr(customDhikr);
      expect(repo.getById('custom_salawat'), isNotNull);

      // Verify custom dhikr persisted across fresh repository instance
      final freshRepo2 = LocalDhikrRepository(prefs);
      final loadedCustom = freshRepo2.getById('custom_salawat');
      expect(loadedCustom, isNotNull);
      expect(
        loadedCustom?.transliteration,
        equals('Allahumma salli ala Muhammad'),
      );
      expect(loadedCustom?.category, equals('Salawat'));

      // Remove custom dhikr
      await freshRepo2.removeCustomDhikr('custom_salawat');
      expect(freshRepo2.getById('custom_salawat'), isNull);

      final freshRepo3 = LocalDhikrRepository(prefs);
      expect(freshRepo3.getById('custom_salawat'), isNull);
    });

    test('LocalSessionRepository persists completed sessions', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalSessionRepository(prefs);

      final now = DateTime.now();
      final session1 = DhikrSession(
        id: 'session-persist-1',
        dhikrId: 'astaghfirullah',
        startedAt: now.subtract(const Duration(minutes: 10)),
        endedAt: now.subtract(const Duration(minutes: 5)),
        count: 100,
        target: 100,
        duration: const Duration(minutes: 5),
        status: SessionStatus.completed,
      );

      final session2 = DhikrSession(
        id: 'session-persist-2',
        dhikrId: 'subhanallah',
        startedAt: now.subtract(const Duration(minutes: 2)),
        endedAt: now,
        count: 33,
        target: 33,
        duration: const Duration(minutes: 2),
        status: SessionStatus.completed,
      );

      await repo.saveSession(session1);
      await repo.saveSession(session2);

      // Verify across fresh instance
      final freshRepo = LocalSessionRepository(prefs);
      final all = await freshRepo.getAllSessions();
      expect(all.length, equals(2));
      // Sorted newest first
      expect(all.first.id, equals('session-persist-2'));
      expect(all.last.id, equals('session-persist-1'));

      final total = await freshRepo.getTotalCount();
      expect(total, equals(133));

      // Test delete
      await freshRepo.deleteSession('session-persist-1');
      final afterDelete = await freshRepo.getAllSessions();
      expect(afterDelete.length, equals(1));
      expect(afterDelete.first.id, equals('session-persist-2'));
    });

    test('Session lifecycle interruption resilience: active draft save and restore', () async {
      final prefs = await SharedPreferences.getInstance();
      final sessionRepo = LocalSessionRepository(prefs);
      final mockEngine = MockRecognitionEngine();
      final controller = SessionController(
        recognitionEngine: mockEngine,
        sessionRepository: sessionRepo,
      );

      const testDhikr = DhikrDefinition(
        id: 'astaghfirullah',
        arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
        transliteration: 'Astaghfirullah',
        translation: 'I seek forgiveness from Allah',
        category: 'Forgiveness',
        defaultTarget: 100,
        normalizedArabic: 'استغفر الله',
      );

      // Start session and count 15
      await controller.startSession(dhikr: testDhikr, target: 100);
      for (int i = 0; i < 15; i++) {
        controller.incrementManual();
      }
      await Future<void>.delayed(Duration.zero);

      // Verify draft was saved
      final savedDraft = await sessionRepo.getActiveDraftSession();
      expect(savedDraft, isNotNull);
      expect(savedDraft?.dhikrId, equals('astaghfirullah'));
      expect(savedDraft?.count, equals(15));
      expect(savedDraft?.target, equals(100));

      // Simulate unexpected exit / app restart: create brand new controller and repository
      controller.dispose();

      final freshRepo = LocalSessionRepository(prefs);
      final recoveredDraft = await freshRepo.getActiveDraftSession();
      expect(recoveredDraft, isNotNull);
      expect(recoveredDraft?.count, equals(15));

      final freshEngine = MockRecognitionEngine();
      final freshController = SessionController(
        recognitionEngine: freshEngine,
        sessionRepository: freshRepo,
      );

      // Restore session from draft
      await freshController.restoreSessionFromDraft(
        draft: recoveredDraft!,
        dhikr: testDhikr,
      );

      expect(freshController.hasActiveSession, isTrue);
      expect(freshController.currentSession?.count, equals(15));

      // Continue counting
      freshController.incrementManual();
      await Future<void>.delayed(Duration.zero);
      expect(freshController.currentSession?.count, equals(16));

      // Complete session
      final completed = await freshController.completeSession();
      expect(completed?.count, equals(16));

      // Draft must now be cleared
      final draftAfterComplete = await freshRepo.getActiveDraftSession();
      expect(draftAfterComplete, isNull);

      freshController.dispose();
    });
  });
}
