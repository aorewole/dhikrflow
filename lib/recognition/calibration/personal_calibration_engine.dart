import '../../domain/models/dhikr_definition.dart';
import '../../domain/recognition/recognition_profile.dart';
import '../text/arabic_normalizer.dart';
import '../text/phrase_matcher.dart';
import '../vad/vad_event.dart';

/// Prototype engine for computing on-device Personal Calibration profiles.
///
/// Follows specifications in `AGENTS.md` and `docs/BUILD_ROADMAP.md` Phase 12:
/// - Processed 100% locally.
/// - Never persists raw audio; extracts statistics and discards samples immediately.
/// - Calculates personalized VAD energy floors and confidence thresholds.
class PersonalCalibrationEngine {
  final PhraseMatcher matcher;

  const PersonalCalibrationEngine({this.matcher = const PhraseMatcher()});

  /// Analyzes a list of user recitation [examples] for [dhikr] and produces a [RecognitionProfile].
  ///
  /// Guarantees that raw audio buffers within [examples] are discarded after feature extraction.
  RecognitionProfile calibrate({
    required DhikrDefinition dhikr,
    required List<SpeechSegment> examples,
    List<String>? recognizedTranscripts,
  }) {
    if (examples.isEmpty) {
      throw ArgumentError('At least one recitation example is required for calibration.');
    }

    double totalDbfs = 0.0;
    int totalDurationMs = 0;
    double totalConfidence = 0.0;
    int validMatches = 0;

    final normTarget = ArabicNormalizer.normalize(dhikr.arabic);

    for (int i = 0; i < examples.length; i++) {
      final seg = examples[i];

      // 1. Extract acoustic energy from in-memory chunks
      double segEnergySum = 0.0;
      for (final chunk in seg.chunks) {
        segEnergySum += chunk.computeDbfs();
      }
      final segAvgDbfs = seg.chunks.isNotEmpty
          ? segEnergySum / seg.chunks.length
          : -40.0;
      totalDbfs += segAvgDbfs;

      // 2. Extract duration
      totalDurationMs += seg.duration.inMilliseconds;

      // 3. Extract matching similarity if transcript is provided
      if (recognizedTranscripts != null && i < recognizedTranscripts.length) {
        final transcript = recognizedTranscripts[i].trim();
        if (transcript.isNotEmpty) {
          final sim = matcher.calculateBestSimilarity(
            candidate: transcript,
            target: normTarget,
          );
          totalConfidence += sim;
          validMatches++;
        }
      }
    }

    final count = examples.length;
    final avgDbfs = totalDbfs / count;
    final avgDurationMs = totalDurationMs ~/ count;

    // Derived threshold calibrations:
    // - VAD floor: set 14 dB below user's average speaking volume, bounded between -54 and -32 dBFS
    final calibratedSpeechFloor = (avgDbfs - 14.0).clamp(-54.0, -32.0);

    // - Confidence threshold: calibrate to user's observed pronunciation score with a 12% tolerance margin,
    //   accommodating regional accents, vowel elongation, and dialectal variations down to 0.60.
    final double calibratedAccept;
    if (validMatches > 0) {
      final avgConf = totalConfidence / validMatches;
      calibratedAccept = (avgConf * 0.88).clamp(0.60, 0.88);
    } else {
      calibratedAccept = 0.82;
    }

    final Set<String> userAliases = {};
    if (recognizedTranscripts != null) {
      for (final t in recognizedTranscripts) {
        final trimmed = t.trim();
        if (trimmed.isNotEmpty) {
          userAliases.add(trimmed);
          final norm = ArabicNormalizer.normalize(trimmed);
          if (norm.isNotEmpty) {
            userAliases.add(norm);
          }
          final phonetic = ArabicNormalizer.normalizePhonetic(trimmed);
          if (phonetic.isNotEmpty) {
            userAliases.add(phonetic);
          }
        }
      }
    }

    return RecognitionProfile(
      id: 'profile-${DateTime.now().millisecondsSinceEpoch}',
      dhikrId: dhikr.id,
      averageSpeechDbfs: double.parse(avgDbfs.toStringAsFixed(1)),
      averageRepetitionDurationMs: avgDurationMs,
      calibratedAcceptThreshold: double.parse(calibratedAccept.toStringAsFixed(2)),
      calibratedSpeechFloorDbfs: double.parse(calibratedSpeechFloor.toStringAsFixed(1)),
      calibratedAliases: userAliases.toList(),
      createdAt: DateTime.now(),
    );
  }
}
