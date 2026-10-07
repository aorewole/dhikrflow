/// Configurable thresholds and tuning parameters for the recognition and VAD pipeline.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 11 and `AGENTS.md`:
/// - Configurable confidence thresholds.
/// - Calibrated presets (Balanced, Sensitive, Whisper, Strict).
class RecognitionConfig {
  /// Minimum similarity threshold to accept a candidate repetition (e.g. 0.82).
  final double acceptThreshold;

  /// Lower bound threshold below which candidates are completely ignored (e.g. 0.62).
  /// Candidates between uncertainThreshold and acceptThreshold are marked UNCERTAIN
  /// and do NOT increment the count automatically.
  final double uncertainThreshold;

  /// Ambient audio dBFS threshold for VAD speech gating.
  final double speechThresholdDbfs;

  /// Duration in milliseconds to bridge intra-phrase micro-pauses (e.g. 240ms).
  final int hangoverDurationMs;

  /// Minimum speech duration in milliseconds to filter out clicks/taps (e.g. 90ms).
  final int minSpeechDurationMs;

  /// Maximum speech duration in milliseconds before concluding segment for rapid recitation (e.g. 1400ms).
  final int maxSpeechDurationMs;

  /// Whether VAD adapts its threshold dynamically to room noise floor.
  final bool adaptiveNoiseTracking;

  /// Whether cadence pacing is factored into repetition recognition.
  final bool cadencePacingEnabled;

  /// Tolerance factor around the expected pace (e.g. 0.35 means +/- 35%).
  final double cadenceTolerance;

  /// Confidence boost applied to near-miss acoustic candidates when cadence matches.
  final double cadenceBonus;

  const RecognitionConfig({
    this.acceptThreshold = 0.74,
    this.uncertainThreshold = 0.55,
    this.speechThresholdDbfs = -55.0,
    this.hangoverDurationMs = 180,
    this.minSpeechDurationMs = 90,
    this.maxSpeechDurationMs = 2600,
    this.adaptiveNoiseTracking = true,
    this.cadencePacingEnabled = true,
    this.cadenceTolerance = 0.35,
    this.cadenceBonus = 0.18,
  });

  /// Default optimized preset: calibrated for whispers, normal distance, and natural pauses.
  static const RecognitionConfig balanced = RecognitionConfig(
    acceptThreshold: 0.74,
    uncertainThreshold: 0.55,
    speechThresholdDbfs: -55.0,
    hangoverDurationMs: 180,
    minSpeechDurationMs: 90,
    maxSpeechDurationMs: 2600,
    adaptiveNoiseTracking: true,
    cadencePacingEnabled: true,
    cadenceTolerance: 0.35,
    cadenceBonus: 0.18,
  );

  /// High recall / sensitive preset: captures quiet speech and whispers in calm environments.
  static const RecognitionConfig sensitive = RecognitionConfig(
    acceptThreshold: 0.71,
    uncertainThreshold: 0.52,
    speechThresholdDbfs: -57.0,
    hangoverDurationMs: 180,
    minSpeechDurationMs: 80,
    maxSpeechDurationMs: 2600,
    adaptiveNoiseTracking: true,
    cadencePacingEnabled: true,
    cadenceTolerance: 0.40,
    cadenceBonus: 0.20,
  );

  /// Dedicated whisper preset: maximum sensitivity for soft whispers and murmurs.
  static const RecognitionConfig whisper = RecognitionConfig(
    acceptThreshold: 0.68,
    uncertainThreshold: 0.50,
    speechThresholdDbfs: -60.0,
    hangoverDurationMs: 180,
    minSpeechDurationMs: 70,
    maxSpeechDurationMs: 2600,
    adaptiveNoiseTracking: true,
    cadencePacingEnabled: true,
    cadenceTolerance: 0.40,
    cadenceBonus: 0.20,
  );

  /// High precision / strict preset: minimizes false positives in noisy or conversational environments.
  static const RecognitionConfig strict = RecognitionConfig(
    acceptThreshold: 0.90,
    uncertainThreshold: 0.75,
    speechThresholdDbfs: -42.0,
    hangoverDurationMs: 180,
    minSpeechDurationMs: 120,
    maxSpeechDurationMs: 2600,
    adaptiveNoiseTracking: true,
    cadencePacingEnabled: true,
    cadenceTolerance: 0.25,
    cadenceBonus: 0.10,
  );

  RecognitionConfig copyWith({
    double? acceptThreshold,
    double? uncertainThreshold,
    double? speechThresholdDbfs,
    int? hangoverDurationMs,
    int? minSpeechDurationMs,
    int? maxSpeechDurationMs,
    bool? adaptiveNoiseTracking,
    bool? cadencePacingEnabled,
    double? cadenceTolerance,
    double? cadenceBonus,
  }) {
    return RecognitionConfig(
      acceptThreshold: acceptThreshold ?? this.acceptThreshold,
      uncertainThreshold: uncertainThreshold ?? this.uncertainThreshold,
      speechThresholdDbfs: speechThresholdDbfs ?? this.speechThresholdDbfs,
      hangoverDurationMs: hangoverDurationMs ?? this.hangoverDurationMs,
      minSpeechDurationMs: minSpeechDurationMs ?? this.minSpeechDurationMs,
      maxSpeechDurationMs: maxSpeechDurationMs ?? this.maxSpeechDurationMs,
      adaptiveNoiseTracking:
          adaptiveNoiseTracking ?? this.adaptiveNoiseTracking,
      cadencePacingEnabled: cadencePacingEnabled ?? this.cadencePacingEnabled,
      cadenceTolerance: cadenceTolerance ?? this.cadenceTolerance,
      cadenceBonus: cadenceBonus ?? this.cadenceBonus,
    );
  }

  Map<String, dynamic> toJson() => {
    'acceptThreshold': acceptThreshold,
    'uncertainThreshold': uncertainThreshold,
    'speechThresholdDbfs': speechThresholdDbfs,
    'hangoverDurationMs': hangoverDurationMs,
    'minSpeechDurationMs': minSpeechDurationMs,
    'maxSpeechDurationMs': maxSpeechDurationMs,
    'adaptiveNoiseTracking': adaptiveNoiseTracking,
    'cadencePacingEnabled': cadencePacingEnabled,
    'cadenceTolerance': cadenceTolerance,
    'cadenceBonus': cadenceBonus,
  };

  factory RecognitionConfig.fromJson(Map<String, dynamic> json) {
    return RecognitionConfig(
      acceptThreshold: (json['acceptThreshold'] as num?)?.toDouble() ?? 0.74,
      uncertainThreshold:
          (json['uncertainThreshold'] as num?)?.toDouble() ?? 0.55,
      speechThresholdDbfs:
          (json['speechThresholdDbfs'] as num?)?.toDouble() ?? -55.0,
      hangoverDurationMs: json['hangoverDurationMs'] as int? ?? 240,
      minSpeechDurationMs: json['minSpeechDurationMs'] as int? ?? 90,
      maxSpeechDurationMs: json['maxSpeechDurationMs'] as int? ?? 5500,
      adaptiveNoiseTracking: json['adaptiveNoiseTracking'] as bool? ?? true,
      cadencePacingEnabled: json['cadencePacingEnabled'] as bool? ?? true,
      cadenceTolerance: (json['cadenceTolerance'] as num?)?.toDouble() ?? 0.35,
      cadenceBonus: (json['cadenceBonus'] as num?)?.toDouble() ?? 0.18,
    );
  }
}
