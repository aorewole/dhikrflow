/// Tracks the rhythmic pace/cadence of a reciter during a dhikr session.
///
/// Follows specifications in `docs/RECOGNITION_SPEC.md` and Bayesian Cadence Prior:
/// - Human dhikr recitation naturally locks into a rhythmic tempo (cadence).
/// - Once the reciter's tempo is established from confirmed recitations,
///   cadence matching can rescue acoustic near-misses (e.g. minor dialectal slips
///   or fast speech artifacts) without increasing false-positive rates on noise.
class RecitationCadenceTracker {
  /// Maximum number of recent confirmed recitation durations retained.
  final int maxHistory;

  /// Tolerance factor around the expected pace (e.g. 0.35 means +/- 35%).
  final double tolerance;

  final List<Duration> _confirmedDurations = [];

  RecitationCadenceTracker({
    this.maxHistory = 6,
    this.tolerance = 0.35,
  });

  /// Whether the tracker has learned enough samples to establish a cadence baseline.
  bool get hasEstablishedCadence => _confirmedDurations.isNotEmpty;

  /// Number of confirmed duration samples currently recorded.
  int get sampleCount => _confirmedDurations.length;

  /// Returns unmodifiable list of recent confirmed per-repetition durations.
  List<Duration> get confirmedDurations =>
      List.unmodifiable(_confirmedDurations);

  /// Returns the current expected per-repetition recitation duration
  /// calculated as the median of confirmed samples (resistant to outliers).
  Duration? get expectedPace {
    if (_confirmedDurations.isEmpty) return null;

    final sortedMs =
        _confirmedDurations.map((d) => d.inMilliseconds).toList()..sort();
    final mid = sortedMs.length ~/ 2;
    final medianMs =
        sortedMs.length.isOdd
            ? sortedMs[mid]
            : ((sortedMs[mid - 1] + sortedMs[mid]) ~/ 2);

    return Duration(milliseconds: medianMs);
  }

  /// Records the duration of a confirmed recitation event.
  ///
  /// If the segment contained multiple repetitions (e.g. [repetitionCount] = 3),
  /// the per-repetition duration is calculated as `duration / repetitionCount`.
  void recordDuration(Duration duration, {int repetitionCount = 1}) {
    if (repetitionCount <= 0 || duration.inMilliseconds <= 0) return;

    final perRepMs = duration.inMilliseconds ~/ repetitionCount;

    // Filter out extreme physical anomalies (< 250ms or > 12000ms)
    if (perRepMs < 250 || perRepMs > 12000) return;

    _confirmedDurations.add(Duration(milliseconds: perRepMs));
    if (_confirmedDurations.length > maxHistory) {
      _confirmedDurations.removeAt(0);
    }
  }

  /// Checks whether [duration] matches the established cadence.
  ///
  /// By default checks if `duration / repetitionCount` falls within
  /// `[expectedPace * (1 - tolerance), expectedPace * (1 + tolerance)]`.
  ///
  /// If [allowMultiples] is true, checks whether there exists any plausible
  /// integer repetition count $k \in [1, 6]$ that matches the expected cadence.
  bool matchesCadence(
    Duration duration, {
    int repetitionCount = 1,
    bool allowMultiples = false,
  }) {
    final pace = expectedPace;
    if (pace == null) return false;

    final paceMs = pace.inMilliseconds;
    final durMs = duration.inMilliseconds;
    final minPerRepMs = paceMs * (1.0 - tolerance);
    final maxPerRepMs = paceMs * (1.0 + tolerance);

    if (!allowMultiples) {
      if (repetitionCount <= 0) return false;
      final perRepMs = durMs / repetitionCount;
      return perRepMs >= minPerRepMs && perRepMs <= maxPerRepMs;
    }

    // Dynamic search for plausible repetition count k
    for (int k = 1; k <= 6; k++) {
      final perRepMs = durMs / k;
      if (perRepMs >= minPerRepMs && perRepMs <= maxPerRepMs) {
        return true;
      }
    }

    return false;
  }

  /// Computes a normalized cadence similarity score in $[0.0, 1.0]$.
  ///
  /// Returns 1.0 when the actual pace matches the expected pace exactly,
  /// tapering down linearly to 0.0 at the tolerance boundary.
  double calculateCadenceSimilarity(Duration duration, {int repetitionCount = 1}) {
    final pace = expectedPace;
    if (pace == null || repetitionCount <= 0) return 0.0;

    final paceMs = pace.inMilliseconds;
    final actualPerRepMs = duration.inMilliseconds / repetitionCount;
    final diff = (actualPerRepMs - paceMs).abs();
    final maxDiff = paceMs * tolerance;

    if (diff >= maxDiff) return 0.0;
    return (1.0 - (diff / maxDiff)).clamp(0.0, 1.0);
  }

  /// Resets cadence history when switching target dhikr or starting a new session.
  void reset() {
    _confirmedDurations.clear();
  }
}
