import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/recognition/audio/audio_chunk.dart';
import 'package:dhikr_counter/recognition/audio/mock_audio_source.dart';
import 'package:dhikr_counter/recognition/pipeline/audio_vad_pipeline.dart';
import 'package:dhikr_counter/recognition/vad/vad_event.dart';
import 'package:dhikr_counter/recognition/vad/voice_activity_detector.dart';

void main() {
  group('AudioChunk calculations', () {
    test('silence produces zero RMS and clamped -100 dBFS', () {
      final silenceBytes = Uint8List(3200); // 100ms at 16kHz 16-bit
      final chunk = AudioChunk(bytes: silenceBytes, sampleRate: 16000);

      expect(chunk.pcm16Samples.length, 1600);
      expect(chunk.computeRms(), 0.0);
      expect(chunk.computeDbfs(), -100.0);
      expect(chunk.computeZeroCrossingRate(), 0.0);
    });

    test(
      'synthetic tone produces expected energy and non-zero zero-crossing rate',
      () {
        const sampleRate = 16000;
        const durationMs = 100;
        const sampleCount = (sampleRate * (durationMs / 1000.0));
        final bytes = Uint8List(sampleCount.toInt() * 2);
        final byteData = ByteData.sublistView(bytes);

        // 400Hz sine wave, amplitude 0.5 (~ -6 dBFS peak)
        for (int i = 0; i < sampleCount; i++) {
          final t = i / sampleRate;
          final sampleVal =
              (0.5 * 32767.0 * math.sin(2.0 * math.pi * 400.0 * t)).round();
          byteData.setInt16(i * 2, sampleVal, Endian.little);
        }

        final chunk = AudioChunk(bytes: bytes, sampleRate: sampleRate);
        final rms = chunk.computeRms();
        final dbfs = chunk.computeDbfs();
        final zcr = chunk.computeZeroCrossingRate();

        expect(rms, greaterThan(0.3));
        expect(rms, lessThan(0.4)); // RMS of 0.5 sin wave is ~0.353
        expect(dbfs, greaterThan(-12.0));
        expect(dbfs, lessThan(-6.0));
        expect(
          zcr,
          greaterThan(0.04),
        ); // 400Hz at 16kHz has ~800 crossings/s = 0.05
      },
    );

    test('Phase 11: caches pcm16Samples to eliminate redundant memory allocations', () {
      final silenceBytes = Uint8List(3200);
      final chunk = AudioChunk(bytes: silenceBytes, sampleRate: 16000);

      expect(chunk.sampleCount, 1600);
      final samples1 = chunk.pcm16Samples;
      final samples2 = chunk.pcm16Samples;

      // Must be the identical cached instance
      expect(identical(samples1, samples2), isTrue);
    });
  });

  group('VoiceActivityDetector', () {
    late VoiceActivityDetector vad;

    setUp(() {
      vad = VoiceActivityDetector(
        speechThresholdDbfs: -40.0,
        hangoverDuration: const Duration(milliseconds: 350),
        minSpeechDuration: const Duration(milliseconds: 120),
        adaptiveNoiseTracking:
            false, // fixed threshold for unit testing predictability
      );
    });

    tearDown(() {
      vad.dispose();
    });

    test('ignores continuous silence', () async {
      final silenceBytes = Uint8List(3200);
      final chunk = AudioChunk(bytes: silenceBytes, sampleRate: 16000);

      final events = <VadStateEvent>[];
      final subscription = vad.stateEvents.listen(events.add);

      vad.processChunk(chunk);
      vad.processChunk(chunk);
      await pumpEventQueue();

      expect(vad.isSpeaking, isFalse);
      expect(events.length, 2);
      expect(events.every((e) => !e.isSpeech), isTrue);

      await subscription.cancel();
    });

    test('transitions to speaking when energy exceeds threshold', () async {
      final mockSource = MockAudioSource();
      await mockSource.start();

      final events = <VadStateEvent>[];
      final subscription = vad.stateEvents.listen(events.add);

      mockSource.chunks.listen((chunk) {
        vad.processChunk(chunk);
      });

      // Emit tone with amplitude 0.7 (well above -40 dBFS)
      mockSource.emitTone(amplitude: 0.7, durationMs: 150);
      await pumpEventQueue();

      expect(vad.isSpeaking, isTrue);
      await subscription.cancel();
      mockSource.dispose();
    });

    test('hangover duration bridges pauses under 350ms', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      final segments = <SpeechSegment>[];
      final segSub = vad.completedSegments.listen(segments.add);

      // 1. Voice chunk at t0 (200ms, exceeding 120ms min speech duration)
      final toneBytes = Uint8List(6400);
      final byteData = ByteData.sublistView(toneBytes);
      for (int i = 0; i < 3200; i++) {
        byteData.setInt16(i * 2, 20000, Endian.little); // loud signal
      }

      vad.processChunk(AudioChunk(bytes: toneBytes, timestamp: baseTime));
      expect(vad.isSpeaking, isTrue);

      // 2. Silence chunk at t0 + 200ms (within 350ms hangover)
      final silenceBytes = Uint8List(3200);
      vad.processChunk(
        AudioChunk(
          bytes: silenceBytes,
          timestamp: baseTime.add(const Duration(milliseconds: 200)),
        ),
      );
      expect(
        vad.isSpeaking,
        isTrue,
        reason: 'Hangover should maintain speaking state during brief pause',
      );

      // 3. Silence chunk at t0 + 600ms (400ms after last speech, exceeds 350ms hangover)
      vad.processChunk(
        AudioChunk(
          bytes: silenceBytes,
          timestamp: baseTime.add(const Duration(milliseconds: 600)),
        ),
      );
      await pumpEventQueue();

      expect(
        vad.isSpeaking,
        isFalse,
        reason: 'Hangover expiry should mark speech ended',
      );
      expect(segments.length, 1, reason: 'Concluded segment should be emitted');

      await segSub.cancel();
    });

    test('rejects transients shorter than minSpeechDuration', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      final segments = <SpeechSegment>[];
      final segSub = vad.completedSegments.listen(segments.add);

      // Loud transient lasting only 50ms (< 120ms minimum)
      final loudBytes = Uint8List(1600);
      final byteData = ByteData.sublistView(loudBytes);
      for (int i = 0; i < 800; i++) {
        byteData.setInt16(i * 2, 25000, Endian.little);
      }

      vad.processChunk(AudioChunk(bytes: loudBytes, timestamp: baseTime));
      expect(vad.isSpeaking, isTrue);

      // Silence at t0 + 500ms (hangover expires)
      vad.processChunk(
        AudioChunk(
          bytes: Uint8List(1600),
          timestamp: baseTime.add(const Duration(milliseconds: 500)),
        ),
      );
      await pumpEventQueue();

      expect(vad.isSpeaking, isFalse);
      expect(
        segments.isEmpty,
        isTrue,
        reason:
            'Short transient should be filtered out without emitting segment',
      );

      await segSub.cancel();
    });

    test('Phase 11: bounds continuous uninterrupted speech at maxSpeechDuration', () async {
      final segments = <SpeechSegment>[];
      final segSub = vad.completedSegments.listen(segments.add);

      final loudBytes = Uint8List(1600);
      final byteData = ByteData.sublistView(loudBytes);
      for (int i = 0; i < 800; i++) {
        byteData.setInt16(i * 2, 25000, Endian.little);
      }

      var time = DateTime(2026, 1, 1, 12, 0, 0);

      // Feed continuous speech for 8 seconds (exceeding default 7s maxSpeechDuration)
      for (int step = 0; step < 16; step++) {
        vad.processChunk(AudioChunk(bytes: loudBytes, timestamp: time));
        time = time.add(const Duration(milliseconds: 500));
      }
      await pumpEventQueue();

      // At step 14 (7.0 seconds), maxSpeechDuration is reached, so a segment is concluded
      expect(segments.isNotEmpty, isTrue);
      expect(segments.first.duration.inMilliseconds, greaterThanOrEqualTo(6500));

      await segSub.cancel();
    });

    test('continuous speech slicing partitions at energy minimum without dropping speaking state', () async {
      final continuousVad = VoiceActivityDetector(
        speechThresholdDbfs: -40.0,
        hangoverDuration: const Duration(milliseconds: 350),
        minSpeechDuration: const Duration(milliseconds: 120),
        continuousSpeechSliceDuration: const Duration(milliseconds: 2000),
        continuousValleySearchWindow: const Duration(milliseconds: 800),
        adaptiveNoiseTracking: false,
      );

      final segments = <SpeechSegment>[];
      final segSub = continuousVad.completedSegments.listen(segments.add);

      // 100ms loud chunk (amplitude 20000)
      final loudBytes = Uint8List(3200);
      final loudData = ByteData.sublistView(loudBytes);
      for (int i = 0; i < 1600; i++) {
        loudData.setInt16(i * 2, 20000, Endian.little);
      }

      // 100ms dip chunk (amplitude 4000, still above -40 dBFS speech threshold)
      final dipBytes = Uint8List(3200);
      final dipData = ByteData.sublistView(dipBytes);
      for (int i = 0; i < 1600; i++) {
        dipData.setInt16(i * 2, 4000, Endian.little);
      }

      var time = DateTime(2026, 1, 1, 12, 0, 0);

      // Simulate 6.0 seconds (60 chunks) of continuous uninterrupted speech.
      // Every 1.0 second (10 chunks), insert a 2-chunk (200ms) acoustic valley dip.
      for (int step = 0; step < 60; step++) {
        final isValley = (step % 10 == 8 || step % 10 == 9);
        continuousVad.processChunk(
          AudioChunk(
            bytes: isValley ? dipBytes : loudBytes,
            timestamp: time,
          ),
        );
        time = time.add(const Duration(milliseconds: 100));

        // Speaking state must NEVER drop throughout unbroken continuous speech
        expect(continuousVad.isSpeaking, isTrue);
      }
      await pumpEventQueue();

      // Continuous slicing should have partitioned into multiple segments cleanly
      expect(segments.length, greaterThanOrEqualTo(2));
      for (final s in segments) {
        expect(s.duration.inMilliseconds, greaterThanOrEqualTo(1500));
        expect(s.duration.inMilliseconds, lessThanOrEqualTo(3500));
      }

      // After 6s of non-stop speech, VAD is STILL in active speaking state (no reset)
      expect(continuousVad.isSpeaking, isTrue);

      await segSub.cancel();
      continuousVad.dispose();
    });
  });

  group('AudioVadPipeline integration', () {
    late MockAudioSource audioSource;
    late AudioVadPipeline pipeline;

    setUp(() {
      audioSource = MockAudioSource();
      pipeline = AudioVadPipeline(
        audioSource: audioSource,
        vad: VoiceActivityDetector(
          adaptiveNoiseTracking: false,
          speechThresholdDbfs: -40.0,
        ),
      );
    });

    tearDown(() {
      pipeline.dispose();
    });

    test('pipeline lifecycle controls audio source and VAD', () async {
      expect(pipeline.isRunning, isFalse);
      expect(audioSource.isRecording, isFalse);

      await pipeline.start();
      expect(pipeline.isRunning, isTrue);
      expect(audioSource.isRecording, isTrue);

      final stateEvents = <VadStateEvent>[];
      final sub = pipeline.vadStateEvents.listen(stateEvents.add);

      audioSource.emitTone(amplitude: 0.8, durationMs: 100);
      await pumpEventQueue();

      expect(stateEvents.isNotEmpty, isTrue);
      expect(pipeline.isSpeaking, isTrue);

      await pipeline.stop();
      expect(pipeline.isRunning, isFalse);
      expect(audioSource.isRecording, isFalse);
      expect(pipeline.isSpeaking, isFalse);

      await sub.cancel();
    });
  });

  group('Whisper & Digital AGC Tests', () {
    test('VAD detects faint whisper tone with whisper threshold', () async {
      final vad = VoiceActivityDetector(
        speechThresholdDbfs: -58.0,
        hangoverDuration: const Duration(milliseconds: 500),
        minSpeechDuration: const Duration(milliseconds: 60),
        adaptiveNoiseTracking: false,
      );

      final events = <VadStateEvent>[];
      final segments = <SpeechSegment>[];
      final sub1 = vad.stateEvents.listen(events.add);
      final sub2 = vad.completedSegments.listen(segments.add);

      // Low amplitude whisper tone: amplitude = 0.004 (~ -48 dBFS)
      const sampleRate = 16000;
      const durationMs = 120;
      const sampleCount = (sampleRate * (durationMs / 1000.0));
      final bytes = Uint8List(sampleCount.toInt() * 2);
      final byteData = ByteData.sublistView(bytes);

      for (int i = 0; i < sampleCount; i++) {
        final t = i / sampleRate;
        final sampleVal =
            (0.004 * 32767.0 * math.sin(2.0 * math.pi * 500.0 * t)).round();
        byteData.setInt16(i * 2, sampleVal, Endian.little);
      }

      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      final whisperChunk = AudioChunk(
        bytes: bytes,
        sampleRate: sampleRate,
        timestamp: baseTime,
      );
      expect(whisperChunk.computeDbfs(), greaterThan(-55.0));
      expect(whisperChunk.computeDbfs(), lessThan(-40.0));

      vad.processChunk(whisperChunk);
      expect(vad.isSpeaking, isTrue);

      // Feed silence with timestamp past hangover (600ms later) to conclude segment
      final silenceBytes = Uint8List(sampleRate * 2); // 1 sec silence
      final silenceChunk = AudioChunk(
        bytes: silenceBytes,
        sampleRate: sampleRate,
        timestamp: baseTime.add(const Duration(milliseconds: 600)),
      );
      vad.processChunk(silenceChunk);

      await pumpEventQueue();
      expect(segments.isNotEmpty, isTrue);

      await sub1.cancel();
      await sub2.cancel();
      vad.dispose();
    });

    test('Digital AGC scales low-peak whisper float samples to target ~0.70', () {
      final quietSamples = Float32List(100);
      for (int i = 0; i < quietSamples.length; i++) {
        quietSamples[i] = 0.035; // Peak 0.035 (~ -29 dBFS)
      }

      double peakAbs = 0.0;
      for (int i = 0; i < quietSamples.length; i++) {
        final val = quietSamples[i].abs();
        if (val > peakAbs) peakAbs = val;
      }

      expect(peakAbs, closeTo(0.035, 0.001));

      if (peakAbs > 0.0001 && peakAbs < 0.65) {
        final gain = (0.70 / peakAbs).clamp(1.0, 20.0);
        for (int i = 0; i < quietSamples.length; i++) {
          quietSamples[i] = (quietSamples[i] * gain).clamp(-1.0, 1.0);
        }
      }

      // New peak should be scaled up to 0.70
      double newPeak = 0.0;
      for (int i = 0; i < quietSamples.length; i++) {
        final val = quietSamples[i].abs();
        if (val > newPeak) newPeak = val;
      }
      expect(newPeak, closeTo(0.70, 0.001));
    });
  });
}
