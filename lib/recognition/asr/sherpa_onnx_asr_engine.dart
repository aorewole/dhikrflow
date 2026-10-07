import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../text/arabic_normalizer.dart';
import '../vad/vad_event.dart';
import 'asr_engine.dart';

/// Supported model architectures for offline on-device speech recognition in sherpa-onnx.
enum SherpaModelType {
  /// Purpose-built Arabic speech recognition model (Moonshine v2 architecture).
  moonshine,

  /// OpenAI Whisper architecture running in Arabic transcription mode.
  whisper,
}

/// Offline on-device Automatic Speech Recognition engine powered by sherpa-onnx.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` and `AGENTS.md`:
/// - 100% on-device processing via native C++ ONNX runtime.
/// - Zero network transmission or cloud API calls.
/// - Transcribes in-memory PCM audio buffers directly; never persists audio files.
/// - Enforces strict Arabic output sanitization: strips any Latin/English letters
///   and suppresses autoregressive silence loops.
class SherpaOnnxAsrEngine implements AsrEngine {
  final String encoderPath;
  final String decoderPath;
  final String tokensPath;
  final SherpaModelType modelType;
  final int numThreads;

  sherpa.OfflineRecognizer? _recognizer;
  bool _initialized = false;

  SherpaOnnxAsrEngine({
    required this.encoderPath,
    required this.decoderPath,
    required this.tokensPath,
    this.modelType = SherpaModelType.whisper,
    this.numThreads = 2,
  });

  /// Factory constructor for the purpose-built Moonshine Arabic model.
  factory SherpaOnnxAsrEngine.moonshine({
    required String encoderPath,
    required String decoderPath,
    required String tokensPath,
    int numThreads = 2,
  }) {
    return SherpaOnnxAsrEngine(
      encoderPath: encoderPath,
      decoderPath: decoderPath,
      tokensPath: tokensPath,
      modelType: SherpaModelType.moonshine,
      numThreads: numThreads,
    );
  }

  /// Factory constructor for Whisper models (Base or Tiny).
  factory SherpaOnnxAsrEngine.whisper({
    required String encoderPath,
    required String decoderPath,
    required String tokensPath,
    int numThreads = 2,
  }) {
    return SherpaOnnxAsrEngine(
      encoderPath: encoderPath,
      decoderPath: decoderPath,
      tokensPath: tokensPath,
      modelType: SherpaModelType.whisper,
      numThreads: numThreads,
    );
  }

  @override
  bool get isInitialized => _initialized && _recognizer != null;

  /// Checks whether all required ONNX model files exist on disk.
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

      final sherpa.OfflineModelConfig modelConfig;

      if (modelType == SherpaModelType.moonshine) {
        // Moonshine v2: encoder + mergedDecoder
        modelConfig = sherpa.OfflineModelConfig(
          moonshine: sherpa.OfflineMoonshineModelConfig(
            encoder: encoderPath,
            mergedDecoder: decoderPath,
          ),
          tokens: tokensPath,
          numThreads: numThreads,
          debug: kDebugMode,
        );
      } else {
        // Whisper: encoder + decoder with forced Arabic language
        modelConfig = sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            language: 'ar',
            task: 'transcribe',
          ),
          tokens: tokensPath,
          numThreads: numThreads,
          debug: kDebugMode,
        );
      }

      final recognizerConfig = sherpa.OfflineRecognizerConfig(
        model: modelConfig,
        decodingMethod: 'greedy_search',
      );

      _recognizer = sherpa.OfflineRecognizer(recognizerConfig);
      _initialized = true;

      if (kDebugMode) {
        debugPrint(
          '[SherpaOnnxAsrEngine] Initialized offline $modelType recognizer successfully.',
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

    // Digital AGC: normalize quiet speech (whispers or distance) to optimal dynamic range
    double peakAbs = 0.0;
    for (int i = 0; i < floatSamples.length; i++) {
      final val = floatSamples[i].abs();
      if (val > peakAbs) peakAbs = val;
    }

    // Filter out sub-threshold ambient background noise / micro-clicks before model hallucination
    if (peakAbs < 0.012 && segment.duration < const Duration(milliseconds: 250)) {
      if (kDebugMode) {
        debugPrint(
          '[SherpaOnnxAsrEngine] Skipped sub-threshold noise segment (${segment.duration.inMilliseconds}ms, peakAbs=${peakAbs.toStringAsFixed(4)})',
        );
      }
      return '';
    }

    if (peakAbs > 0.0001 && peakAbs < 0.55) {
      final gain = (0.55 / peakAbs).clamp(1.0, 20.0);
      for (int i = 0; i < floatSamples.length; i++) {
        floatSamples[i] = (floatSamples[i] * gain).clamp(-1.0, 1.0);
      }
      if (kDebugMode) {
        debugPrint(
          '[SherpaOnnxAsrEngine] Digital AGC applied: peakAbs=${peakAbs.toStringAsFixed(4)} -> gain=${gain.toStringAsFixed(2)}x',
        );
      }
    }

    final stream = _recognizer!.createStream();
    try {
      final inputSampleRate = segment.chunks.isNotEmpty
          ? segment.chunks.first.sampleRate
          : 16000;
      stream.acceptWaveform(samples: floatSamples, sampleRate: inputSampleRate);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      final rawText = result.text;

      // Clean speech transcript (preserving Arabic and Latin transliteration, stripping punctuation/digits/loops)
      final cleanText = ArabicNormalizer.cleanTranscript(rawText);

      if (kDebugMode) {
        debugPrint(
          '[SherpaOnnxAsrEngine] Decoded (${segment.duration.inMilliseconds}ms @ ${inputSampleRate}Hz) [$modelType]: '
          'raw="$rawText" -> clean="$cleanText"',
        );
      }

      return cleanText;
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
