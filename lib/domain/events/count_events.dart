/// Origin of an accepted repetition count event.
enum CountSource { voice, manual }

/// Domain event representing an accepted recitation repetition.
class DhikrCountEvent {
  final String phraseId;
  final double confidence;
  final DateTime timestamp;
  final CountSource source;
  final int increment;

  const DhikrCountEvent({
    required this.phraseId,
    required this.confidence,
    required this.timestamp,
    required this.source,
    this.increment = 1,
  });

  @override
  String toString() =>
      'DhikrCountEvent($phraseId, +$increment, conf: ${confidence.toStringAsFixed(2)}, $source)';
}

/// Convenience subclass for manual user screen tap counting.
class ManualCountEvent extends DhikrCountEvent {
  ManualCountEvent({
    required super.phraseId,
    DateTime? timestamp,
    super.increment = 1,
  }) : super(
         confidence: 1.0,
         timestamp: timestamp ?? DateTime.now(),
         source: CountSource.manual,
       );
}
