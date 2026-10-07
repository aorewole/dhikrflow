import 'dart:math' as math;
import 'dart:typed_data';

import '../vad/vad_event.dart';

/// The result of an acoustic repetition analysis on a speech segment.
///
/// Produced by [SpeechEnvelopeAnalyzer.analyze] without any ASR involvement.
/// Used as an independent signal to cross-validate or supplement ASR counts.
class EnvelopeAnalysisResult {
  /// Estimated number of dhikr repetitions from energy valley detection.
  final int estimatedCount;

  /// Composite confidence in the estimate (0.0 – 1.0).
  final double confidence;

  /// True when the segment shows a rhythmically consistent voiced speech
  /// pattern — i.e. it is unlikely to be a clap, noise burst, or conversation.
  final bool isRhythmicVoicedSpeech;

  /// Mean duration of individual repetitions in milliseconds.
  final double meanRepetitionDurationMs;

  /// Raw number of valleys detected before gating.
  final int rawValleyCount;

  /// Valleys that passed all gates and contributed to [estimatedCount].
  final int acceptedValleyCount;

  const EnvelopeAnalysisResult({
    required this.estimatedCount,
    required this.confidence,
    required this.isRhythmicVoicedSpeech,
    required this.meanRepetitionDurationMs,
    required this.rawValleyCount,
    required this.acceptedValleyCount,
  });

  /// True when this result is confident enough to act on independently
  /// (i.e. when ASR returned zero or hallucinated).
  bool get isActionable {
    if (estimatedCount == 1) {
      return confidence >= 0.60 &&
          isRhythmicVoicedSpeech &&
          meanRepetitionDurationMs >= 350;
    }
    return confidence >= 0.70 &&
        isRhythmicVoicedSpeech &&
        estimatedCount >= 1 &&
        meanRepetitionDurationMs >= 400;
  }

  static const EnvelopeAnalysisResult empty = EnvelopeAnalysisResult(
    estimatedCount: 0,
    confidence: 0.0,
    isRhythmicVoicedSpeech: false,
    meanRepetitionDurationMs: 0.0,
    rawValleyCount: 0,
    acceptedValleyCount: 0,
  );

  @override
  String toString() =>
      'EnvelopeAnalysisResult(count=$estimatedCount, conf=${confidence.toStringAsFixed(2)}, '
      'rhythmic=$isRhythmicVoicedSpeech, meanRep=${meanRepetitionDurationMs.toStringAsFixed(0)}ms, '
      'valleys=$acceptedValleyCount/$rawValleyCount)';
}

/// Information about a single detected energy valley (word boundary) in the
/// amplitude envelope.
class _Valley {
  /// Frame index of the minimum energy point of the valley.
  final int centreFrame;

  /// Lowest RMS value at the valley minimum.
  final double minEnergy;

  /// Peak energy in the speech region before the valley.
  final double peakBefore;

  /// Peak energy in the speech region after the valley.
  final double peakAfter;

  /// Width of the valley in frames, measured as the span of frames that fall
  /// below [_lowEnergyThreshold] × surrounding peak.
  final int lowEnergyWidthFrames;

  const _Valley({
    required this.centreFrame,
    required this.minEnergy,
    required this.peakBefore,
    required this.peakAfter,
    required this.lowEnergyWidthFrames,
  });

  /// Fraction by which the valley floor drops below the lower surrounding peak.
  double get depthFraction {
    final ref = math.min(peakBefore, peakAfter);
    if (ref <= 0.0) return 0.0;
    return (ref - minEnergy) / ref;
  }
}

