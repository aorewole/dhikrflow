import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'audio_chunk.dart';
import 'audio_source.dart';

/// Live microphone implementation of [AudioSource] using `package:record`.
///
/// Streams raw 16kHz mono 16-bit PCM audio directly in-memory.
/// Never persists audio to disk.
class RecordAudioSource implements AudioSource {
  final AudioRecorder _recorder;
  final StreamController<AudioChunk> _chunkController =
      StreamController<AudioChunk>.broadcast();
  StreamSubscription<Uint8List>? _streamSubscription;
  bool _isRecording = false;

  RecordAudioSource({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  @override
  Stream<AudioChunk> get chunks => _chunkController.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  @override
  Future<bool> requestPermission() async {
    return _recorder.hasPermission();
  }

  @override
  Future<void> start() async {
    if (_isRecording) return;

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw StateError('Microphone permission not granted.');
    }

    const sampleRatesToTry = [16000, 44100, 48000];
    Stream<Uint8List>? rawStream;
    int activeSampleRate = 16000;

    for (final rate in sampleRatesToTry) {
      try {
        final config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: rate,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        );
        rawStream = await _recorder.startStream(config);
        activeSampleRate = rate;
        debugPrint('[RecordAudioSource] Audio stream started at $rate Hz');
        break;
      } catch (e) {
        debugPrint('[RecordAudioSource] Could not start stream at $rate Hz: $e');
      }
    }

    if (rawStream == null) {
      throw StateError('Failed to initialize audio recorder at any supported sample rate.');
    }

    _isRecording = true;

    _streamSubscription = rawStream.listen(
      (bytes) {
        if (_isRecording) {
          _chunkController.add(
            AudioChunk(bytes: bytes, sampleRate: activeSampleRate, channels: 1),
          );
        }
      },
      onError: (err, stack) {
        debugPrint('[RecordAudioSource] Stream error: $err');
        _isRecording = false;
        _chunkController.addError(err);
      },
      onDone: () {
        debugPrint('[RecordAudioSource] Stream closed');
        _isRecording = false;
      },
      cancelOnError: false,
    );
  }

  @override
  Future<void> stop() async {
    if (!_isRecording) return;
    _isRecording = false;

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {
      // In case native stream was already terminated
    }
  }

  @override
  void dispose() {
    stop();
    _chunkController.close();
    _recorder.dispose();
  }
}
