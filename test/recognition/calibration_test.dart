import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr_counter/domain/recognition/recognition_config.dart';
import 'package:dhikr_counter/recognition/calibration/recognition_test_harness.dart';

void main() {
  group('RecognitionConfig Tests', () {
    test('presets have valid monotonically consistent thresholds', () {
      expect(
        RecognitionConfig.whisper.acceptThreshold,
        lessThan(RecognitionConfig.sensitive.acceptThreshold),
      );
      expect(
        RecognitionConfig.sensitive.acceptThreshold,
        lessThan(RecognitionConfig.balanced.acceptThreshold),
      );
      expect(
        RecognitionConfig.balanced.acceptThreshold,
        lessThan(RecognitionConfig.strict.acceptThreshold),
      );

      expect(
        RecognitionConfig.whisper.speechThresholdDbfs,
        lessThan(RecognitionConfig.sensitive.speechThresholdDbfs),
      );
      expect(
        RecognitionConfig.sensitive.speechThresholdDbfs,
        lessThan(RecognitionConfig.balanced.speechThresholdDbfs),
      );
      expect(
        RecognitionConfig.balanced.speechThresholdDbfs,
        lessThan(RecognitionConfig.strict.speechThresholdDbfs),
      );
    });

    test('serializes and deserializes to JSON correctly', () {
      const original = RecognitionConfig(
        acceptThreshold: 0.88,
        uncertainThreshold: 0.70,
        speechThresholdDbfs: -38.0,
        hangoverDurationMs: 320,
        minSpeechDurationMs: 140,
        adaptiveNoiseTracking: false,
      );

      final json = original.toJson();
      final restored = RecognitionConfig.fromJson(json);

      expect(restored.acceptThreshold, 0.88);
      expect(restored.uncertainThreshold, 0.70);
      expect(restored.speechThresholdDbfs, -38.0);
      expect(restored.hangoverDurationMs, 320);
      expect(restored.minSpeechDurationMs, 140);
      expect(restored.adaptiveNoiseTracking, isFalse);
    });
  });

  group('RecognitionTestHarness Empirical Calibration (Phase 7)', () {
    final dataset = RecognitionTestHarness.standardBenchmarkDataset();

    test('Balanced preset achieves 100% precision and zero false positives on negative speech', () {
      final metrics = RecognitionTestHarness.evaluateDataset(
        testCases: dataset,
        config: RecognitionConfig.balanced,
      );

      // Verify zero false positives
      expect(
        metrics.falsePositives,
        0,
        reason: 'Balanced preset must not hallucinate false repetitions',
      );
      expect(
        metrics.negativeFpRate,
        0.0,
        reason: 'False positive rate on negative speech must be 0%',
      );

      // Verify high precision and recall
      expect(metrics.precision, 1.0);
      expect(metrics.recall, greaterThanOrEqualTo(0.95));
      expect(metrics.f1Score, greaterThanOrEqualTo(0.97));

      // Verify absolute count error is very small across entire diverse dataset
      expect(metrics.totalAbsoluteError, lessThanOrEqualTo(1));
    });

    test('Strict preset enforces highest precision threshold', () {
      final metrics = RecognitionTestHarness.evaluateDataset(
        testCases: dataset,
        config: RecognitionConfig.strict,
      );

      expect(metrics.falsePositives, 0);
      expect(metrics.precision, 1.0);
      expect(metrics.negativeFpRate, 0.0);
    });

    test('Sensitive preset captures edge-case degraded phonemes', () {
      final metrics = RecognitionTestHarness.evaluateDataset(
        testCases: dataset,
        config: RecognitionConfig.sensitive,
      );

      expect(
        metrics.recall,
        1.0,
        reason: 'Sensitive preset should capture 100% of target repetitions',
      );
      expect(
        metrics.negativeFpRate,
        0.0,
        reason: 'Negative speech must still be rejected',
      );
    });

    test('Parametric confidence sweep demonstrates calibration stability', () {
      // Evaluate across thresholds from 0.75 to 0.92
      final thresholds = [0.75, 0.80, 0.85, 0.90, 0.92];
      final sweepResults = <double, CalibrationMetrics>{};

      for (final t in thresholds) {
        final config = RecognitionConfig(
          acceptThreshold: t,
          uncertainThreshold: t - 0.20,
        );
        sweepResults[t] = RecognitionTestHarness.evaluateDataset(
          testCases: dataset,
          config: config,
        );
      }

      // At all operational thresholds, negative conversation must have zero false positives
      for (final t in thresholds) {
        expect(
          sweepResults[t]!.negativeFpRate,
          0.0,
          reason: 'Threshold $t must reject unrelated speech',
        );
      }

      // Default 0.85 balances recall with robustness
      final balancedMetrics = sweepResults[0.85]!;
      expect(balancedMetrics.precision, 1.0);
      expect(balancedMetrics.recall, greaterThanOrEqualTo(0.95));
    });
  });
}
