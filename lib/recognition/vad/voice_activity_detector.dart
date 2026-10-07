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
  Duration hangoverDuration;

  /// Minimum speech length to reject short transient noise (clicks, taps).
  Duration minSpeechDuration;

  /// Maximum speech length before concluding a segment to prevent unbounded memory growth.
  Duration maxSpeechDuration;

  /// Optional target accumulated duration during continuous speech before
  /// seeking an acoustic energy valley to slice a clean segment without silence.
  Duration? continuousSpeechSliceDuration;

  /// Lookback window in milliseconds to inspect for an energy valley.
  Duration continuousValleySearchWindow;

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
    this.continuousSpeechSliceDuration,
    this.continuousValleySearchWindow = const Duration(milliseconds: 900),
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

      if (_speechStartTime != null) {
        final currentDuration = now.difference(_speechStartTime!);
        if (continuousSpeechSliceDuration != null &&
            currentDuration >= continuousSpeechSliceDuration!) {
          _sliceContinuousSpeechAtValley(now);
        } else if (currentDuration >= maxSpeechDuration) {
          _concludeSpeechSegment(now);
        }
      }
    } else {
      // Energy below threshold: check hangover period
      if (_isSpeaking && _lastSpeechTime != null) {
        final silenceDuration = now.difference(_lastSpeechTime!);
        if (silenceDuration <= hangoverDuration) {
          // Bridge intra-phrase pause: continue buffering
          _currentSegmentChunks.add(chunk);
          if (_speechStartTime != null) {
            final currentDuration = now.difference(_speechStartTime!);
            if (continuousSpeechSliceDuration != null &&
                currentDuration >= continuousSpeechSliceDuration!) {
              _sliceContinuousSpeechAtValley(now);
            } else if (currentDuration >= maxSpeechDuration) {
              _concludeSpeechSegment(now);
            }
          }
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

  /// Slices an ongoing continuous speech buffer at the deepest acoustic energy valley
  /// within the [continuousValleySearchWindow] lookback window.
  ///
  /// Rather than terminating speech recognition or cutting mid-word at an arbitrary timer,
  /// this partitions the accumulated audio at the natural boundary between repetitions,
  /// emits the completed segment to downstream recognizers, and seamlessly carries over
  /// the remaining audio into the next rolling segment while keeping [isSpeaking] true.
  void _sliceContinuousSpeechAtValley(DateTime now) {
    if (_speechStartTime == null || _currentSegmentChunks.isEmpty) return;

    final currentDuration = now.difference(_speechStartTime!);
    final searchWindowStart = now.subtract(continuousValleySearchWindow);

    int bestSplitIndex = -1;
    double lowestRms = double.infinity;

    // Search from chunk 0 up to the second-to-last chunk to guarantee at least
    // one chunk remains for the continuing segment.
    for (int i = 0; i < _currentSegmentChunks.length - 1; i++) {
      final c = _currentSegmentChunks[i];
      if (c.timestamp.isAfter(searchWindowStart) ||
          c.timestamp.isAtSameMomentAs(searchWindowStart)) {
        final rms = c.computeRms();
        if (rms < lowestRms) {
          lowestRms = rms;
          bestSplitIndex = i;
        }
      }
    }

    // If no candidate was found in the search window (e.g. very large chunks),
    // and currentDuration >= maxSpeechDuration, fall back to concluding segment.
    if (bestSplitIndex <= 0) {
      if (currentDuration >= maxSpeechDuration) {
        _concludeSpeechSegment(now);
      }
      return;
    }

    final segmentChunks = _currentSegmentChunks.sublist(0, bestSplitIndex + 1);
    final remainingChunks = _currentSegmentChunks.sublist(bestSplitIndex + 1);

    final segmentStartTime = _speechStartTime!;
    final lastChunk = segmentChunks.last;
    final segmentEndTime = lastChunk.timestamp.add(lastChunk.duration);

    if (segmentEndTime.difference(segmentStartTime) >= minSpeechDuration) {
      _segmentController.add(
        SpeechSegment(
          chunks: List.unmodifiable(segmentChunks),
          startTime: segmentStartTime,
          endTime: segmentEndTime,
        ),
      );
    }

    // Seamless handoff: retain the remaining chunks for the next continuous segment.
    _currentSegmentChunks.clear();
    _currentSegmentChunks.addAll(remainingChunks);
    _speechStartTime =
        remainingChunks.isNotEmpty ? remainingChunks.first.timestamp : now;
    _lastSpeechTime = now;
    _isSpeaking = true;
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
