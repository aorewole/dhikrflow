import 'dart:async';

import '../audio/audio_chunk.dart';
import 'vad_event.dart';

/// Configurable, adaptive Voice Activity Detector (VAD) designed for on-device processing.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` Section 4:
/// - Reduces downstream ASR load during silence.
/// - Recovers from short intra-phrase micro-pauses via hangover buffering.
/// - Adaptively tracks room ambient noise floor without persisting audio.
class VoiceActivityDetector {
  /// Base threshold in dBFS above which a frame is classified as voice.
  double speechThresholdDbfs;

  /// Time to bridge intra-phrase silence (e.g. Arabic glottal stops and consonants).
  final Duration hangoverDuration;

  /// Minimum speech length to reject short transient noise (clicks, taps).
  final Duration minSpeechDuration;

  /// Maximum speech length before concluding a segment to prevent unbounded memory growth.
  final Duration maxSpeechDuration;

  /// Whether to adapt the threshold dynamically relative to background ambient noise.
  final bool adaptiveNoiseTracking;

  final StreamController<VadStateEvent> _stateController =
      StreamController<VadStateEvent>.broadcast();
  final StreamController<SpeechSegment> _segmentController =
      StreamController<SpeechSegment>.broadcast();

  bool _isSpeaking = false;
  DateTime? _speechStartTime;
  DateTime? _lastSpeechTime;
  double _noiseFloorDbfs = -60.0;
  final List<AudioChunk> _currentSegmentChunks = [];

  VoiceActivityDetector({
    this.speechThresholdDbfs = -48.0,
    this.hangoverDuration = const Duration(milliseconds: 280),
    this.minSpeechDuration = const Duration(milliseconds: 80),
    this.maxSpeechDuration = const Duration(seconds: 7),
    this.adaptiveNoiseTracking = true,
  });

  Stream<VadStateEvent> get stateEvents => _stateController.stream;
  Stream<SpeechSegment> get completedSegments => _segmentController.stream;

  bool get isSpeaking => _isSpeaking;
  double get noiseFloorDbfs => _noiseFloorDbfs;

  /// Ingests a new audio chunk into the VAD state machine.
  void processChunk(AudioChunk chunk) {
    final frameDbfs = chunk.computeDbfs();
    final zcr = chunk.computeZeroCrossingRate();
    final now = chunk.timestamp;

    // Effective threshold accounts for adaptive noise tracking
    final effectiveThreshold = adaptiveNoiseTracking
        ? (_noiseFloorDbfs + 12.0).clamp(speechThresholdDbfs, -15.0)
        : speechThresholdDbfs;

    final frameIsSpeech = frameDbfs >= effectiveThreshold;

    if (frameIsSpeech) {
      _lastSpeechTime = now;
      if (!_isSpeaking) {
        _isSpeaking = true;
        _speechStartTime = now;
        _currentSegmentChunks.clear();
      }
      _currentSegmentChunks.add(chunk);

      // Phase 11 Optimization: Limit segment duration to avoid unbounded memory accumulation
      if (_speechStartTime != null &&
          now.difference(_speechStartTime!) >= maxSpeechDuration) {
        _concludeSpeechSegment(now);
      }
    } else {
      // Energy below threshold: check hangover period
      if (_isSpeaking && _lastSpeechTime != null) {
        final silenceDuration = now.difference(_lastSpeechTime!);
        if (silenceDuration <= hangoverDuration) {
          // Bridge intra-phrase pause: continue buffering
          _currentSegmentChunks.add(chunk);
        } else {
          // Hangover expired: finalize speech segment
          _concludeSpeechSegment(now);
        }
      } else {
        // Continuous silence: adaptively track noise floor
        if (adaptiveNoiseTracking && frameDbfs > -90.0) {
          _noiseFloorDbfs = (_noiseFloorDbfs * 0.95) + (frameDbfs * 0.05);
        }
      }
    }

    _stateController.add(
      VadStateEvent(
        isSpeech: _isSpeaking,
        energyDbfs: frameDbfs,
        zcr: zcr,
        timestamp: now,
      ),
    );
  }

  void _concludeSpeechSegment(DateTime now) {
    if (_speechStartTime != null && _currentSegmentChunks.isNotEmpty) {
      final lastSpeech = _lastSpeechTime ?? _speechStartTime!;
      final lastSpeechChunkDuration = _currentSegmentChunks
          .firstWhere(
            (c) => c.timestamp == lastSpeech,
            orElse: () => _currentSegmentChunks.last,
          )
          .duration;

      final actualSpeechDuration =
          lastSpeech.difference(_speechStartTime!) + lastSpeechChunkDuration;

      if (actualSpeechDuration >= minSpeechDuration) {
        _segmentController.add(
          SpeechSegment(
            chunks: List.unmodifiable(_currentSegmentChunks),
            startTime: _speechStartTime!,
            endTime: lastSpeech.add(lastSpeechChunkDuration),
          ),
        );
      }
    }

    _isSpeaking = false;
    _speechStartTime = null;
    _lastSpeechTime = null;
    _currentSegmentChunks.clear();
  }

  /// Flushes any open speech segment and resets VAD state.
  void reset() {
    _concludeSpeechSegment(DateTime.now());
    _isSpeaking = false;
    _speechStartTime = null;
    _lastSpeechTime = null;
    _currentSegmentChunks.clear();
  }

  void dispose() {
    reset();
    _stateController.close();
    _segmentController.close();
  }
}