/// Analyses the amplitude envelope of a completed [SpeechSegment] to
/// estimate how many times a dhikr phrase was repeated, based on energy
/// valley detection — without any ASR.
///
/// ## Algorithm
///
/// 1. Extract all PCM16 samples and compute RMS energy in 10 ms frames.
/// 2. Apply a sliding-window max-pooling (30 ms window) to compute a smooth
///    "energy envelope" that captures word-level amplitude peaks.
/// 3. Find local minima (valleys) in the smoothed envelope where energy drops
///    substantially between two speech regions.
/// 4. Gate each valley:
///    - **Depth gate** ≥ 28 %: valley floor drops ≥ 28 % below surrounding peaks.
///    - **Width gate** ≤ 40 frames (400 ms): valley cannot be wider than a breath.
///    - **Recovery gate**: energy must rise back ≥ 50 % of peakAfter within
///      250 ms — rules out ambient silence / breath that never recovers.
///    - **IOI plausibility gate**: the implied repetition period must be
///      within 50 %–200 % of [minRepDurationMs, maxRepDurationMs].
/// 5. Check IOI rhythm consistency across accepted valleys.
/// 6. Compute composite confidence.
///
/// ## Noise immunity
///
/// - **Claps / snaps**: very short transient, no sustained energy → fail recovery gate.
/// - **Conversation**: irregular IOI, wrong repetition duration → fail IOI gate.
/// - **Silence**: global peak < threshold → return empty.
class SpeechEnvelopeAnalyzer {
  static const int _frameSizeMs = 10;

  // Max-pool window for envelope smoothing (in frames).
  // 5 frames = 50 ms — captures the overall word-level amplitude shape
  // without being fooled by rapid intra-word oscillations.
  static const int _smoothWindowFrames = 5;

  // Valley depth: valley floor must be this far below the surrounding peaks.
  static const double _minValleyDepth = 0.28;

  // Maximum width of the "low energy zone" inside a valley (in frames).
  // A valley wider than this is a breath pause, not a word boundary.
  static const int _maxValleyWidthFrames = 40; // 400 ms

  // Minimum width of the low-energy zone (ensures it is not a micro-dip).
  static const int _minValleyWidthFrames = 1; // 10 ms

  // Fraction of surrounding peak used to define the "low energy zone" boundary.
  static const double _lowEnergyThreshold = 0.35;

  // After the valley minimum, energy must reach this fraction of peakAfter
  // within _recoveryWindowFrames to confirm voiced speech follows.
  static const double _minRecoveryFraction = 0.50;
  static const int _recoveryWindowFrames = 25; // 250 ms

  // Maximum IOI coefficient of variation (stddev/mean) for "rhythmic" speech.
  static const double _maxIoiCv = 0.45;

  // Minimum global peak below which the segment is silence.
  static const double _minGlobalPeak = 0.008;

