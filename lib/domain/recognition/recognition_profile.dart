import 'recognition_config.dart';

/// Compact, privacy-preserving profile created during personal calibration.
///
/// Follows specifications in `AGENTS.md` and `docs/BUILD_ROADMAP.md` Phase 12:
/// - Processed 100% locally.
/// - Raw audio is discarded immediately after parameter extraction.
/// - Does not attempt full neural network fine-tuning on mobile devices.
/// - Tunes acoustic sensitivity (dBFS floor) and matching tolerance to user's voice.
class RecognitionProfile {
  final String id;
  final String dhikrId;
  final double averageSpeechDbfs;
  final int averageRepetitionDurationMs;
  final double calibratedAcceptThreshold;
  final double calibratedSpeechFloorDbfs;
  final DateTime createdAt;

  const RecognitionProfile({
    required this.id,
    required this.dhikrId,
    required this.averageSpeechDbfs,
    required this.averageRepetitionDurationMs,
    required this.calibratedAcceptThreshold,
    required this.calibratedSpeechFloorDbfs,
    required this.createdAt,
  });

  /// Derives an optimized [RecognitionConfig] tailored to this user's voice profile.
  RecognitionConfig toCalibratedConfig({
    RecognitionConfig baseConfig = RecognitionConfig.balanced,
  }) {
    return baseConfig.copyWith(
      speechThresholdDbfs: calibratedSpeechFloorDbfs,
      acceptThreshold: calibratedAcceptThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dhikrId': dhikrId,
    'averageSpeechDbfs': averageSpeechDbfs,
    'averageRepetitionDurationMs': averageRepetitionDurationMs,
    'calibratedAcceptThreshold': calibratedAcceptThreshold,
    'calibratedSpeechFloorDbfs': calibratedSpeechFloorDbfs,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RecognitionProfile.fromJson(Map<String, dynamic> json) {
    return RecognitionProfile(
      id: json['id'] as String,
      dhikrId: json['dhikrId'] as String,
      averageSpeechDbfs: (json['averageSpeechDbfs'] as num).toDouble(),
      averageRepetitionDurationMs:
          (json['averageRepetitionDurationMs'] as num).toInt(),
      calibratedAcceptThreshold:
          (json['calibratedAcceptThreshold'] as num).toDouble(),
      calibratedSpeechFloorDbfs:
          (json['calibratedSpeechFloorDbfs'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
