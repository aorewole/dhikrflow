import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/data/repositories/dhikr_repository.dart';
import 'package:dhikr_counter/domain/models/dhikr_session.dart';

void main() {
  group('Dhikr Models & Repository Tests', () {
    test('DhikrSession progress and target calculations', () {
      final sessionWithTarget = DhikrSession(
        id: 'test-1',
        dhikrId: 'astaghfirullah',
        startedAt: DateTime.now(),
        count: 10,
        target: 33,
      );

      expect(sessionWithTarget.isTargetReached, isFalse);
      expect(sessionWithTarget.progress, closeTo(10 / 33, 0.001));
      expect(sessionWithTarget.remaining, equals(23));

      final sessionReached = sessionWithTarget.copyWith(count: 33);
      expect(sessionReached.isTargetReached, isTrue);
      expect(sessionReached.progress, equals(1.0));
      expect(sessionReached.remaining, equals(0));

      final sessionExceeded = sessionWithTarget.copyWith(count: 50);
      expect(sessionExceeded.isTargetReached, isTrue);
      expect(sessionExceeded.progress, equals(1.0));
      expect(sessionExceeded.remaining, equals(0));

      final sessionNoTarget = sessionWithTarget.copyWith(clearTarget: true);
      expect(sessionNoTarget.isTargetReached, isFalse);
      expect(sessionNoTarget.progress, isNull);
      expect(sessionNoTarget.remaining, isNull);
    });

    test('InMemoryDhikrRepository provides validated canonical adhkar', () {
      final repo = InMemoryDhikrRepository();
      final all = repo.getAll();

      expect(all.isNotEmpty, isTrue);
      expect(all.length, greaterThanOrEqualTo(5));

      // Verify primary test dhikr: Astaghfirullah
      final astaghfirullah = repo.getById('astaghfirullah');
      expect(astaghfirullah, isNotNull);
      expect(astaghfirullah?.transliteration, equals('Astaghfirullah'));
      expect(astaghfirullah?.arabic, contains('أَسْتَغْفِرُ'));
      expect(astaghfirullah?.normalizedArabic, equals('استغفر الله'));

      // Test category filtering
      final forgivenessItems = repo.getByCategory('Forgiveness');
      expect(forgivenessItems.any((d) => d.id == 'astaghfirullah'), isTrue);

      // Test favorite toggling
      final initialFav = astaghfirullah!.isFavorite;
      repo.toggleFavorite('astaghfirullah');
      expect(repo.getById('astaghfirullah')?.isFavorite, equals(!initialFav));
    });
  });
}
