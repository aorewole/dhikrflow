import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/events/count_events.dart';
import '../domain/models/dhikr_definition.dart';
import '../domain/recognition/recognition_engine.dart';
import 'asr/asr_engine.dart';
import 'pipeline/audio_vad_pipeline.dart';
import 'text/phrase_matcher.dart';
import 'text/streaming_repetition_detector.dart';
import 'vad/vad_event.dart';

/// Diagnostic recognition event for developer tools and active session visualizer.
class RecognitionDiagnostic {
  final DateTime timestamp;
  final String? rawTranscript;
  final String? normalizedTranscript;
  final int newOccurrences;
  final double? energyDbfs;
  final bool isSpeaking;

  const RecognitionDiagnostic({
    required this.timestamp,
    this.rawTranscript,
    this.normalizedTranscript,
    this.newOccurrences = 0,
    this.energyDbfs,
    this.isSpeaking = false,
  });
}

/// Production implementation of [RecognitionEngine] combining local Audio/VAD,
/// on-device ASR, Arabic normalization, phrase matching, and streaming repetition detection.
///
/// Follows specifications in `docs/MASTER_SPEC.md`, `docs/RECOGNITION_SPEC.md`, and
/// `docs/BUILD_ROADMAP.md` Phase 4, 5, 6:
/// - 100% on-device processing.
/// - Zero raw audio persisted.
/// - Isolates all speech recognition mechanics behind [RecognitionEngine].
/// - Emits domain [DhikrCountEvent]s consumed directly by SessionController.
class LocalRecognitionEngine implements RecognitionEngine {
  final AudioVadPipeline pipeline;
  final AsrEngine asrEngine;
  final PhraseMatcher matcher;

  final StreamController<DhikrCountEvent> _countEventsController =
      StreamController<DhikrCountEvent>.broadcast();
  final StreamController<RecognitionState> _stateController =
      StreamController<RecognitionState>.broadcast();
  final StreamController<RecognitionDiagnostic> _diagnosticController =
      StreamController<RecognitionDiagnostic>.broadcast();

  StreamSubscription<SpeechSegment>? _segmentSubscription;
  StreamSubscription<VadStateEvent>? _vadStateSubscription;

  RecognitionState _currentState = RecognitionState.idle;
  DhikrDefinition? _currentTarget;
  StreamingRepetitionDetector? _repetitionDetector;

  LocalRecognitionEngine({
    required this.pipeline,
    required this.asrEngine,
    PhraseMatcher? matcher,
  }) : matcher = matcher ?? const PhraseMatcher();

  @override
  Stream<DhikrCountEvent> get countEvents => _countEventsController.stream;

  @override
  Stream<RecognitionState> get stateStream => _stateController.stream;

  @override
  RecognitionState get currentState => _currentState;

  @override
  DhikrDefinition? get currentTarget => _currentTarget;

  /// Stream of real-time diagnostic events for debug visualization.
  Stream<RecognitionDiagnostic> get diagnostics => _diagnosticController.stream;

  @override
  Future<void> start(DhikrDefinition target) async {
    _currentTarget = target;
    _setState(RecognitionState.listening);

    // Initialize local ASR engine
    if (!asrEngine.isInitialized) {
      await asrEngine.initialize();
    }

    // Set up phrase matcher and repetition detector for the selected dhikr
    _repetitionDetector = StreamingRepetitionDetector(
      targetPhrase: target.arabic,
      matcher: matcher,
    );

    // Listen to real-time VAD energy for diagnostics
    _vadStateSubscription?.cancel();
    _vadStateSubscription = pipeline.vadStateEvents.listen((vadEvent) {
      _diagnosticController.add(
        RecognitionDiagnostic(
          timestamp: vadEvent.timestamp,
          energyDbfs: vadEvent.energyDbfs,
          isSpeaking: vadEvent.isSpeech,
        ),
      );
    });

    // Listen to concluded speech segments from VAD
    _segmentSubscription?.cancel();
    _segmentSubscription = pipeline.speechSegments.listen(_handleSpeechSegment);

    // Start audio capture & VAD pipeline
    await pipeline.start();
  }

  Future<void> _handleSpeechSegment(SpeechSegment segment) async {
    if (_currentState != RecognitionState.listening || _currentTarget == null) {
      return;
    }

    try {
      // 1. Transcribe speech segment locally
      final rawTranscript = await asrEngine.transcribeSegment(segment);
      if (rawTranscript.trim().isEmpty) return;

      // 2. Process through repetition detector & phrase matcher
      final occurrences =
          _repetitionDetector?.processTranscript(
            rawTranscript,
            timestamp: segment.endTime,
          ) ??
          const [];

      if (kDebugMode) {
        debugPrint(
          '[LocalRecognitionEngine] Transcribed: "$rawTranscript" -> '
          '${occurrences.length} new occurrences found',
        );
      }

      // 3. Emit count events for each newly accepted repetition
      for (final occ in occurrences) {
        _countEventsController.add(
          DhikrCountEvent(
            phraseId: _currentTarget!.id,
            confidence: occ.confidence,
            timestamp: occ.timestamp,
            source: CountSource.voice,
            increment: 1,
          ),
        );
      }

      // 4. Emit diagnostic update
      _diagnosticController.add(
        RecognitionDiagnostic(
          timestamp: segment.endTime,
          rawTranscript: rawTranscript,
          newOccurrences: occurrences.length,
          isSpeaking: false,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[LocalRecognitionEngine] Error processing segment: $e\n$st',
        );
      }
    }
  }

  @override
  Future<void> pause() async {
    _setState(RecognitionState.paused);
    await pipeline.stop();
    _segmentSubscription?.cancel();
    _vadStateSubscription?.cancel();
  }

  @override
  Future<void> resume() async {
    if (_currentTarget == null) return;
    _setState(RecognitionState.listening);

    _vadStateSubscription?.cancel();
    _vadStateSubscription = pipeline.vadStateEvents.listen((vadEvent) {
      _diagnosticController.add(
        RecognitionDiagnostic(
          timestamp: vadEvent.timestamp,
          energyDbfs: vadEvent.energyDbfs,
          isSpeaking: vadEvent.isSpeech,
        ),
      );
    });

    _segmentSubscription?.cancel();
    _segmentSubscription = pipeline.speechSegments.listen(_handleSpeechSegment);

    await pipeline.start();
  }

  @override
  Future<void> stop() async {
    _setState(RecognitionState.idle);
    await pipeline.stop();
    _segmentSubscription?.cancel();
    _vadStateSubscription?.cancel();
    _repetitionDetector?.reset();
    _repetitionDetector = null;
    _currentTarget = null;
  }

  void _setState(RecognitionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  void dispose() {
    stop();
    pipeline.dispose();
    asrEngine.dispose();
    _countEventsController.close();
    _stateController.close();
    _diagnosticController.close();
  }
}
