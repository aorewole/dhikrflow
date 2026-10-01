/// Configurable thresholds and tuning parameters for the recognition and VAD pipeline.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 11 and `docs/BUILD_ROADMAP.md` Phase 7:
/// - Configurable confidence thresholds.
/// - Calibrated presets (Balanced, High Precision / Strict, High Recall / Sensitive).
class RecognitionConfig {
  /// Minimum similarity threshold to accept a candidate repetition (e.g. 0.85).
  final double acceptThreshold;

  /// Lower bound threshold below which candidates are completely ignored (e.g. 0.65).
  /// Candidates between uncertainThreshold and acceptThreshold are marked UNCERTAIN
  /// and do NOT increment the count automatically.
  final double uncertainThreshold;

  /// Ambient audio dBFS threshold for VAD speech gating.
  final double speechThresholdDbfs;

  /// Duration in milliseconds to bridge intra-phrase micro-pauses (e.g. 350ms).
  final int hangoverDurationMs;

  /// Minimum speech duration in milliseconds to filter out clicks/taps (e.g. 120ms).
  final int minSpeechDurationMs;

  /// Whether VAD adapts its threshold dynamically to room noise floor.
  final bool adaptiveNoiseTracking;

  const RecognitionConfig({
    this.acceptThreshold = 0.85,
    this.uncertainThreshold = 0.65,
    this.speechThresholdDbfs = -40.0,
    this.hangoverDurationMs = 350,
    this.minSpeechDurationMs = 120,
    this.adaptiveNoiseTracking = true,
  });

  /// Default balanced preset: calibrated to eliminate false positives while capturing natural recitation.
  static const RecognitionConfig balanced = RecognitionConfig(
    acceptThreshold: 0.85,
    uncertainThreshold: 0.65,
    speechThresholdDbfs: -40.0,
    hangoverDurationMs: 350,
    minSpeechDurationMs: 120,
    adaptiveNoiseTracking: true,
  );

  /// High precision / strict preset: minimizes false positives in noisy or conversational environments.
  static const RecognitionConfig strict = RecognitionConfig(
    acceptThreshold: 0.90,
    uncertainThreshold: 0.75,
    speechThresholdDbfs: -36.0,
    hangoverDurationMs: 300,
    minSpeechDurationMs: 150,
    adaptiveNoiseTracking: true,
  );

  /// High recall / sensitive preset: captures quiet or whisper recitation in calm environments.
  static const RecognitionConfig sensitive = RecognitionConfig(
    acceptThreshold: 0.80,
    uncertainThreshold: 0.60,
    speechThresholdDbfs: -46.0,
    hangoverDurationMs: 400,
    minSpeechDurationMs: 100,
    adaptiveNoiseTracking: true,
  );

  RecognitionConfig copyWith({
    double? acceptThreshold,
    double? uncertainThreshold,
    double? speechThresholdDbfs,
    int? hangoverDurationMs,
    int? minSpeechDurationMs,
    bool? adaptiveNoiseTracking,
  }) {
    return RecognitionConfig(
      acceptThreshold: acceptThreshold ?? this.acceptThreshold,
      uncertainThreshold: uncertainThreshold ?? this.uncertainThreshold,
      speechThresholdDbfs: speechThresholdDbfs ?? this.speechThresholdDbfs,
      hangoverDurationMs: hangoverDurationMs ?? this.hangoverDurationMs,
      minSpeechDurationMs: minSpeechDurationMs ?? this.minSpeechDurationMs,
      adaptiveNoiseTracking:
          adaptiveNoiseTracking ?? this.adaptiveNoiseTracking,
    );
  }

  Map<String, dynamic> toJson() => {
    'acceptThreshold': acceptThreshold,
    'uncertainThreshold': uncertainThreshold,
    'speechThresholdDbfs': speechThresholdDbfs,
    'hangoverDurationMs': hangoverDurationMs,
    'minSpeechDurationMs': minSpeechDurationMs,
    'adaptiveNoiseTracking': adaptiveNoiseTracking,
  };

  factory RecognitionConfig.fromJson(Map<String, dynamic> json) {
    return RecognitionConfig(
      acceptThreshold: (json['acceptThreshold'] as num?)?.toDouble() ?? 0.85,
      uncertainThreshold:
          (json['uncertainThreshold'] as num?)?.toDouble() ?? 0.65,
      speechThresholdDbfs:
          (json['speechThresholdDbfs'] as num?)?.toDouble() ?? -40.0,
      hangoverDurationMs: json['hangoverDurationMs'] as int? ?? 350,
      minSpeechDurationMs: json['minSpeechDurationMs'] as int? ?? 120,
      adaptiveNoiseTracking: json['adaptiveNoiseTracking'] as bool? ?? true,
    );
  }
}
