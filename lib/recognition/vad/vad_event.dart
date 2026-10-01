import '../audio/audio_chunk.dart';

/// Instantaneous diagnostic event emitted by the Voice Activity Detector.
class VadStateEvent {
  final bool isSpeech;
  final double energyDbfs;
  final double zcr;
  final DateTime timestamp;

  const VadStateEvent({
    required this.isSpeech,
    required this.energyDbfs,
    required this.zcr,
    required this.timestamp,
  });

  @override
  String toString() =>
      'VadStateEvent(speech: $isSpeech, ${energyDbfs.toStringAsFixed(1)} dBFS, zcr: ${zcr.toStringAsFixed(2)})';
}

/// A contiguous segment of detected speech activity bounded by silence.
class SpeechSegment {
  final List<AudioChunk> chunks;
  final DateTime startTime;
  final DateTime endTime;

  const SpeechSegment({
    required this.chunks,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration => endTime.difference(startTime);

  int get totalBytes =>
      chunks.fold<int>(0, (sum, chunk) => sum + chunk.bytes.length);
}