  /// Analyses [segment] and returns an [EnvelopeAnalysisResult].
  ///
  /// [minRepDurationMs] and [maxRepDurationMs] define the expected duration
  /// range for a single repetition of the target dhikr.
  static EnvelopeAnalysisResult analyze(
    SpeechSegment segment, {
    required int minRepDurationMs,
    required int maxRepDurationMs,
  }) {
    if (segment.chunks.isEmpty) return EnvelopeAnalysisResult.empty;

    final sampleRate = segment.chunks.first.sampleRate;
    final frameSizeSamples = (sampleRate * _frameSizeMs / 1000).round();
    if (frameSizeSamples <= 0) return EnvelopeAnalysisResult.empty;

    // ── 1. Flatten all PCM samples ──────────────────────────────────────────
    final totalSamples = segment.chunks.fold<int>(
      0,
      (s, c) => s + c.pcm16Samples.length,
    );
    if (totalSamples < frameSizeSamples * 4) return EnvelopeAnalysisResult.empty;

    final flat = Float32List(totalSamples);
    int writeIdx = 0;
    for (final chunk in segment.chunks) {
      final pcm = chunk.pcm16Samples;
      for (int i = 0; i < pcm.length; i++) {
        flat[writeIdx++] = pcm[i] / 32768.0;
      }
    }

    // ── 2. RMS per frame ────────────────────────────────────────────────────
    final frameCount = totalSamples ~/ frameSizeSamples;
    final rms = Float32List(frameCount);
    for (int f = 0; f < frameCount; f++) {
      double sumSq = 0.0;
      final start = f * frameSizeSamples;
      for (int i = start; i < start + frameSizeSamples; i++) {
        sumSq += flat[i] * flat[i];
      }
      rms[f] = math.sqrt(sumSq / frameSizeSamples);
    }

    // ── 3. Max-pool envelope smoothing ──────────────────────────────────────
    // Max-pooling captures the peak amplitude in each neighbourhood window,
    // which gives a clean word-level energy envelope without the rapid
    // oscillations caused by individual speech waveform cycles.
    final envelope = Float32List(frameCount);
    for (int f = 0; f < frameCount; f++) {
      double peak = 0.0;
      final lo = math.max(0, f - _smoothWindowFrames);
      final hi = math.min(frameCount - 1, f + _smoothWindowFrames);
      for (int i = lo; i <= hi; i++) {
        if (rms[i] > peak) peak = rms[i];
      }
      envelope[f] = peak;
    }

    final globalPeak = envelope.reduce(math.max);
    if (globalPeak < _minGlobalPeak) return EnvelopeAnalysisResult.empty;

    // ── 4. Valley detection ─────────────────────────────────────────────────
    // A valley is a region where the envelope drops substantially below
    // the peaks on both sides.  We scan the envelope and identify each
    // contiguous block of frames that fall below _lowEnergyThreshold ×
    // their surrounding peaks.
    final rawValleys = _detectValleys(envelope, frameCount);

    // ── 5. Gate each valley ─────────────────────────────────────────────────
    final accepted = _gateValleys(
      rawValleys,
      envelope,
      frameCount: frameCount,
      minRepDurationMs: minRepDurationMs,
      maxRepDurationMs: maxRepDurationMs,
    );

    final totalSegMs = segment.duration.inMilliseconds;

    // Safety guard against intra-phrase pauses in long phrases:
    // If the detected valleys would force mean repetition duration below 80% of minRepDurationMs,
    // the valley was an internal phrasing breath (e.g. between "Astaghfirullah" and "wa atubu ilayh"),
    // not a true multi-repetition boundary.
    if (accepted.isNotEmpty &&
        (totalSegMs / (accepted.length + 1)) < (minRepDurationMs * 0.80)) {
      accepted.clear();
    }

    if (accepted.isEmpty) {
      // Single uninterrupted repetition check.
      // Must be within expected duration bounds and have sustained voiced energy.
      if (totalSegMs >= (minRepDurationMs * 0.60).round() &&
          totalSegMs <= (maxRepDurationMs * 1.5).round()) {
        // Active speech duty cycle check:
        // A genuine continuous dhikr repetition maintains speech energy across
        // at least 45% of the segment. Isolated transients (claps, taps, clicks)
        // are mostly silence and fail this check.
        int activeFrames = 0;
        final activeThreshold = _minGlobalPeak * 2;
        for (int i = 0; i < frameCount; i++) {
          if (envelope[i] >= activeThreshold) activeFrames++;
        }
        final dutyCycle = activeFrames / frameCount;
        if (dutyCycle < 0.45) {
          return EnvelopeAnalysisResult.empty;
        }

        final zcr = _meanZcrHz(flat, sampleRate);
        final voiced = _voicedLikelihood(zcr, globalPeak);
        final isVoiced = voiced >= 0.55;
        return EnvelopeAnalysisResult(
          estimatedCount: isVoiced ? 1 : 0,
          confidence: isVoiced ? (voiced * 0.85).clamp(0.0, 1.0) : 0.0,
          isRhythmicVoicedSpeech: isVoiced,
          meanRepetitionDurationMs: totalSegMs.toDouble(),
          rawValleyCount: rawValleys.length,
          acceptedValleyCount: 0,
        );
      }
      return EnvelopeAnalysisResult.empty;
    }

    // ── 6. IOI rhythm consistency ───────────────────────────────────────────
    final repCount = accepted.length + 1;
    final ioiCv = _ioiCv(accepted, _frameSizeMs);
    final isRhythmic = ioiCv <= _maxIoiCv;

    // ── 7. Per-rep duration fit ─────────────────────────────────────────────
    final meanRepMs = totalSegMs / repCount;
    final durFit = _durationFit(meanRepMs, minRepDurationMs, maxRepDurationMs);

    // ── 8. ZCR voiced speech likelihood ────────────────────────────────────
    final zcr = _meanZcrHz(flat, sampleRate);
    final voiced = _voicedLikelihood(zcr, globalPeak);

    // ── 9. Valley depth quality ─────────────────────────────────────────────
    final meanDepth = accepted.fold<double>(0.0, (s, v) => s + v.depthFraction) /
        accepted.length;
    final depthScore = (meanDepth / 0.60).clamp(0.0, 1.0);

    // ── 10. Composite confidence ────────────────────────────────────────────
    final rhythmScore = isRhythmic
        ? (1.0 - ioiCv / _maxIoiCv).clamp(0.0, 1.0)
        : 0.0;

    // Weight: depth 35 %, rhythm 35 %, duration fit 20 %, voiced 10 %
    final confidence = (depthScore * 0.35 +
            rhythmScore * 0.35 +
            durFit * 0.20 +
            voiced * 0.10)
        .clamp(0.0, 1.0);

    return EnvelopeAnalysisResult(
      estimatedCount: repCount,
      confidence: confidence,
      isRhythmicVoicedSpeech: isRhythmic && voiced > 0.40,
      meanRepetitionDurationMs: meanRepMs,
      rawValleyCount: rawValleys.length,
      acceptedValleyCount: accepted.length,
    );
  }

