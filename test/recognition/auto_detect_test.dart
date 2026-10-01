import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/data/repositories/dhikr_repository.dart';
import 'package:dhikr_counter/domain/events/count_events.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/recognition/auto_detect/auto_detect_engine.dart';

void main() {
  group('Phase 13 Auto-Detect Prototype Tests', () {
    late AutoDetectEngine engine;
    late List<DhikrDefinition> library;

    setUp(() {
      library = kCanonicalAdhkar;
      engine = AutoDetectEngine(
        supportedLibrary: library,
        lockConfidenceThreshold: 0.88,
      );
    });

    test('initial state has no locked target and zero count events', () {
      expect(engine.isTargetLocked, isFalse);
      expect(engine.lockedTarget, isNull);
    });

    test('unrelated speech does not lock target or emit count events', () {
      final events = engine.processTranscript('مرحبا كيف حالك اليوم');

      expect(events.isEmpty, isTrue);
      expect(engine.isTargetLocked, isFalse);
      expect(engine.lockedTarget, isNull);
    });

    test('reciting Astaghfirullah locks target and emits initial count event', () {
      final events = engine.processTranscript('أستغفر الله');

      expect(engine.isTargetLocked, isTrue);
      expect(engine.lockedTarget?.id, equals('astaghfirullah'));
      expect(events.length, 1);
      expect(events.first.phraseId, equals('astaghfirullah'));
      expect(events.first.increment, 1);
      expect(events.first.source, equals(CountSource.voice));
    });

    test('reciting SubhanAllah locks target to subhanallah', () {
      final events = engine.processTranscript('سبحان الله');

      expect(engine.isTargetLocked, isTrue);
      expect(engine.lockedTarget?.id, equals('subhanallah'));
      expect(events.length, 1);
      expect(events.first.phraseId, equals('subhanallah'));
    });

    test('subsequent repetitions increment the locked target', () {
      // Step 1: Lock to Alhamdulillah
      final ev1 = engine.processTranscript('الحمد لله');
      expect(engine.lockedTarget?.id, equals('alhamdulillah'));
      expect(ev1.length, 1);

      // Step 2: Recite additional repetitions
      final ev2 = engine.processTranscript('الحمد لله الحمد لله');
      expect(ev2.length, 1); // 1 new committed in this growing/evolving transcript
    });

    test('strictly prevents accidental silent target switching while reciting', () {
      // Step 1: User starts reciting Astaghfirullah -> locks to astaghfirullah
      engine.processTranscript('أستغفر الله');
      expect(engine.lockedTarget?.id, equals('astaghfirullah'));

      // Step 2: User accidentally recites a different phrase (e.g. SubhanAllah)
      // Engine MUST NOT silently switch targets!
      final events = engine.processTranscript('سبحان الله');

      // Locked target remains Astaghfirullah!
      expect(engine.lockedTarget?.id, equals('astaghfirullah'));
      // Does not count SubhanAllah for Astaghfirullah
      expect(events.isEmpty, isTrue);
    });

    test('resetting engine allows re-detecting and locking a different target', () {
      engine.processTranscript('أستغفر الله');
      expect(engine.lockedTarget?.id, equals('astaghfirullah'));

      // User pauses or explicitly resets auto-detect
      engine.reset();
      expect(engine.isTargetLocked, isFalse);
      expect(engine.lockedTarget, isNull);

      // Now reciting Allahu Akbar locks to allahu_akbar
      final events = engine.processTranscript('الله أكبر');
      expect(engine.isTargetLocked, isTrue);
      expect(engine.lockedTarget?.id, equals('allahu_akbar'));
      expect(events.length, 1);
    });
  });
}
