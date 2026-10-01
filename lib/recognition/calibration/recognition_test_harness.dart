import 'dart:math' as math;

import '../../domain/recognition/recognition_config.dart';
import '../text/phrase_matcher.dart';
import '../text/streaming_repetition_detector.dart';

/// Single test vector for recognition confidence calibration.
class CalibrationTestCase {
  final String id;
  final String description;
  final int groundTruthCount;
  final List<String> simulatedTranscriptSteps;
  final String targetPhrase;
  final List<String> targetAliases;
  final bool isNegativeExample;

  const CalibrationTestCase({
    required this.id,
    required this.description,
    required this.groundTruthCount,
    required this.simulatedTranscriptSteps,
    required this.targetPhrase,
    this.targetAliases = const [],
    this.isNegativeExample = false,
  });
}

/// Result of evaluating a single test case.
class TestCaseResult {
  final CalibrationTestCase testCase;
  final int detectedCount;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final int absoluteError;

  const TestCaseResult({
    required this.testCase,
    required this.detectedCount,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.absoluteError,
  });
}

/// Aggregate performance metrics across a calibration dataset.
class CalibrationMetrics {
  final RecognitionConfig config;
  final List<TestCaseResult> results;
  final int totalGroundTruth;
  final int totalDetected;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final int totalAbsoluteError;

  const CalibrationMetrics({
    required this.config,
    required this.results,
    required this.totalGroundTruth,
    required this.totalDetected,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.totalAbsoluteError,
  });

  double get precision {
    final denom = truePositives + falsePositives;
    if (denom == 0) return truePositives == 0 ? 1.0 : 0.0;
    return truePositives / denom;
  }

  double get recall {
    final denom = truePositives + falseNegatives;
    if (denom == 0) return 1.0;
    return truePositives / denom;
  }

  double get f1Score {
    final p = precision;
    final r = recall;
    if (p + r == 0) return 0.0;
    return 2.0 * (p * r) / (p + r);
  }

  /// False positive rate on negative test cases (unrelated speech).
  double get negativeFpRate {
    final negativeResults = results
        .where((r) => r.testCase.isNegativeExample)
        .toList();
    if (negativeResults.isEmpty) return 0.0;
    final falsePositiveCount = negativeResults.fold<int>(
      0,
      (sum, r) => sum + r.falsePositives,
    );
    return falsePositiveCount / negativeResults.length;
  }

  @override
  String toString() {
    return 'CalibrationMetrics(\n'
        '  Threshold: ${config.acceptThreshold.toStringAsFixed(2)},\n'
        '  Ground Truth: $totalGroundTruth, Detected: $totalDetected,\n'
        '  TP: $truePositives, FP: $falsePositives, FN: $falseNegatives,\n'
        '  Precision: ${(precision * 100).toStringAsFixed(1)}%,\n'
        '  Recall: ${(recall * 100).toStringAsFixed(1)}%,\n'
        '  F1 Score: ${(f1Score * 100).toStringAsFixed(1)}%,\n'
        '  Negative FP Rate: ${(negativeFpRate * 100).toStringAsFixed(1)}%,\n'
        '  Total Absolute Error: $totalAbsoluteError\n'
        ')';
  }
}

/// Offline test harness for measuring phrase-matching and repetition-detection calibration.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 11 and `docs/BUILD_ROADMAP.md` Phase 7.
class RecognitionTestHarness {
  /// Evaluates a list of test cases against a specific [RecognitionConfig].
  static CalibrationMetrics evaluateDataset({
    required List<CalibrationTestCase> testCases,
    required RecognitionConfig config,
  }) {
    final matcher = PhraseMatcher(
      acceptThreshold: config.acceptThreshold,
      uncertainThreshold: config.uncertainThreshold,
    );

    final results = <TestCaseResult>[];

    int totalGroundTruth = 0;
    int totalDetected = 0;
    int totalTp = 0;
    int totalFp = 0;
    int totalFn = 0;
    int totalAbsError = 0;

    for (final tc in testCases) {
      final detector = StreamingRepetitionDetector(
        targetPhrase: tc.targetPhrase,
        targetAliases: tc.targetAliases,
        matcher: matcher,
      );

      for (final step in tc.simulatedTranscriptSteps) {
        detector.processTranscript(step);
      }

      final detected = detector.totalAcceptedOccurrences;
      final expected = tc.groundTruthCount;

      final tp = math.min(detected, expected);
      final fp = math.max(0, detected - expected);
      final fn = math.max(0, expected - detected);
      final absError = (detected - expected).abs();

      totalGroundTruth += expected;
      totalDetected += detected;
      totalTp += tp;
      totalFp += fp;
      totalFn += fn;
      totalAbsError += absError;

      results.add(
        TestCaseResult(
          testCase: tc,
          detectedCount: detected,
          truePositives: tp,
          falsePositives: fp,
          falseNegatives: fn,
          absoluteError: absError,
        ),
      );
    }

    return CalibrationMetrics(
      config: config,
      results: results,
      totalGroundTruth: totalGroundTruth,
      totalDetected: totalDetected,
      truePositives: totalTp,
      falsePositives: totalFp,
      falseNegatives: totalFn,
      totalAbsoluteError: totalAbsError,
    );
  }