  /// Returns the expected single-repetition duration range (min, max) in ms
  /// based on the selected dhikr, its text length, or the number of Arabic tokens.
  static ({int min, int max}) expectedDurationRange(
    int tokenCount, {
    String? dhikrId,
    String? arabicText,
  }) {
    // 1. Explicit per-dhikr calibration for standard library litanies
    if (dhikrId != null) {
      switch (dhikrId) {
        case 'astaghfirullah':
        case 'subhanallah':
        case 'alhamdulillah':
        case 'allahu_akbar':
          return (min: 650, max: 1500);

        case 'subhanallahi_wa_bihamdihi':
        case 'subhanallahil_azeem':
        case 'subhana_rabbiyal_ala':
        case 'subhana_rabbiyal_azeem':
          return (min: 1200, max: 2400);

        case 'la_ilaha_illallah':
          return (min: 1400, max: 2800);

        case 'astaghfirullah_wa_atubu_ilayh':
          // "Astaghfirullah wa atubu ilayh": 11-12 syllables.
          // Single repetition takes ~1.9s - 3.2s.
          // Floor of 1900ms strictly prevents intra-phrase valleys from double-counting.
          return (min: 1900, max: 3800);

        case 'rabbighfir_li_wa_tub_alayya':
          return (min: 2400, max: 4800);

        case 'la_hawla':
        case 'hasbunallahu_wa_nimal_wakeel':
        case 'ya_hayyu_ya_qayyum':
        case 'audhu_bikalimatillah':
        case 'bismillahi_tawakkaltu':
        case 'allahumma_salli_ala_muhammad':
        case 'allahumma_salli_wa_sallim':
          return (min: 2200, max: 4500);

        case 'la_ilaha_illallah_wahdahu':
        case 'tahlil_tamam':
        case 'raditu_billah':
        case 'hasbiyallahu_la_ilaha':
        case 'subhanallahi_adada_khalqihi':
        case 'salawat_ibrahimiyyah_short':
          return (min: 3500, max: 8000);

        case 'bismillahilladhi':
        case 'sayyid_al_istighfar':
        case 'yunus_dhikr':
          return (min: 5000, max: 15000);
      }
    }

    // 2. Text-aware heuristic if arabicText is available
    if (arabicText != null) {
      if (arabicText.contains('أتوب') || arabicText.contains('اتوب')) {
        return (min: 1900, max: 3800);
      }
      final cleanText = arabicText.replaceAll(RegExp(r'\s+'), '');
      if (cleanText.length >= 15) {
        final minMs = (cleanText.length * 115).clamp(1800, 14000);
        final maxMs = (cleanText.length * 260).clamp(3500, 30000);
        return (min: minMs, max: maxMs);
      }
    }

    // 3. Fallback token-count based ranges
    switch (tokenCount) {
      case 1:
        return (min: 250, max: 900);
      case 2:
        // أستغفر الله, الحمد لله, سبحان الله, الله أكبر
        return (min: 650, max: 1500);
      case 3:
        // سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ
        return (min: 1100, max: 2200);
      case 4:
        // لا إله إلا الله
        return (min: 1400, max: 2800);
      case 5:
        // أَسْتَغْفِرُ ٱللّٰهَ وَأَتُوبُ إِلَيْهْ
        return (min: 1900, max: 3800);
      default:
        // Multi-word litanies (6+ tokens): scale proportionally with token count
        final minMs = (tokenCount * 380).round();
        final maxMs = (tokenCount * 950).round();
        return (min: minMs, max: maxMs);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Detects valleys by scanning for contiguous low-energy zones between
  /// two regions of sustained high energy.
  static List<_Valley> _detectValleys(Float32List envelope, int frameCount) {
    final valleys = <_Valley>[];

    int f = 0;
    while (f < frameCount) {
      // Find a high-energy region (start of a speech burst).
      if (envelope[f] < _minGlobalPeak * 4) {
        f++;
        continue;
      }

      // We are in a high-energy region. Find its peak.
      double peakBefore = 0.0;
      while (f < frameCount && envelope[f] > _minGlobalPeak * 2) {
        if (envelope[f] > peakBefore) peakBefore = envelope[f];
        f++;
      }
      if (peakBefore <= 0) continue;

      // We've exited the high-energy region. Check if this is a valley.
      final lowThreshold = peakBefore * _lowEnergyThreshold;
      int valleyStart = f;
      double valleyMin = peakBefore;
      int valleyCentre = f;

      // Walk through the low-energy zone.
      while (f < frameCount && envelope[f] < lowThreshold) {
        if (envelope[f] < valleyMin) {
          valleyMin = envelope[f];
          valleyCentre = f;
        }
        f++;
      }

      final valleyWidthFrames = f - valleyStart;

      // After the valley, check if energy recovers (voiced speech follows).
      if (f >= frameCount) break; // segment ends during valley — no recovery

      // Find the peak AFTER the valley.
      double peakAfter = 0.0;
      final searchEnd = math.min(frameCount, f + 60);
      for (int i = f; i < searchEnd; i++) {
        if (envelope[i] > peakAfter) peakAfter = envelope[i];
      }

      if (peakAfter <= 0) continue;

      // Recovery check.
      final recoveryTarget = peakAfter * _minRecoveryFraction;
      bool recovered = false;
      final recovEnd = math.min(frameCount, valleyCentre + _recoveryWindowFrames);
      for (int i = valleyCentre; i < recovEnd; i++) {
        if (envelope[i] >= recoveryTarget) {
          recovered = true;
          break;
        }
      }
      if (!recovered) continue;

      valleys.add(
        _Valley(
          centreFrame: valleyCentre,
          minEnergy: valleyMin,
          peakBefore: peakBefore,
          peakAfter: peakAfter,
          lowEnergyWidthFrames: valleyWidthFrames,
        ),
      );

      // Continue scanning from the end of the valley.
      // (f is already pointing past the valley.)
    }

    return valleys;
  }

  static List<_Valley> _gateValleys(
    List<_Valley> candidates,
    Float32List envelope, {
    required int frameCount,
    required int minRepDurationMs,
    required int maxRepDurationMs,
  }) {
    final accepted = <_Valley>[];

    for (final v in candidates) {
      // Gate 1: depth
      if (v.depthFraction < _minValleyDepth) continue;

      // Gate 2: valley width
      if (v.lowEnergyWidthFrames > _maxValleyWidthFrames) continue;
      if (v.lowEnergyWidthFrames < _minValleyWidthFrames) continue;

      // Gate 3: IOI plausibility.
      //
      // Both the speech region BEFORE the valley and the speech region AFTER
      // the valley must each be long enough to contain a full repetition of
      // the target dhikr.
      //
      // "أستغفر الله" is ~900-1200ms per rep. If a valley appears at 550ms
      // inside a 1100ms segment, the first half is 550ms and the second half
      // is 550ms — both are above 450ms minimum so they look plausible.
      // But the TOTAL segment of 1100ms / 2 reps = 550ms each, which is
      // barely above 450ms. We use a stricter floor here: each implied rep
      // must be >= minRepDurationMs (not just half of it).
      if (accepted.isEmpty) {
        // First valley: before = centreFrame × frameSizeMs
        final beforeMs = v.centreFrame * _frameSizeMs;
        final afterMs = (frameCount - v.centreFrame) * _frameSizeMs;
        // Both the speech chunk BEFORE and AFTER must be plausible full repetitions:
        // Speech before the first valley must be at least 88% of minRepDurationMs.
        if (beforeMs < (minRepDurationMs * 0.88).round() ||
            afterMs < (minRepDurationMs * 0.70).round()) {
          continue;
        }
      } else {
        // Subsequent valleys: IOI from last accepted valley centre.
        final ioiMs = (v.centreFrame - accepted.last.centreFrame) * _frameSizeMs;
        final afterMs = (frameCount - v.centreFrame) * _frameSizeMs;
        final minIoi = (minRepDurationMs * 0.75).round();
        final maxIoi = maxRepDurationMs * 2;
        if (ioiMs < minIoi || ioiMs > maxIoi || afterMs < (minRepDurationMs * 0.70).round()) {
          continue;
        }
      }

      accepted.add(v);
    }
    return accepted;
  }

  static double _ioiCv(List<_Valley> accepted, int frameSizeMs) {
    if (accepted.length < 2) return 0.0;
    final iois = <double>[];
    for (int i = 1; i < accepted.length; i++) {
      iois.add(
        (accepted[i].centreFrame - accepted[i - 1].centreFrame).toDouble() *
            frameSizeMs,
      );
    }
    final mean = iois.reduce((a, b) => a + b) / iois.length;
    if (mean <= 0) return 1.0;
    final variance = iois
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        iois.length;
    return math.sqrt(variance) / mean;
  }

  static double _meanZcrHz(Float32List samples, int sampleRate) {
    if (samples.length < 2) return 0.0;
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i - 1] >= 0)) crossings++;
    }
    return crossings / (samples.length / sampleRate.toDouble());
  }

  /// 0–1 likelihood that [zcr] and [globalPeak] represent voiced Arabic speech.
  static double _voicedLikelihood(double zcr, double globalPeak) {
    if (globalPeak < _minGlobalPeak * 3) return 0.2;
    // Arabic voiced speech at 16 kHz typically 500–4000 ZCR/sec.
    if (zcr < 200) return 0.3;
    if (zcr <= 4000) return 1.0;
    if (zcr <= 7000) return (1.0 - (zcr - 4000) / 3000.0).clamp(0.2, 0.9);
    return 0.1;
  }

  static double _durationFit(
    double meanRepMs,
    int minMs,
    int maxMs,
  ) {
    if (meanRepMs < minMs * 0.55 || meanRepMs > maxMs * 1.65) return 0.0;
    if (meanRepMs >= minMs && meanRepMs <= maxMs) return 1.0;
    if (meanRepMs < minMs) {
      return ((meanRepMs - minMs * 0.55) / (minMs * 0.45)).clamp(0.0, 1.0);
    }
    return ((maxMs * 1.65 - meanRepMs) / (maxMs * 0.65)).clamp(0.0, 1.0);
  }
}
