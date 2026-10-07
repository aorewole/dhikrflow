import 'dart:async';

import '../events/count_events.dart';
import '../models/dhikr_definition.dart';
import 'recognition_diagnostic.dart';

export 'recognition_diagnostic.dart';

/// Operational states of the speech recognition pipeline.
enum RecognitionState { idle, listening, paused, error }

/// Abstract contract for local speech recognition engines.
///
/// Implementations can be swapped (e.g. Mock for tests/UI prototyping,
/// sherpa-onnx for on-device ASR) without leaking implementation details
/// into the UI or session state machine.
abstract interface class RecognitionEngine {
  /// Stream of accepted domain count events.
  Stream<DhikrCountEvent> get countEvents;

  /// Stream of state changes (idle, listening, paused, error).
  Stream<RecognitionState> get stateStream;

  /// Optional stream of real-time diagnostic and speech transcription events.
  Stream<RecognitionDiagnostic>? get diagnostics;

  /// The current state of the engine.
  RecognitionState get currentState;

  /// The dhikr currently being targeted for recognition.
  DhikrDefinition? get currentTarget;

  /// Start listening for the specified target dhikr phrase.
  Future<void> start(DhikrDefinition target);

  /// Temporarily pause recognition (e.g. when session is paused).
  Future<void> pause();

  /// Resume recognition after pause.
  Future<void> resume();

  /// Stop listening and reset recognition state.
  Future<void> stop();

  /// Release any held resources.
  void dispose();
}
