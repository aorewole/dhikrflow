import '../vad/vad_event.dart';

/// Contract for local on-device Automatic Speech Recognition (ASR) engines.
///
/// Ensures the speech engine remains completely replaceable per `AGENTS.md`.
abstract interface class AsrEngine {
  /// Asynchronously loads weights and initializes the offline engine.
  Future<void> initialize();

  /// Transcribes a concluded voice activity segment into text locally.
  Future<String> transcribeSegment(SpeechSegment segment);

  /// Whether the engine is initialized and ready to transcribe.
  bool get isInitialized;

  /// Releases native memory and resources.
  void dispose();
}
