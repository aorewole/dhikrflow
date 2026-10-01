import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/domain/models/dhikr_definition.dart';
import 'package:dhikr_counter/domain/recognition/recognition_config.dart';
import 'package:dhikr_counter/domain/recognition/recognition_profile.dart';
import 'package:dhikr_counter/recognition/audio/audio_chunk.dart';
import 'package:dhikr_counter/recognition/calibration/personal_calibration_engine.dart';
import 'package:dhikr_counter/recognition/calibration/recognition_test_harness.dart';
import 'package:dhikr_counter/recognition/vad/vad_event.dart';

void main() {
  group('Phase 12 Personal Calibration Tests', () {
    late PersonalCalibrationEngine engine;

    const testDhikr = DhikrDefinition(
      id: 'astaghfirullah',
      arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
      transliteration: 'Astaghfirullah',
      translation: 'I seek forgiveness from Allah',
      category: 'Forgiveness',
      defaultTarget: 100,
      normalizedArabic: 'استغفر الله',
    );

    SpeechSegment createSyntheticExample({
      required double amplitude,
      required int durationMs,
      required DateTime timestamp,
    }) {
      const sampleRate = 16000;
      final sampleCount = (sampleRate * (durationMs / 1000.0)).round();
      final bytes = Uint8List(sampleCount * 2);
      final byteData = ByteData.sublistView(bytes);

      for (int i = 0; i < sampleCount; i++) {
        final t = i / sampleRate;
        final sampleVal = (amplitude * 32767.0 * math.sin(2.0 * math.pi * 350.0 * t)).round();
        byteData.setInt16(i * 2, sampleVal, Endian.little);
      }

      final chunk = AudioChunk(bytes: bytes, timestamp: timestamp);
      return SpeechSegment(
        chunks: [chunk],
        startTime: timestamp,
        endTime: timestamp.add(Duration(milliseconds: durationMs)),
      );
    }

    setUp(() {
      engine = const PersonalCalibrationEngine();
    });

    test('calibrates profile from multiple recitation examples', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final examples = [
        createSyntheticExample(amplitude: 0.5, durationMs: 1200, timestamp: t0),
        createSyntheticExample(amplitude: 0.6, durationMs: 1100, timestamp: t0.add(const Duration(seconds: 2))),
        createSyntheticExample(amplitude: 0.55, durationMs: 1150, timestamp: t0.add(const Duration(seconds: 4))),
      ];

      final profile = engine.calibrate(
        dhikr: testDhikr,
        examples: examples,
        recognizedTranscripts: [
          'استغفر الله',
          'استغفر الله',
          'استغفر الله',
        ],
      );

      expect(profile.dhikrId, equals(testDhikr.id));
      expect(profile.averageRepetitionDurationMs, inInclusiveRange(1100, 1200));
      expect(profile.calibratedAcceptThreshold, inInclusiveRange(0.80, 0.90));
      expect(profile.calibratedSpeechFloorDbfs, inInclusiveRange(-48.0, -32.0));

      // Converts to tailored RecognitionConfig
      final calibratedConfig = profile.toCalibratedConfig(baseConfig: RecognitionConfig.balanced);
      expect(calibratedConfig.acceptThreshold, equals(profile.calibratedAcceptThreshold));
      expect(calibratedConfig.speechThresholdDbfs, equals(profile.calibratedSpeechFloorDbfs));
    });

    test('serializes and deserializes profile correctly', () {
      final now = DateTime.now();
      final profile = RecognitionProfile(
        id: 'prof-test-1',
        dhikrId: 'astaghfirullah',
        averageSpeechDbfs: -22.5,
        averageRepetitionDurationMs: 1150,
        calibratedAcceptThreshold: 0.84,
        calibratedSpeechFloorDbfs: -36.5,
        createdAt: now,
      );

      final json = profile.toJson();
      final restored = RecognitionProfile.fromJson(json);

      expect(restored.id, equals('prof-test-1'));
      expect(restored.dhikrId, equals('astaghfirullah'));
      expect(restored.averageSpeechDbfs, equals(-22.5));
      expect(restored.averageRepetitionDurationMs, equals(1150));
      expect(restored.calibratedAcceptThreshold, equals(0.84));
      expect(restored.calibratedSpeechFloorDbfs, equals(-36.5));
    });

    test('compares baseline vs calibrated performance on RecognitionTestHarness', () {
      final dataset = RecognitionTestHarness.standardBenchmarkDataset();

      // Baseline balanced config
      final baselineMetrics = RecognitionTestHarness.evaluateDataset(
        testCases: dataset,
        config: RecognitionConfig.balanced,
      );

      // Tailored config derived from calibration profile
      const tailoredConfig = RecognitionConfig(
        acceptThreshold: 0.84,
        uncertainThreshold: 0.65,
        speechThresholdDbfs: -38.0,
      );
      final calibratedMetrics = RecognitionTestHarness.evaluateDataset(
        testCases: dataset,
        config: tailoredConfig,
      );

      // Both must maintain zero false positives and high precision
      expect(baselineMetrics.precision, 1.0);
      expect(calibratedMetrics.precision, 1.0);
      expect(calibratedMetrics.falsePositives, 0);
      expect(calibratedMetrics.recall, greaterThanOrEqualTo(0.95));
    });

    test('captures and stores user pronunciation aliases during calibration', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final examples = [
        createSyntheticExample(amplitude: 0.5, durationMs: 1000, timestamp: t0),
        createSyntheticExample(amplitude: 0.6, durationMs: 1050, timestamp: t0.add(const Duration(seconds: 2))),
      ];

      final profile = engine.calibrate(
        dhikr: testDhikr,
        examples: examples,
        recognizedTranscripts: [
          'أستعو في',
          'استل في رضنا',
        ],
      );

      expect(profile.calibratedAliases, contains('أستعو في'));
      expect(profile.calibratedAliases, contains('استل في رضنا'));

      // Serialization round-trip preserves user calibrated aliases
      final json = profile.toJson();
      final restored = RecognitionProfile.fromJson(json);
      expect(restored.calibratedAliases, equals(profile.calibratedAliases));
    });
  });
}
