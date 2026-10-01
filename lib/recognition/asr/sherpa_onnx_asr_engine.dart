import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../vad/vad_event.dart';
import 'asr_engine.dart';

/// Offline on-device Automatic Speech Recognition engine powered by sherpa-onnx and Whisper Tiny int8.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` and `docs/BUILD_ROADMAP.md` Phase 4:
/// - 100% on-device processing via native C++ ONNX runtime.
/// - Zero network transmission or cloud API calls.
/// - Transcribes in-memory PCM audio buffers directly; never persists audio files.
class SherpaOnnxAsrEngine implements AsrEngine {
  final String encoderPath;
  final String decoderPath;
  final String tokensPath;
  final int numThreads;

  sherpa.OfflineRecognizer? _recognizer;
  bool _initialized = false;

  SherpaOnnxAsrEngine({
    required this.encoderPath,
    required this.decoderPath,
    required this.tokensPath,
    this.numThreads = 2,
  });

  @override
  bool get isInitialized => _initialized && _recognizer != null;

  /// Checks whether all three required Whisper ONNX model files exist on disk.
  bool get areModelFilesPresent {
    return File(encoderPath).existsSync() &&
        File(decoderPath).existsSync() &&
        File(tokensPath).existsSync();
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    if (!areModelFilesPresent) {
      if (kDebugMode) {
        debugPrint(
          '[SherpaOnnxAsrEngine] Model files not found on disk at:\n'
          '  Encoder: $encoderPath\n'
          '  Decoder: $decoderPath\n'
          '  Tokens: $tokensPath',
        );
      }
      return;
    }

    try {
      // Initialize native FFI bindings
      sherpa.initBindings();

      final whisperConfig = sherpa.OfflineWhisperModelConfig(
        encoder: encoderPath,
        decoder: decoderPath,
        language: 'ar',
        task: 'transcribe',
      );

      final modelConfig = sherpa.OfflineModelConfig(
        whisper: whisperConfig,
        tokens: tokensPath,
        numThreads: numThreads,
        debug: kDebugMode,
      );

      final recognizerConfig = sherpa.OfflineRecognizerConfig(
        model: modelConfig,
        decodingMethod: 'greedy_search',
      );

      _recognizer = sherpa.OfflineRecognizer(recognizerConfig);
      _initialized = true;

      if (kDebugMode) {
        debugPrint(
          '[SherpaOnnxAsrEngine] Initialized offline Whisper recognizer successfully.',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SherpaOnnxAsrEngine] Initialization failed: $e\n$st');
      }
      _recognizer = null;
      _initialized = false;
    }
  }

  @override
  Future<String> transcribeSegment(SpeechSegment segment) async {
    if (!_initialized || _recognizer == null) {
      throw StateError(
        'SherpaOnnxAsrEngine is not initialized or model files are missing.',
      );
    }

    // Convert in-memory AudioChunks to continuous normalized float32 samples
    final totalSamplesCount = segment.chunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.sampleCount,
    );

    if (totalSamplesCount == 0) return '';

    final floatSamples = Float32List(totalSamplesCount);
    int offset = 0;

    for (final chunk in segment.chunks) {
      final pcm16 = chunk.pcm16Samples;
      for (int i = 0; i < pcm16.length; i++) {
        floatSamples[offset++] = pcm16[i] / 32768.0;
      }
    }

    final stream = _recognizer!.createStream();
    try {
      stream.acceptWaveform(samples: floatSamples, sampleRate: 16000);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);

      if (kDebugMode) {
        debugPrint('[SherpaOnnxAsrEngine] Raw transcript: "${result.text}"');
      }

      return result.text;
    } finally {
      stream.free();
    }
  }

  @override
  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _initialized = false;
  }
}
