import 'dart:async';

import 'package:flutter/foundation.dart';

import '../events/count_events.dart';
import '../models/dhikr_definition.dart';
import '../models/dhikr_session.dart';
import '../recognition/recognition_engine.dart';
import '../../data/repositories/session_repository.dart';

/// Central state machine controlling active dhikr sessions.
///
/// Follows strict architecture rules:
/// - Single authority for mutating session count.
/// - Unifies voice count events and manual count events.
/// - Does not terminate session automatically when target is reached.
class SessionController extends ChangeNotifier {
  final RecognitionEngine recognitionEngine;
  final SessionRepository sessionRepository;

  DhikrSession? _currentSession;
  DhikrDefinition? _activeDhikr;
  StreamSubscription<DhikrCountEvent>? _countSubscription;
  StreamSubscription<RecognitionState>? _stateSubscription;
  Timer? _durationTimer;
  DateTime? _lastResumeTime;
  Duration _accumulatedDuration = Duration.zero;

  SessionController({
    required this.recognitionEngine,
    required this.sessionRepository,
  });

  DhikrSession? get currentSession => _currentSession;
  DhikrDefinition? get activeDhikr => _activeDhikr;
  RecognitionState get recognitionState => recognitionEngine.currentState;
  bool get hasActiveSession => _currentSession != null;
  bool get isPaused => _currentSession?.status == SessionStatus.paused;
  bool get isListening =>
      _currentSession?.status == SessionStatus.active &&
      recognitionEngine.currentState == RecognitionState.listening;

  /// Start a new session for the given [dhikr] with an optional [target].
  Future<void> startSession({
    required DhikrDefinition dhikr,
    int? target,
  }) async {
    await endCurrentSessionSilently();

    _activeDhikr = dhikr;
    final now = DateTime.now();
    _currentSession = DhikrSession(
      id: 'session-${now.millisecondsSinceEpoch}',
      dhikrId: dhikr.id,
      startedAt: now,
      target: target,
      status: SessionStatus.active,
    );
    _accumulatedDuration = Duration.zero;
    _lastResumeTime = now;

    _startDurationTimer();

    // Subscribe to count events from recognition engine
    _countSubscription?.cancel();
    _countSubscription = recognitionEngine.countEvents.listen(
      _handleCountEvent,
    );

    // Subscribe to engine state changes
    _stateSubscription?.cancel();
    _stateSubscription = recognitionEngine.stateStream.listen((_) {
      notifyListeners();
    });

    await recognitionEngine.start(dhikr);
    notifyListeners();
  }

  /// Manually increment the counter by 1.
  void incrementManual() {
    if (_currentSession == null ||
        _currentSession!.status != SessionStatus.active) {
      return;
    }
    _handleCountEvent(
      ManualCountEvent(
        phraseId: _currentSession!.dhikrId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Internal handler for all count events (both voice and manual).
  void _handleCountEvent(DhikrCountEvent event) {
    if (_currentSession == null ||
        _currentSession!.status != SessionStatus.active) {
      return;
    }

    // Ensure event corresponds to the active dhikr
    if (event.phraseId != _currentSession!.dhikrId) {
      return;
    }

    final newCount = _currentSession!.count + event.increment;
    _currentSession = _currentSession!.copyWith(
      count: newCount,
      duration: currentDuration,
    );

    notifyListeners();
  }

  /// Pause current session and speech recognition.
  Future<void> pauseSession() async {
    if (_currentSession == null ||
        _currentSession!.status != SessionStatus.active) {
      return;
    }

    _accumulatedDuration = currentDuration;
    _lastResumeTime = null;
    _durationTimer?.cancel();

    _currentSession = _currentSession!.copyWith(
      status: SessionStatus.paused,
      duration: _accumulatedDuration,
    );

    await recognitionEngine.pause();
    notifyListeners();
  }

  /// Resume paused session and speech recognition.
  Future<void> resumeSession() async {
    if (_currentSession == null ||
        _currentSession!.status != SessionStatus.paused) {
      return;
    }

    _lastResumeTime = DateTime.now();
    _startDurationTimer();

    _currentSession = _currentSession!.copyWith(status: SessionStatus.active);

    await recognitionEngine.resume();
    notifyListeners();
  }

  /// Finish the session, record end timestamp, and save to repository.
  Future<DhikrSession?> completeSession() async {
    if (_currentSession == null) return null;

    _durationTimer?.cancel();
    await recognitionEngine.stop();
    _countSubscription?.cancel();
    _stateSubscription?.cancel();

    final completedSession = _currentSession!.copyWith(
      endedAt: DateTime.now(),
      duration: currentDuration,
      status: SessionStatus.completed,
    );

    await sessionRepository.saveSession(completedSession);

    final result = completedSession;
    _currentSession = null;
    _activeDhikr = null;
    _lastResumeTime = null;
    _accumulatedDuration = Duration.zero;

    notifyListeners();
    return result;
  }

  /// End current session without saving (e.g. user aborted or restarted).
  Future<void> endCurrentSessionSilently() async {
    if (_currentSession == null) return;

    _durationTimer?.cancel();
    await recognitionEngine.stop();
    _countSubscription?.cancel();
    _stateSubscription?.cancel();

    _currentSession = null;
    _activeDhikr = null;
    _lastResumeTime = null;
    _accumulatedDuration = Duration.zero;
    notifyListeners();
  }

  Duration get currentDuration {
    if (_lastResumeTime == null) {
      return _accumulatedDuration;
    }
    return _accumulatedDuration + DateTime.now().difference(_lastResumeTime!);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentSession != null &&
          _currentSession!.status == SessionStatus.active) {
        _currentSession = _currentSession!.copyWith(duration: currentDuration);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _countSubscription?.cancel();
    _stateSubscription?.cancel();
    recognitionEngine.dispose();
    super.dispose();
  }
}
