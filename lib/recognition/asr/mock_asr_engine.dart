import '../vad/vad_event.dart';
import 'asr_engine.dart';

/// Test implementation of [AsrEngine] that returns deterministic transcripts.
class MockAsrEngine implements AsrEngine {
  bool _initialized = false;
  String defaultTranscript;
  final List<String> queuedTranscripts = [];
  final List<SpeechSegment> transcribedSegments = [];

  MockAsrEngine({this.defaultTranscript = 'أستغفر الله'});

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<String> transcribeSegment(SpeechSegment segment) async {
    if (!_initialized) {
      throw StateError('AsrEngine is not initialized.');
    }
    transcribedSegments.add(segment);
    if (queuedTranscripts.isNotEmpty) {
      return queuedTranscripts.removeAt(0);
    }
    return defaultTranscript;
  }

  @override
  void dispose() {
    _initialized = false;
    transcribedSegments.clear();
    queuedTranscripts.clear();
  }
}
