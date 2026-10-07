/// Diagnostic recognition event for developer tools, calibration, and live active session transcription.
class RecognitionDiagnostic {
  final DateTime timestamp;
  final String? rawTranscript;
  final String? normalizedTranscript;
  final int newOccurrences;
  final double? energyDbfs;
  final bool isSpeaking;
  final double? confidence;
  final List<String> pendingPrefixTokens;
  final Duration? currentPace;
  final bool? isCadenceMatched;

  /// Number of phrase matches found by the ASR phrase-matcher (null if no
  /// recognition event occurred, e.g. VAD-only diagnostics).
  final int? asrCount;

  /// Estimated count returned by the Acoustic Repetition Estimator (ARe).
  /// Null when no recognition event occurred.
  final int? areCount;

  /// Human-readable explanation of which engine was trusted and why,
  /// e.g. "ASR(2)" or "ARe recovery(3, conf=0.88)".
  /// Null when no recognition event occurred.
  final String? fusionReason;

  /// Whether this segment was verified as legitimate voiced human speech
  /// (as opposed to an impulsive acoustic transient like a clap, knock, or thump).
  final bool isVoiceVerified;

  const RecognitionDiagnostic({
    required this.timestamp,
    this.rawTranscript,
    this.normalizedTranscript,
    this.newOccurrences = 0,
    this.energyDbfs,
    this.isSpeaking = false,
    this.confidence,
    this.pendingPrefixTokens = const [],
    this.currentPace,
    this.isCadenceMatched,
    this.asrCount,
    this.areCount,
    this.fusionReason,
    this.isVoiceVerified = false,
  });

  /// Whether this diagnostic carries a non-empty speech transcription.
  bool get hasTranscript =>
      rawTranscript != null && rawTranscript!.trim().isNotEmpty;

  /// Whether this speech segment directly produced a recognized count event (+1 or +N).
  bool get isCounted => newOccurrences > 0;

  /// Whether this segment is a valid prefix buffered waiting for completion (e.g. SubhanAllah in SubhanAllahi wa bihamdihi).
  bool get isBuffering => pendingPrefixTokens.isNotEmpty && newOccurrences == 0;
}
