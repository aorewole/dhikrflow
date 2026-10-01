import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/domain/events/count_events.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/domain/recognition/recognition_engine.dart';
import 'package:dhikr_counter/recognition/asr/mock_asr_engine.dart';
import 'package:dhikr_counter/recognition/audio/mock_audio_source.dart';
import 'package:dhikr_counter/recognition/local_recognition_engine.dart';
import 'package:dhikr_counter/recognition/pipeline/audio_vad_pipeline.dart';
import 'package:dhikr_counter/recognition/vad/voice_activity_detector.dart';

void main() {
  group('LocalRecognitionEngine Tests', () {
    late MockAudioSource audioSource;
    late VoiceActivityDetector vad;
    late AudioVadPipeline pipeline;
    late MockAsrEngine asrEngine;
    late LocalRecognitionEngine engine;

    final targetDhikr = DhikrDefinition(
      id: 'astaghfirullah',
      arabic: 'أَسْتَغْفِرُ اللَّهَ',
      normalizedArabic: 'استغفر الله',
      transliteration: 'Astaghfirullah',
      translation: 'I seek forgiveness from Allah',
      category: 'Istighfar',
      defaultTarget: 33,
    );

    setUp(() {
      audioSource = MockAudioSource();
      vad = VoiceActivityDetector(
        speechThresholdDbfs: -40.0,
        hangoverDuration: const Duration(milliseconds: 350),
        minSpeechDuration: const Duration(milliseconds: 120),
        adaptiveNoiseTracking: false,
      );
      pipeline = AudioVadPipeline(audioSource: audioSource, vad: vad);
      asrEngine = MockAsrEngine(defaultTranscript: 'أستغفر الله');
      engine = LocalRecognitionEngine(pipeline: pipeline, asrEngine: asrEngine);
    });

    tearDown(() {
      engine.dispose();
    });

    test('starts in idle state and transitions to listening', () async {
      expect(engine.currentState, RecognitionState.idle);
      expect(engine.currentTarget, isNull);

      await engine.start(targetDhikr);

      expect(engine.currentState, RecognitionState.listening);
      expect(engine.currentTarget, targetDhikr);
      expect(pipeline.isRunning, isTrue);
      expect(asrEngine.isInitialized, isTrue);
    });

    test(
      'speech segment decoded into Astaghfirullah emits +1 DhikrCountEvent',
      () async {
        await engine.start(targetDhikr);

        final countEvents = <DhikrCountEvent>[];
        final sub = engine.countEvents.listen(countEvents.add);

        final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

        // 1. Emit 200ms tone (above -40 dBFS threshold)
        audioSource.emitTone(
          amplitude: 0.8,
          durationMs: 200,
          timestamp: baseTime,
        );
        await pumpEventQueue();

        // 2. Emit silence exceeding 350ms hangover duration to conclude segment
        audioSource.emitSilence(
          durationMs: 400,
          timestamp: baseTime.add(const Duration(milliseconds: 500)),
        );
        await pumpEventQueue();

        expect(asrEngine.transcribedSegments.length, 1);
        expect(countEvents.length, 1);
        expect(countEvents.first.phraseId, targetDhikr.id);
        expect(countEvents.first.increment, 1);
        expect(countEvents.first.source, CountSource.voice);

        await sub.cancel();
      },
    );

    test('speech segment with 2 repetitions emits +2 count events', () async {
      asrEngine.queuedTranscripts.add('أستغفر الله أستغفر الله');
      await engine.start(targetDhikr);

      final countEvents = <DhikrCountEvent>[];
      final sub = engine.countEvents.listen(countEvents.add);

      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

      audioSource.emitTone(
        amplitude: 0.8,
        durationMs: 300,
        timestamp: baseTime,
      );
      await pumpEventQueue();

      audioSource.emitSilence(
        durationMs: 400,
        timestamp: baseTime.add(const Duration(milliseconds: 600)),
      );
      await pumpEventQueue();

      expect(countEvents.length, 2);
      expect(countEvents[0].phraseId, targetDhikr.id);
      expect(countEvents[1].phraseId, targetDhikr.id);

      await sub.cancel();
    });

    test('unrelated transcript emits +0 count events', () async {
      asrEngine.queuedTranscripts.add('مرحبا كيف حالك اليوم');
      await engine.start(targetDhikr);

      final countEvents = <DhikrCountEvent>[];
      final sub = engine.countEvents.listen(countEvents.add);

      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

      audioSource.emitTone(
        amplitude: 0.8,
        durationMs: 200,
        timestamp: baseTime,
      );
      await pumpEventQueue();

      audioSource.emitSilence(
        durationMs: 400,
        timestamp: baseTime.add(const Duration(milliseconds: 500)),
      );
      await pumpEventQueue();

      expect(asrEngine.transcribedSegments.length, 1);
      expect(countEvents.isEmpty, isTrue);

      await sub.cancel();
    });

    test('pause and resume manages engine state correctly', () async {
      await engine.start(targetDhikr);
      expect(engine.currentState, RecognitionState.listening);
      expect(pipeline.isRunning, isTrue);

      await engine.pause();
      expect(engine.currentState, RecognitionState.paused);
      expect(pipeline.isRunning, isFalse);

      await engine.resume();
      expect(engine.currentState, RecognitionState.listening);
      expect(pipeline.isRunning, isTrue);
    });

    test('stop transitions to idle and clears target', () async {
      await engine.start(targetDhikr);
      await engine.stop();

      expect(engine.currentState, RecognitionState.idle);
      expect(engine.currentTarget, isNull);
      expect(pipeline.isRunning, isFalse);
    });

    test('Phase 11: two consecutive discrete speech segments emit +1 each', () async {
      await engine.start(targetDhikr);

      final countEvents = <DhikrCountEvent>[];
      final sub = engine.countEvents.listen(countEvents.add);

      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

      // --- Segment 1: Tone + Silence (>350ms hangover) ---
      audioSource.emitTone(
        amplitude: 0.8,
        durationMs: 250,
        timestamp: baseTime,
      );
      await pumpEventQueue();

      audioSource.emitSilence(
        durationMs: 400,
        timestamp: baseTime.add(const Duration(milliseconds: 500)),
      );
      await pumpEventQueue();

      expect(countEvents.length, 1);
      expect(countEvents[0].increment, 1);

      // --- Segment 2: Tone + Silence (second utterance) ---
      audioSource.emitTone(
        amplitude: 0.8,
        durationMs: 250,
        timestamp: baseTime.add(const Duration(milliseconds: 1000)),
      );
      await pumpEventQueue();

      audioSource.emitSilence(
        durationMs: 400,
        timestamp: baseTime.add(const Duration(milliseconds: 1500)),
      );
      await pumpEventQueue();

      expect(countEvents.length, 2);
      expect(countEvents[1].increment, 1);

      await sub.cancel();
    });
  });
}
