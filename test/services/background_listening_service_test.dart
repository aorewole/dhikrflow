import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/services/background_listening_service.dart';

void main() {
  group('DefaultBackgroundListeningService Tests (Phase 10)', () {
    late DefaultBackgroundListeningService service;

    const testDhikr = DhikrDefinition(
      id: 'astaghfirullah',
      arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
      transliteration: 'Astaghfirullah',
      translation: 'I seek forgiveness from Allah',
      category: 'Forgiveness',
      defaultTarget: 100,
      normalizedArabic: 'استغفر الله',
    );

    setUp(() {
      service = DefaultBackgroundListeningService(initialOptIn: false);
    });

    tearDown(() {
      service.dispose();
    });

    test('is disabled by default for privacy and battery preservation', () {
      expect(service.isOptedIn, isFalse);
      expect(service.isActive, isFalse);
    });

    test('does not activate on session start when not opted in', () async {
      await service.onSessionStarted(testDhikr);
      expect(service.isActive, isFalse);
    });

    test('activates on session start when user explicitly opts in', () async {
      await service.setOptedIn(true);
      expect(service.isOptedIn, isTrue);

      if (service.isSupported) {
        await service.onSessionStarted(testDhikr);
        expect(service.isActive, isTrue);

        await service.onSessionStopped();
        expect(service.isActive, isFalse);
      }
    });

    test('immediately stops active background service if user revokes opt-in', () async {
      await service.setOptedIn(true);
      if (service.isSupported) {
        await service.onSessionStarted(testDhikr);
        expect(service.isActive, isTrue);

        await service.setOptedIn(false);
        expect(service.isActive, isFalse);
      }
    });
  });
}
