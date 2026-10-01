import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_chunk.dart';
import 'audio_source.dart';

/// Mock audio source capable of generating synthetic PCM sine waves or silence for testing.
class MockAudioSource implements AudioSource {
  final StreamController<AudioChunk> _controller =
      StreamController<AudioChunk>.broadcast();
  bool _isRecording = false;
  bool permissionGranted = true;

  @override
  Stream<AudioChunk> get chunks => _controller.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> start() async {
    if (!permissionGranted) {
      throw StateError('Microphone permission not granted.');
    }
    _isRecording = true;
  }

  @override
  Future<void> stop() async {
    _isRecording = false;
  }

  /// Manually injects a silent audio chunk into the stream.
  void emitSilence({
    int durationMs = 100,
    int sampleRate = 16000,
    DateTime? timestamp,
  }) {
    if (!_isRecording) return;
    final sampleCount = (sampleRate * (durationMs / 1000.0)).round();
    final bytes = Uint8List(sampleCount * 2); // 16-bit = 2 bytes per sample
    _controller.add(
      AudioChunk(bytes: bytes, sampleRate: sampleRate, timestamp: timestamp),
    );
  }

  /// Manually injects an audible tone burst (e.g. 300Hz-800Hz voice fundamental range) into the stream.
  void emitTone({
    double frequencyHz = 300.0,
    int durationMs = 200,
    double amplitude = 0.5,
    int sampleRate = 16000,
    DateTime? timestamp,
  }) {
    if (!_isRecording) return;
    final sampleCount = (sampleRate * (durationMs / 1000.0)).round();
    final bytes = Uint8List(sampleCount * 2);
    final byteData = ByteData.sublistView(bytes);

    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final sampleVal =
          (amplitude * 32767.0 * math.sin(2.0 * math.pi * frequencyHz * t))
              .round()
              .clamp(-32768, 32767);
      byteData.setInt16(i * 2, sampleVal, Endian.little);
    }

    _controller.add(
      AudioChunk(bytes: bytes, sampleRate: sampleRate, timestamp: timestamp),
    );
  }

  @override
  void dispose() {
    _isRecording = false;
    _controller.close();
  }
}
