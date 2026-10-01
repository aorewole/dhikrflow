import 'dart:async';

import 'audio_chunk.dart';

/// Abstract contract for live or simulated audio input streams.
///
/// Complies with `docs/RECOGNITION_SPEC.md` Section 3.
abstract interface class AudioSource {
  /// Stream of raw in-memory PCM audio chunks.
  Stream<AudioChunk> get chunks;

  /// Whether microphone permission has been granted.
  Future<bool> hasPermission();

  /// Prompts system microphone permission dialog if not yet granted.
  Future<bool> requestPermission();

  /// Starts streaming audio from the source.
  Future<void> start();

  /// Immediately stops audio capture and flushes buffers.
  Future<void> stop();

  /// Whether the audio source is actively capturing.
  bool get isRecording;

  /// Releases platform and streaming resources.
  void dispose();
}
