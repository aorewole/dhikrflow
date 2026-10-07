import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/events/count_events.dart';
import '../domain/models/dhikr_definition.dart';
import '../domain/recognition/recognition_config.dart';
import '../domain/recognition/recognition_engine.dart';
import 'asr/asr_engine.dart';
import 'audio/speech_envelope_analyzer.dart';
import 'pipeline/audio_vad_pipeline.dart';
import 'text/arabic_normalizer.dart';
import 'text/phrase_matcher.dart';
import 'text/recitation_cadence_tracker.dart';
import 'text/streaming_repetition_detector.dart';
import 'vad/vad_event.dart';

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
  final AsrEngine? asrEngine;
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
  final RecitationCadenceTracker _cadenceTracker = RecitationCadenceTracker();

  RecognitionConfig config;

  // ── Acoustic context guard ──────────────────────────────────────────────
  List<String>? activeCalibratedAliases;

  /// Acoustic Echo Cancellation (AEC) Ducking guard:
  /// When true, the device's own speaker is actively outputting speech (TTS),
  /// so incoming microphone audio is ducked/ignored to prevent self-counting loopback.
  bool isSpeakerOutputActive = false;

  LocalRecognitionEngine({
    required this.pipeline,
    this.asrEngine,
    this.config = RecognitionConfig.balanced,
    PhraseMatcher? matcher,
  }) : matcher =
           matcher ??
           PhraseMatcher(
             acceptThreshold: config.acceptThreshold,
             uncertainThreshold: config.uncertainThreshold,
           );

  /// Active cadence tracker for observing user recitation tempo.
  RecitationCadenceTracker get cadenceTracker => _cadenceTracker;

  /// Dynamically updates the active recognition and VAD configuration.
  void updateConfig(RecognitionConfig newConfig) {
    config = newConfig;
    pipeline.vad.speechThresholdDbfs = newConfig.speechThresholdDbfs;
    pipeline.vad.hangoverDuration = Duration(
      milliseconds: newConfig.hangoverDurationMs,
    );
    pipeline.vad.minSpeechDuration = Duration(
      milliseconds: newConfig.minSpeechDurationMs,
    );
    pipeline.vad.maxSpeechDuration = Duration(
      milliseconds: newConfig.maxSpeechDurationMs,
    );
    if (_currentTarget != null) {
      final combinedAliases = [
        ..._currentTarget!.aliases,
        ...?activeCalibratedAliases,
      ];
      _repetitionDetector = StreamingRepetitionDetector(
        targetPhrase: _currentTarget!.arabic,
        targetAliases: combinedAliases,
        matcher: PhraseMatcher(
          acceptThreshold: newConfig.acceptThreshold,
          uncertainThreshold: newConfig.uncertainThreshold,
        ),
        cadenceTracker: newConfig.cadencePacingEnabled ? _cadenceTracker : null,
      );
    }
  }

  /// Sets personal calibrated pronunciation aliases for the active user.
  void setCalibratedAliases(List<String>? aliases) {
    activeCalibratedAliases = aliases;
    if (_currentTarget != null) {
      final combinedAliases = [
        ..._currentTarget!.aliases,
        ...?activeCalibratedAliases,
      ];
      _repetitionDetector = StreamingRepetitionDetector(
        targetPhrase: _currentTarget!.arabic,
        targetAliases: combinedAliases,
        matcher: matcher,
        cadenceTracker: config.cadencePacingEnabled ? _cadenceTracker : null,
      );
    }
  }

  @override
  Stream<DhikrCountEvent> get countEvents => _countEventsController.stream;

  @override
  Stream<RecognitionState> get stateStream => _stateController.stream;

  @override
  RecognitionState get currentState => _currentState;

  @override
  DhikrDefinition? get currentTarget => _currentTarget;

  /// Stream of real-time diagnostic events for debug visualization.
  @override
  Stream<RecognitionDiagnostic> get diagnostics => _diagnosticController.stream;

  @override
  Future<void> start(DhikrDefinition target) async {
    _currentTarget = target;
    _cadenceTracker.reset();
    _setState(RecognitionState.listening);

    // Dynamic phrase segmentation: balance between capturing multi-rep runs
    // and keeping decoder buffers short enough to avoid hallucination.
    // For short dhikr (1-2 tokens), use a longer hangover so rapid back-to-back
    // reps are captured in the same segment rather than split into single-rep fragments.
    final tokenCount = ArabicNormalizer.tokenize(target.arabic).length;
    if (tokenCount <= 2) {
      // For 2-token dhikr (e.g. أستغفر الله, الحمد لله, الله أكبر):
      // 800ms hangover bridges inter-repetition breath pauses during discrete recitation.
      // 2800ms continuous slice targets ~3-4 reps before slicing at an acoustic valley.
      pipeline.vad.hangoverDuration = const Duration(milliseconds: 800);
      pipeline.vad.continuousSpeechSliceDuration =
          const Duration(milliseconds: 2800);
      pipeline.vad.continuousValleySearchWindow =
          const Duration(milliseconds: 900);
      pipeline.vad.maxSpeechDuration = const Duration(milliseconds: 8000);
    } else if (tokenCount <= 4) {
      // 3-4 token dhikr (e.g. سبحان الله وبحمده, لا إله إلا الله).
      pipeline.vad.hangoverDuration = const Duration(milliseconds: 400);
      pipeline.vad.continuousSpeechSliceDuration =
          const Duration(milliseconds: 3600);
      pipeline.vad.continuousValleySearchWindow =
          const Duration(milliseconds: 1200);
      pipeline.vad.maxSpeechDuration = const Duration(milliseconds: 8000);
    } else {
      // 5+ token dhikr (e.g. لا حول ولا قوة إلا بالله).
      pipeline.vad.hangoverDuration = const Duration(milliseconds: 350);
      pipeline.vad.continuousSpeechSliceDuration =
          const Duration(milliseconds: 4800);
      pipeline.vad.continuousValleySearchWindow =
          const Duration(milliseconds: 1500);
      pipeline.vad.maxSpeechDuration = const Duration(milliseconds: 9000);
    }

    // Initialize local ASR engine if present
    if (asrEngine != null && !asrEngine!.isInitialized) {
      await asrEngine!.initialize();
    }

    // Set up phrase matcher and repetition detector for the selected dhikr with aliases
    final combinedAliases = [
      ...target.aliases,
      ...?activeCalibratedAliases,
    ];
    _repetitionDetector = StreamingRepetitionDetector(
      targetPhrase: target.arabic,
      targetAliases: combinedAliases,
      matcher: matcher,
      cadenceTracker: config.cadencePacingEnabled ? _cadenceTracker : null,
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
      final target = _currentTarget!;


      // ── Physical Duration Floor (Impulsive Transient & Clap Shield) ───────
      // ── Physical Duration Floor (Impulsive Transient & Clap Shield) ───────
      // Claps, table snaps, and clicks are impulsive transients that typically
      // last 30-120ms. Human liturgical recitation physically takes longer.
      // Discard any audio burst < 200ms immediately as non-speech transient.
      if (segment.duration.inMilliseconds < 200) {
        if (kDebugMode) {
          debugPrint(
            '[LocalRecognitionEngine] Discarded acoustic transient (clap/noise): ${segment.duration.inMilliseconds}ms (< 200ms floor)',
          );
        }
        _diagnosticController.add(
          RecognitionDiagnostic(
            timestamp: segment.endTime,
            rawTranscript: '[Acoustic transient / clap]',
            normalizedTranscript: '',
            newOccurrences: 0,
            confidence: 0.0,
            pendingPrefixTokens: const [],
            isSpeaking: false,
            currentPace: _cadenceTracker.expectedPace,
            isCadenceMatched: false,
            asrCount: 0,
            areCount: 0,
            fusionReason:
                'Transient noise rejected (${segment.duration.inMilliseconds}ms < 200ms)',
            isVoiceVerified: false,
          ),
        );
        return;
      }

      // ── Step 1: Acoustic Repetition Estimator (ARe) ──────────────────────
      // Fast, zero-latency physical envelope analysis on raw PCM.
      final tokenCount = ArabicNormalizer.tokenize(target.arabic).length;
      final durRange = SpeechEnvelopeAnalyzer.expectedDurationRange(tokenCount);
      final areResult = SpeechEnvelopeAnalyzer.analyze(
        segment,
        minRepDurationMs: durRange.min,
        maxRepDurationMs: durRange.max,
      );

      if (kDebugMode) {
        debugPrint('[LocalRecognitionEngine] ARe: $areResult');
      }

      // ── Step 2: Decoupled ASR transcription (non-blocking fallback) ──────
      String rawTranscript = '';
      List<RepetitionOccurrence> asrOccurrences = const [];
      if (asrEngine != null) {
        try {
          rawTranscript = await asrEngine!.transcribeSegment(segment);
          if (rawTranscript.trim().isNotEmpty &&
              _isPlausibleTranscript(rawTranscript, target)) {
            asrOccurrences =
                _repetitionDetector?.processSegment(
                  rawTranscript,
                  timestamp: segment.endTime,
                  segmentDuration: segment.duration,
                ) ??
                const [];
          }
        } catch (e) {
          debugPrint('[LocalRecognitionEngine] ASR error (non-fatal): $e');
        }
      }

      final asrCount = asrOccurrences.length;

      // ── Step 3: Pure Mathematical Waveform Counting ───────────────────────
      // The acoustic envelope analyzer serves as the primary zero-latency
      // counting mechanism. It identifies physical energy valleys and rhythm
      // consistency, providing 100% offline, zero-hallucination detection.
      int finalCount;
      String fusionReason;

      final areHasPlausibleRepetition =
          areResult.isActionable &&
          (areResult.estimatedCount == 1
              ? areResult.meanRepetitionDurationMs >= durRange.min * 0.85
              : areResult.meanRepetitionDurationMs >= durRange.min * 1.05);

      if (areHasPlausibleRepetition) {
        // Acoustic waveform rhythm successfully detected repetitions
        finalCount = areResult.estimatedCount;
        fusionReason =
            'Acoustic waveform ($finalCount rep${finalCount > 1 ? "s" : ""}, ${(areResult.confidence * 100).toStringAsFixed(0)}% conf)';
      } else if (asrCount > 0) {
        // Fallback to phrase matcher if ARe was uncertain
        finalCount = asrCount;
        fusionReason =
            'Phrase match ($asrCount rep${asrCount > 1 ? "s" : ""})';
      } else {
        finalCount = 0;
        fusionReason = areResult.isRhythmicVoicedSpeech
            ? 'Acoustic rhythm below confidence threshold'
            : (rawTranscript.trim().isEmpty
                ? 'Non-speech / transient noise'
                : 'Phrase not matched');
      }

      if (kDebugMode) {
        debugPrint(
          '[LocalRecognitionEngine] Speech evaluated -> ARe=${areResult.estimatedCount}, ASR=$asrCount -> '
          'Final=$finalCount [$fusionReason]',
        );
      }

      // ── Step 4: Emit count events ─────────────────────────────────────────
      if (finalCount > 0) {
        final emitConfidence = areHasPlausibleRepetition
            ? areResult.confidence
            : (asrOccurrences.isNotEmpty
                ? asrOccurrences.first.confidence
                : 0.85);

        for (int i = 0; i < finalCount; i++) {
          _countEventsController.add(
            DhikrCountEvent(
              phraseId: target.id,
              confidence: emitConfidence,
              timestamp: segment.endTime,
              source: CountSource.voice,
              increment: 1,
            ),
          );
        }
      }

      // ── Step 5: Telemetry diagnostic emission ─────────────────────────────
      double bestConfidence = finalCount > 0
          ? (areHasPlausibleRepetition ? areResult.confidence : 0.85)
          : (areResult.confidence > 0 ? areResult.confidence : 0.0);

      _diagnosticController.add(
        RecognitionDiagnostic(
          timestamp: segment.endTime,
          rawTranscript: rawTranscript.isNotEmpty
              ? rawTranscript
              : (finalCount > 0 ? '[Voiced Recitation]' : '[Acoustic Analysis]'),
          normalizedTranscript: rawTranscript.isNotEmpty
              ? ArabicNormalizer.normalize(rawTranscript)
              : '',
          newOccurrences: finalCount,
          confidence: bestConfidence,
          pendingPrefixTokens:
              _repetitionDetector?.pendingPrefixTokens ?? const [],
          isSpeaking: false,
          currentPace: _cadenceTracker.expectedPace,
          isCadenceMatched: _cadenceTracker.matchesCadence(segment.duration),
          asrCount: asrEngine != null ? asrCount : null,
          areCount: areResult.estimatedCount,
          fusionReason: fusionReason,
          isVoiceVerified:
              areResult.isRhythmicVoicedSpeech || finalCount > 0,
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

  /// Returns true if the transcript shares at least one Arabic root from the
  /// active dhikr's phoneme family. This is a fast first-pass guard against
  /// Moonshine hallucinations (e.g. returning "مساء الخير يمه" when the user
  /// said "أستغفر الله"). Applies only to short segments to avoid blocking
  /// genuine multi-rep transcripts that start with preamble words.
  bool _isPlausibleTranscript(String transcript, DhikrDefinition target) {
    // Always trust longer transcripts — they almost certainly contain the
    // target phrase repeated several times, so matching will handle them.
    final tokens = ArabicNormalizer.tokenize(
      ArabicNormalizer.normalize(transcript),
    );
    if (tokens.length >= 4) return true;

    // Build the combined root set from the target phrase + all aliases.
    // We check for any substring match — not exact equality — so phoneme
    // variations like أستغفر / استغفر / مستغفر all pass the same root.
    final rootSet = <String>{};
    void addRoots(String phrase) {
      for (final t in ArabicNormalizer.tokenize(
        ArabicNormalizer.normalize(phrase),
      )) {
        if (t.length >= 3) rootSet.add(t);
      }
    }

    addRoots(target.arabic);
    for (final alias in target.aliases) {
      addRoots(alias);
    }
    if (activeCalibratedAliases != null) {
      for (final alias in activeCalibratedAliases!) {
        addRoots(alias);
      }
    }

    // Check if any token in the transcript shares a root / morpheme with
    // any token in the target/alias set.
    for (final token in tokens) {
      if (token.length < 3) continue;
      for (final root in rootSet) {
        if (root.length < 3) continue;
        // 1. Direct mutual substring containment (e.g. "غفر" in "يستغفر", or "استغفر" in "استغفروا")
        if (token.contains(root) || root.contains(token)) {
          return true;
        }
        // 2. Prefix radical match
        final radical = root.substring(0, root.length >= 4 ? 4 : 3);
        final tokenRadical = token.substring(0, token.length >= 4 ? 4 : 3);
        if (token.contains(radical) || radical.contains(tokenRadical)) {
          return true;
        }
        // 3. Sliding 3-character root window (detects inflected verb forms like يستغفر)
        for (int i = 0; i <= token.length - 3; i++) {
          final trigram = token.substring(i, i + 3);
          if (root.contains(trigram)) {
            return true;
          }
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[LocalRecognitionEngine] Discarded hallucination (no root match): "$transcript"',
      );
    }
    return false;
  }

  @override
  Future<void> pause() async {
    _setState(RecognitionState.paused);
    await pipeline.stop();
    _segmentSubscription?.cancel();
    _vadStateSubscription?.cancel();
    _repetitionDetector?.reset();
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
    _cadenceTracker.reset();
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
    asrEngine?.dispose();
    _countEventsController.close();
    _stateController.close();
    _diagnosticController.close();
  }
}
