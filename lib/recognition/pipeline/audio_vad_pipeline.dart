import 'dart:async';

import '../audio/audio_chunk.dart';
import '../audio/audio_source.dart';
import '../vad/vad_event.dart';
import '../vad/voice_activity_detector.dart';

/// Combined audio ingestion and local Voice Activity Detection pipeline.
class AudioVadPipeline {
  final AudioSource audioSource;
  final VoiceActivityDetector vad;
  StreamSubscription<AudioChunk>? _audioSubscription;
  bool _isRunning = false;

  AudioVadPipeline({required this.audioSource, VoiceActivityDetector? vad})
    : vad = vad ?? VoiceActivityDetector();

  Stream<VadStateEvent> get vadStateEvents => vad.stateEvents;
  Stream<SpeechSegment> get speechSegments => vad.completedSegments;

  bool get isRunning => _isRunning;
  bool get isSpeaking => vad.isSpeaking;

  Future<void> start() async {
    if (_isRunning) return;

    await audioSource.start();
    _isRunning = true;
    vad.reset();

    _audioSubscription = audioSource.chunks.listen(
      (chunk) {
        if (_isRunning) {
          vad.processChunk(chunk);
        }
      },
      onError: (err) {
        // Log or handle error without crashing
      },
    );
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    vad.reset();
    await audioSource.stop();
  }

  void dispose() {
    stop();
    vad.dispose();
    audioSource.dispose();
  }
}