  /// Comprehensive standard benchmark dataset for dhikr counting calibration.
  static List<CalibrationTestCase> standardBenchmarkDataset() {
    const target = 'أَسْتَغْفِرُ اللَّهَ';
    const aliases = ['أستغفر بالله'];

    return const [
      // 1. Single clear repetition
      CalibrationTestCase(
        id: 'single_clear',
        description: 'Single isolated clear recitation',
        groundTruthCount: 1,
        simulatedTranscriptSteps: ['أستغفر الله'],
        targetPhrase: target,
      ),

      // 2. Fast 2x repetitions
      CalibrationTestCase(
        id: 'double_fast',
        description: 'Two continuous repetitions',
        groundTruthCount: 2,
        simulatedTranscriptSteps: ['أستغفر الله أستغفر الله'],
        targetPhrase: target,
      ),

      // 3. Fast 4x rapid repetitions
      CalibrationTestCase(
        id: 'rapid_4x',
        description: 'Four rapid repetitions without pauses',
        groundTruthCount: 4,
        simulatedTranscriptSteps: [
          'أستغفر الله أستغفر الله أستغفر الله أستغفر الله',
        ],
        targetPhrase: target,
      ),

      // 4. Ten continuous repetitions
      CalibrationTestCase(
        id: 'continuous_10x',
        description: 'Ten continuous repetitions',
        groundTruthCount: 10,
        simulatedTranscriptSteps: [
          'أستغفر الله أستغفر الله أستغفر الله أستغفر الله أستغفر الله '
              'أستغفر الله أستغفر الله أستغفر الله أستغفر الله أستغفر الله',
        ],
        targetPhrase: target,
      ),

      // 5. Streaming partial hypotheses leading to 2 repetitions
      CalibrationTestCase(
        id: 'streaming_evolving',
        description: 'Partial evolving stream hypotheses',
        groundTruthCount: 2,
        simulatedTranscriptSteps: [
          'استغ',
          'استغفر',
          'استغفر الله',
          'استغفر الله استغفر',
          'استغفر الله استغفر الله',
        ],
        targetPhrase: target,
      ),

      // 6. Joined token format (no space)
      CalibrationTestCase(
        id: 'joined_tokens',
        description: 'Joined word token format (استغفرالله)',
        groundTruthCount: 3,
        simulatedTranscriptSteps: ['استغفرالله استغفرالله استغفرالله'],
        targetPhrase: target,
      ),

      // 7. Legitimate alias
      CalibrationTestCase(
        id: 'valid_alias',
        description: 'Supported theological alias (أستغفر بالله)',
        groundTruthCount: 1,
        simulatedTranscriptSteps: ['أستغفر بالله'],
        targetPhrase: target,
        targetAliases: aliases,
      ),

      // 8. Slight ASR phoneme drop (tolerable under controlled fuzzy match)
      CalibrationTestCase(
        id: 'minor_asr_typo',
        description: 'Minor ASR acoustic omission (missing terminal letter)',
        groundTruthCount: 1,
        simulatedTranscriptSteps: ['استغفر الل'],
        targetPhrase: target,
      ),

      // 9. Negative example: Unrelated conversational Arabic
      CalibrationTestCase(
        id: 'neg_arabic_conv',
        description: 'Everyday unrelated Arabic dialogue',
        groundTruthCount: 0,
        simulatedTranscriptSteps: [
          'السلام عليكم كيف حالك اليوم إن شاء الله بخير',
        ],
        targetPhrase: target,
        isNegativeExample: true,
      ),

      // 10. Negative example: Different dhikr (SubhanAllah, Alhamdulillah)
      CalibrationTestCase(
        id: 'neg_other_dhikr',
        description: 'Different dhikr recited (SubhanAllah / Alhamdulillah)',
        groundTruthCount: 0,
        simulatedTranscriptSteps: [
          'سبحان الله وبحمده سبحان الله العظيم والحمد لله رب العالمين',
        ],
        targetPhrase: target,
        isNegativeExample: true,
      ),

      // 11. Negative example: English conversational noise
      CalibrationTestCase(
        id: 'neg_english_noise',
        description: 'Background English speech transcription',
        groundTruthCount: 0,
        simulatedTranscriptSteps: [
          'Hello can you hear me please turn off the volume',
        ],
        targetPhrase: target,
        isNegativeExample: true,
      ),

      // 12. Negative example: Cough / noise fragment
      CalibrationTestCase(
        id: 'neg_noise_fragment',
        description: 'Transient noise acoustic fragments',
        groundTruthCount: 0,
        simulatedTranscriptSteps: ['آه أم إه'],
        targetPhrase: target,
        isNegativeExample: true,
      ),

      // 13. Mixed speech: target embedded within unrelated speech
      CalibrationTestCase(
        id: 'mixed_speech',
        description: 'Target phrase embedded inside conversational narrative',
        groundTruthCount: 2,
        simulatedTranscriptSteps: [
          'ثم قال العبد أستغفر الله وتاب إلى ربه ثم كرر أستغفر الله فغفر له',
        ],
        targetPhrase: target,
      ),
    ];
  }
}
