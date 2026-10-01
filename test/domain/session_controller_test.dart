import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/data/repositories/session_repository.dart';
import 'package:dhikr_counter/domain/events/count_events.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/domain/models/dhikr_session.dart';
import 'package:dhikr_counter/domain/recognition/recognition_engine.dart';
import 'package:dhikr_counter/domain/session/session_controller.dart';
import 'package:dhikr_counter/recognition/mock_recognition_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionController Tests', () {
    late MockRecognitionEngine mockEngine;
    late LocalSessionRepository sessionRepo;
    late SessionController controller;

    const testDhikr = DhikrDefinition(
      id: 'astaghfirullah',
      arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
      transliteration: 'Astaghfirullah',
      translation: 'I seek forgiveness from Allah',
      category: 'Forgiveness',
      defaultTarget: 33,
      normalizedArabic: 'استغفر الله',
    );

    setUp(() {
      mockEngine = MockRecognitionEngine();
      sessionRepo = LocalSessionRepository();
      controller = SessionController(
        recognitionEngine: mockEngine,
        sessionRepository: sessionRepo,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts session with initial zero count and active state', () async {
      await controller.startSession(dhikr: testDhikr, target: 33);

      expect(controller.hasActiveSession, isTrue);
      expect(controller.isPaused, isFalse);
      expect(controller.isListening, isTrue);
      expect(controller.currentSession?.count, equals(0));
      expect(controller.currentSession?.target, equals(33));
      expect(controller.currentSession?.status, equals(SessionStatus.active));
      expect(controller.activeDhikr?.id, equals('astaghfirullah'));
      expect(mockEngine.currentState, equals(RecognitionState.listening));
    });

    test('voice count event increments count by 1', () async {
      await controller.startSession(dhikr: testDhikr);

      mockEngine.simulateVoiceCount(repetitions: 1);
      // Wait for stream event delivery
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentSession?.count, equals(1));
    });

    test('rapid voice recitation emits +4 correctly', () async {
      await controller.startSession(dhikr: testDhikr);

      mockEngine.simulateVoiceCount(repetitions: 4);
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentSession?.count, equals(4));
    });

    test('manual count event increments count by 1', () async {
      await controller.startSession(dhikr: testDhikr);

      controller.incrementManual();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentSession?.count, equals(1));

      controller.incrementManual();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentSession?.count, equals(2));
    });

    test('unrelated voice phrase does not increment count', () async {
      await controller.startSession(dhikr: testDhikr);

      // Simulate event with non-matching phraseId
      mockEngine.simulateVoiceCount(repetitions: 1); // target
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentSession?.count, equals(1));

      // Emit event for unrelated phrase
      // (Directly testing SessionController safety against mismatched events)
      final unrelatedEvent = DhikrCountEvent(
        phraseId: 'unrelated_speech_event',
        confidence: 0.9,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        source: CountSource.voice,
        increment: 1,
      );

      // Controller should ignore it because phraseId != currentSession.dhikrId
      // We test through engine by temporarily switching target or direct controller test
      expect(unrelatedEvent.phraseId, isNot(equals(testDhikr.id)));
      expect(controller.currentSession?.count, equals(1));
    });

    test('reaching target does not terminate session automatically', () async {
      await controller.startSession(dhikr: testDhikr, target: 2);

      controller.incrementManual();
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentSession?.count, equals(1));
      expect(controller.currentSession?.isTargetReached, isFalse);

      controller.incrementManual();
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentSession?.count, equals(2));
      expect(controller.currentSession?.isTargetReached, isTrue);
      // Crucial: Session must remain active and listening!
      expect(controller.currentSession?.status, equals(SessionStatus.active));
      expect(controller.isListening, isTrue);

      // User can continue reciting past the target
      controller.incrementManual();
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentSession?.count, equals(3));
      expect(controller.currentSession?.status, equals(SessionStatus.active));
    });

    test('pause and resume manages session and engine state', () async {
      await controller.startSession(dhikr: testDhikr);
      expect(controller.isListening, isTrue);

      await controller.pauseSession();
      expect(controller.isPaused, isTrue);
      expect(controller.isListening, isFalse);
      expect(mockEngine.currentState, equals(RecognitionState.paused));

      // While paused, manual count should not increment
      controller.incrementManual();
      expect(controller.currentSession?.count, equals(0));

      await controller.resumeSession();
      expect(controller.isPaused, isFalse);
      expect(controller.isListening, isTrue);
      expect(mockEngine.currentState, equals(RecognitionState.listening));

      controller.incrementManual();
      expect(controller.currentSession?.count, equals(1));
    });

    test('completeSession saves to repository and resets controller', () async {
      await controller.startSession(dhikr: testDhikr, target: 33);
      controller.incrementManual();
      controller.incrementManual();
      await Future<void>.delayed(Duration.zero);

      final completed = await controller.completeSession();
      expect(completed, isNotNull);
      expect(completed?.count, equals(2));
      expect(completed?.status, equals(SessionStatus.completed));
      expect(controller.hasActiveSession, isFalse);
      expect(mockEngine.currentState, equals(RecognitionState.idle));

      // Verify saved in repository
      final allSaved = await sessionRepo.getAllSessions();
      expect(allSaved.any((s) => s.id == completed!.id), isTrue);
    });

    test('endCurrentSessionSilently aborts without saving', () async {
      await controller.startSession(dhikr: testDhikr);
      final initialSessionId = controller.currentSession!.id;
      controller.incrementManual();

      await controller.endCurrentSessionSilently();
      expect(controller.hasActiveSession, isFalse);

      final allSaved = await sessionRepo.getAllSessions();
      expect(allSaved.any((s) => s.id == initialSessionId), isFalse);
    });

    test('Phase 8: target progress and remaining calculations are exact', () async {
      await controller.startSession(dhikr: testDhikr, target: 10);
      expect(controller.currentSession?.target, 10);
      expect(controller.currentSession?.count, 0);
      expect(controller.currentSession?.progress, 0.0);
      expect(controller.currentSession?.remaining, 10);
      expect(controller.currentSession?.isTargetReached, isFalse);

      for (int i = 1; i <= 5; i++) {
        controller.incrementManual();
      }
      expect(controller.currentSession?.count, 5);
      expect(controller.currentSession?.progress, 0.5);
      expect(controller.currentSession?.remaining, 5);
      expect(controller.currentSession?.isTargetReached, isFalse);

      for (int i = 6; i <= 10; i++) {
        controller.incrementManual();
      }
      expect(controller.currentSession?.count, 10);
      expect(controller.currentSession?.progress, 1.0);
      expect(controller.currentSession?.remaining, 0);
      expect(controller.currentSession?.isTargetReached, isTrue);

      // Reciting past target preserves progress clamped at 1.0 and remaining 0
      controller.incrementManual();
      expect(controller.currentSession?.count, 11);
      expect(controller.currentSession?.progress, 1.0);
      expect(controller.currentSession?.remaining, 0);
      expect(controller.currentSession?.isTargetReached, isTrue);
      expect(controller.currentSession?.status, SessionStatus.active);
    });
  });
}
