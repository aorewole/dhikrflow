import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/domain/events/count_events.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/domain/recognition/recognition_engine.dart';
import 'package:dhikr_counter/recognition/mock_recognition_engine.dart';

void main() {
  group('MockRecognitionEngine Tests', () {
    late MockRecognitionEngine engine;

    const testDhikr = DhikrDefinition(
      id: 'subhanallah',
      arabic: 'سُبْحَانَ ٱللَّٰهِ',
      transliteration: 'SubhanAllah',
      translation: 'Glory be to Allah',
      category: 'Tasbih',
      normalizedArabic: 'سبحان الله',
    );

    setUp(() {
      engine = MockRecognitionEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('initial state is idle with no target', () {
      expect(engine.currentState, equals(RecognitionState.idle));
      expect(engine.currentTarget, isNull);
    });

    test('start transitions to listening with target phrase', () async {
      await engine.start(testDhikr);
      expect(engine.currentState, equals(RecognitionState.listening));
      expect(engine.currentTarget?.id, equals('subhanallah'));
    });

    test('emits count events via simulateVoiceCount', () async {
      await engine.start(testDhikr);

      final receivedEvents = <DhikrCountEvent>[];
      final subscription = engine.countEvents.listen(receivedEvents.add);

      engine.simulateVoiceCount(confidence: 0.95, repetitions: 1);
      await Future<void>.delayed(Duration.zero);

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.phraseId, equals('subhanallah'));
      expect(receivedEvents.first.confidence, equals(0.95));
      expect(receivedEvents.first.source, equals(CountSource.voice));

      // Test multiple repetitions in single continuous segment
      engine.simulateVoiceCount(confidence: 0.9, repetitions: 4);
      await Future<void>.delayed(Duration.zero);

      expect(receivedEvents.length, equals(5));

      await subscription.cancel();
    });

    test('pause and resume manage engine state correctly', () async {
      await engine.start(testDhikr);
      expect(engine.currentState, equals(RecognitionState.listening));

      await engine.pause();
      expect(engine.currentState, equals(RecognitionState.paused));

      // When paused, simulated counts are suppressed
      final receivedEvents = <DhikrCountEvent>[];
      final subscription = engine.countEvents.listen(receivedEvents.add);

      engine.simulateVoiceCount();
      await Future<void>.delayed(Duration.zero);
      expect(receivedEvents, isEmpty);

      await engine.resume();
      expect(engine.currentState, equals(RecognitionState.listening));

      engine.simulateVoiceCount();
      await Future<void>.delayed(Duration.zero);
      expect(receivedEvents.length, equals(1));

      await subscription.cancel();
    });

    test('stop transitions to idle and clears target', () async {
      await engine.start(testDhikr);
      await engine.stop();

      expect(engine.currentState, equals(RecognitionState.idle));
      expect(engine.currentTarget, isNull);
    });
  });
}
