import 'dart:math' as math;
import 'dart:typed_data';

/// In-memory representation of an uncompressed PCM audio buffer.
///
/// Designed to satisfy privacy rules:
/// - Exists only in-memory.
/// - Never written to disk or uploaded.
class AudioChunk {
  final Uint8List bytes;
  final int sampleRate;
  final int channels;
  final DateTime timestamp;
  Int16List? _cachedPcm16;

  AudioChunk({
    required this.bytes,
    this.sampleRate = 16000,
    this.channels = 1,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Total number of 16-bit PCM samples per channel in this chunk.
  int get sampleCount => bytes.lengthInBytes ~/ (channels * 2);

  /// The duration of audio contained within this chunk.
  Duration get duration {
    final ms = (sampleCount * 1000) ~/ sampleRate;
    return Duration(milliseconds: ms);
  }

  /// Converts the raw byte buffer to 16-bit signed PCM samples.
  ///
  /// Caches the decoded samples in-memory to prevent duplicate allocations
  /// during VAD energy calculation and downstream ASR transcription.
  Int16List get pcm16Samples {
    if (_cachedPcm16 != null) return _cachedPcm16!;
    final byteData = ByteData.sublistView(bytes);
    final count = bytes.lengthInBytes ~/ 2;
    final samples = Int16List(count);
    for (int i = 0; i < count; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little);
    }
    _cachedPcm16 = samples;
    return samples;
  }

  /// Calculates the Root Mean Square (RMS) energy normalized between 0.0 and 1.0.
  double computeRms() {
    final samples = pcm16Samples;
    if (samples.isEmpty) return 0.0;

    double sumSquares = 0.0;
    for (final sample in samples) {
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Calculates the signal power in decibels relative to full scale (dBFS).
  ///
  /// Typical values range from -100 dBFS (near total silence) to 0 dBFS (peak clipping).
  double computeDbfs() {
    final rms = computeRms();
    if (rms <= 0.000001) return -100.0;
    final dbfs = 20.0 * (math.log(rms) / math.ln10);
    return dbfs.clamp(-100.0, 0.0);
  }

  /// Calculates the Zero Crossing Rate (ZCR), useful for voicing detection.
  double computeZeroCrossingRate() {
    final samples = pcm16Samples;
    if (samples.length < 2) return 0.0;

    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0 && samples[i - 1] < 0) ||
          (samples[i] < 0 && samples[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / (samples.length - 1);
  }
}
