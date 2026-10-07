import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhikr_counter/recognition/audio/audio_chunk.dart';
import 'package:dhikr_counter/recognition/audio/speech_envelope_analyzer.dart';
import 'package:dhikr_counter/recognition/vad/vad_event.dart';

// ── Synthetic waveform helpers ─────────────────────────────────────────────

/// Generates a synthetic sinusoidal "speech burst" of [durationMs] at [sampleRate].
/// The burst has a Hann-windowed envelope so the amplitude rises and falls
/// smoothly (mimicking a real Arabic word).
Uint8List _speechBurst({
  required int durationMs,
  required int sampleRate,
  double amplitude = 0.4,
  double freqHz = 220.0, // typical voiced speech fundamental
}) {
  final sampleCount = (sampleRate * durationMs / 1000).round();
  final bytes = ByteData(sampleCount * 2);
  for (int i = 0; i < sampleCount; i++) {
    // Hann window envelope
    final t = i / sampleCount;
    final envelope = 0.5 * (1 - math.cos(2 * math.pi * t));
    final sample = amplitude * envelope * math.sin(2 * math.pi * freqHz * i / sampleRate);
    final pcm16 = (sample * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(i * 2, pcm16, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Generates silence of [durationMs].
Uint8List _silence({required int durationMs, required int sampleRate}) {
  final sampleCount = (sampleRate * durationMs / 1000).round();
  return Uint8List(sampleCount * 2);
}

/// Generates a clap transient: very short burst with high-frequency content
/// and no sustained energy.
Uint8List _clapBurst({int sampleRate = 16000}) {
  const durationMs = 80;
  final sampleCount = (sampleRate * durationMs / 1000).round();
  final bytes = ByteData(sampleCount * 2);
  final rng = math.Random(42);
  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleCount;
    // Short attack, immediate exponential decay — pure noise character
    final envelope = math.exp(-t * 30);
    final noise = (rng.nextDouble() * 2 - 1) * envelope * 0.7;
    final pcm16 = (noise * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(i * 2, pcm16, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Builds a SpeechSegment by concatenating a list of PCM byte arrays
/// into separate AudioChunks with correct timestamps.
SpeechSegment _makeSegment(
  List<Uint8List> parts, {
  int sampleRate = 16000,
}) {
  final baseTime = DateTime(2024, 1, 1, 12, 0, 0);
  final chunks = <AudioChunk>[];
  var offset = Duration.zero;
  for (final part in parts) {
    chunks.add(AudioChunk(bytes: part, sampleRate: sampleRate, timestamp: baseTime.add(offset)));
    final samples = part.lengthInBytes ~/ 2;
    final ms = (samples * 1000) ~/ sampleRate;
    offset += Duration(milliseconds: ms);
  }
  return SpeechSegment(
    chunks: chunks,
    startTime: baseTime,
    endTime: baseTime.add(offset),
  );
}

void main() {
  const sampleRate = 16000;
  // Duration range for a 2-token dhikr like Astaghfirullah (min 450ms, max 1400ms)
  const minRep = 450;
  const maxRep = 1400;

  group('SpeechEnvelopeAnalyzer', () {
    group('expectedDurationRange', () {
      test('1-token dhikr returns narrow short range', () {
        final r = SpeechEnvelopeAnalyzer.expectedDurationRange(1);
        expect(r.min, lessThan(r.max));
        expect(r.min, lessThan(500));
      });

      test('2-token dhikr returns 650-1500ms', () {
        final r = SpeechEnvelopeAnalyzer.expectedDurationRange(2);
        expect(r.min, equals(650));
        expect(r.max, equals(1500));
      });

      test('6-token dhikr returns wider range', () {
        final r = SpeechEnvelopeAnalyzer.expectedDurationRange(6);
        expect(r.min, greaterThan(800));
        expect(r.max, greaterThan(2000));
      });
    });

    group('single repetition', () {
      test('single 900ms speech burst returns count=1 with moderate confidence', () {
        final segment = _makeSegment([
          _speechBurst(durationMs: 900, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(1));
        expect(result.confidence, greaterThan(0.3));
      });

      test('very short 80ms burst returns empty (too short for a dhikr)', () {
        final segment = _makeSegment([
          _speechBurst(durationMs: 80, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        // Either 0 or 1 but confidence must be low
        if (result.estimatedCount > 0) {
          expect(result.confidence, lessThan(0.6));
        }
      });
    });

    group('multiple repetitions', () {
      test('2 bursts separated by 80ms silence → count=2', () {
        final segment = _makeSegment([
          _speechBurst(durationMs: 850, sampleRate: sampleRate),
          _silence(durationMs: 80, sampleRate: sampleRate),
          _speechBurst(durationMs: 850, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(2));
        expect(result.confidence, greaterThan(0.55));
        expect(result.acceptedValleyCount, greaterThanOrEqualTo(1));
      });

      test('3 bursts with 70ms gaps → count=3', () {
        final segment = _makeSegment([
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 70, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 70, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(3));
        expect(result.confidence, greaterThan(0.60));
      });

      test('4 bursts with consistent 80ms gaps → count=4 with high confidence', () {
        final segment = _makeSegment([
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 80, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 80, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 80, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(4));
        expect(result.confidence, greaterThan(0.65));
        expect(result.isRhythmicVoicedSpeech, isTrue);
        expect(result.isActionable, isTrue);
      });

      test('5 rapid bursts → count=5', () {
        final parts = <Uint8List>[];
        for (int i = 0; i < 5; i++) {
          parts.add(_speechBurst(durationMs: 750, sampleRate: sampleRate));
          if (i < 4) parts.add(_silence(durationMs: 60, sampleRate: sampleRate));
        }
        final segment = _makeSegment(parts);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(5));
        expect(result.isActionable, isTrue);
      });
    });

    group('noise immunity', () {
      test('clap transient does not produce a rhythmic voiced speech result', () {
        final segment = _makeSegment([_clapBurst(sampleRate: sampleRate)]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.isActionable, isFalse);
      });

      test('3 claps do not produce an actionable result', () {
        final segment = _makeSegment([
          _clapBurst(sampleRate: sampleRate),
          _silence(durationMs: 300, sampleRate: sampleRate),
          _clapBurst(sampleRate: sampleRate),
          _silence(durationMs: 300, sampleRate: sampleRate),
          _clapBurst(sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        // Claps are each 80ms — even with gaps the inter-onset is ~380ms,
        // below minRepDurationMs (450ms). Should not be actionable.
        expect(result.isActionable, isFalse);
      });

      test('empty segment returns empty result', () {
        final segment = SpeechSegment(
          chunks: [],
          startTime: DateTime.now(),
          endTime: DateTime.now(),
        );
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result, equals(EnvelopeAnalysisResult.empty));
      });

      test('silence-only segment returns empty result', () {
        final segment = _makeSegment([
          _silence(durationMs: 2000, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(0));
        expect(result.isActionable, isFalse);
      });
    });

    group('rhythm consistency', () {
      test('highly irregular gaps produce non-actionable or non-rhythmic result', () {
        // Wildly different gap sizes simulate irregular conversation.
        // The 800ms gap vs 50ms gap creates a highly inconsistent IOI.
        final segment = _makeSegment([
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 50, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 800, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        // Either: valleys are filtered (count < 3) OR the result is not actionable
        // due to high IOI variance → isRhythmicVoicedSpeech=false.
        // Both outcomes are acceptable — the key is it must not be fully actionable.
        final isFullyAccurate = result.estimatedCount == 3 && result.isActionable;
        expect(isFullyAccurate, isFalse,
            reason: 'Highly irregular rhythm should not produce an actionable 3-count result');
      });

      test('consistent gaps produce isRhythmicVoicedSpeech=true', () {
        final segment = _makeSegment([
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 75, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
          _silence(durationMs: 80, sampleRate: sampleRate),
          _speechBurst(durationMs: 800, sampleRate: sampleRate),
        ]);
        final result = SpeechEnvelopeAnalyzer.analyze(
          segment,
          minRepDurationMs: minRep,
          maxRepDurationMs: maxRep,
        );
        expect(result.estimatedCount, equals(3));
        expect(result.isRhythmicVoicedSpeech, isTrue);
      });
    });

    group('EnvelopeAnalysisResult.isActionable', () {
      test('empty result is not actionable', () {
        expect(EnvelopeAnalysisResult.empty.isActionable, isFalse);
      });

      test('high confidence rhythmic result is actionable', () {
        const r = EnvelopeAnalysisResult(
          estimatedCount: 3,
          confidence: 0.80,
          isRhythmicVoicedSpeech: true,
          meanRepetitionDurationMs: 850,
          rawValleyCount: 2,
          acceptedValleyCount: 2,
        );
        expect(r.isActionable, isTrue);
      });

      test('low confidence result is not actionable even if rhythmic', () {
        const r = EnvelopeAnalysisResult(
          estimatedCount: 2,
          confidence: 0.50,
          isRhythmicVoicedSpeech: true,
          meanRepetitionDurationMs: 850,
          rawValleyCount: 1,
          acceptedValleyCount: 1,
        );
        expect(r.isActionable, isFalse);
      });

      test('high confidence non-rhythmic result is not actionable', () {
        const r = EnvelopeAnalysisResult(
          estimatedCount: 2,
          confidence: 0.80,
          isRhythmicVoicedSpeech: false,
          meanRepetitionDurationMs: 850,
          rawValleyCount: 1,
          acceptedValleyCount: 1,
        );
        expect(r.isActionable, isFalse);
      });
    });
  });
}
