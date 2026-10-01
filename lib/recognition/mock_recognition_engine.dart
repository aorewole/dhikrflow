import 'dart:async';

import '../domain/events/count_events.dart';
import '../domain/models/dhikr_definition.dart';
import '../domain/recognition/recognition_engine.dart';
import 'pipeline/audio_vad_pipeline.dart';
import 'vad/vad_event.dart';

/// Mock implementation of [RecognitionEngine] for development and UI prototyping.
///
/// Can operate purely synthetically or connect to an [AudioVadPipeline] to react
/// to live local microphone voice activity.
class MockRecognitionEngine implements RecognitionEngine {
  final _countEventsController = StreamController<DhikrCountEvent>.broadcast();
  final _stateController = StreamController<RecognitionState>.broadcast();

  final AudioVadPipeline? pipeline;
  StreamSubscription<SpeechSegment>? _segmentSubscription;

  RecognitionState _currentState = RecognitionState.idle;
  DhikrDefinition? _currentTarget;
  Timer? _autoTimer;
  final bool autoSimulate;
  final Duration simulationInterval;

  MockRecognitionEngine({
    this.pipeline,
    this.autoSimulate = false,
    this.simulationInterval = const Duration(seconds: 4),
  });

  @override
  Stream<DhikrCountEvent> get countEvents => _countEventsController.stream;

  @override
  Stream<RecognitionState> get stateStream => _stateController.stream;

  @override
  RecognitionState get currentState => _currentState;

  @override
  DhikrDefinition? get currentTarget => _currentTarget;

  @override
  Future<void> start(DhikrDefinition target) async {
    _currentTarget = target;
    _setState(RecognitionState.listening);

    if (pipeline != null) {
      await pipeline!.start();
      _segmentSubscription?.cancel();
      _segmentSubscription = pipeline!.speechSegments.listen((segment) {
        if (_currentState == RecognitionState.listening) {
          // In Phase 3, each detected speech segment triggers an accepted count event
          simulateVoiceCount(confidence: 0.95, repetitions: 1);
        }
      });
    }

    if (autoSimulate) {
      _startAutoSimulation();
    }
  }

  @override
  Future<void> pause() async {
    _autoTimer?.cancel();
    await pipeline?.stop();
    _segmentSubscription?.cancel();
    _setState(RecognitionState.paused);
  }

  @override
  Future<void> resume() async {
    _setState(RecognitionState.listening);
    if (pipeline != null) {
      await pipeline!.start();
      _segmentSubscription?.cancel();
      _segmentSubscription = pipeline!.speechSegments.listen((segment) {
        if (_currentState == RecognitionState.listening) {
          simulateVoiceCount(confidence: 0.95, repetitions: 1);
        }
      });
    }
    if (autoSimulate) {
      _startAutoSimulation();
    }
  }

  @override
  Future<void> stop() async {
    _autoTimer?.cancel();
    await pipeline?.stop();
    _segmentSubscription?.cancel();
    _currentTarget = null;
    _setState(RecognitionState.idle);
  }

  /// Programmatically simulate voice detection of the target phrase.
  void simulateVoiceCount({double confidence = 0.95, int repetitions = 1}) {
    if (_currentState != RecognitionState.listening || _currentTarget == null) {
      return;
    }

    for (int i = 0; i < repetitions; i++) {
      _countEventsController.add(
        DhikrCountEvent(
          phraseId: _currentTarget!.id,
          confidence: confidence,
          timestamp: DateTime.now(),
          source: CountSource.voice,
          increment: 1,
        ),
      );
    }
  }

  void _setState(RecognitionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void _startAutoSimulation() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(simulationInterval, (_) {
      if (_currentState == RecognitionState.listening) {
        simulateVoiceCount(confidence: 0.92);
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _segmentSubscription?.cancel();
    pipeline?.dispose();
    _countEventsController.close();
    _stateController.close();
  }
}
