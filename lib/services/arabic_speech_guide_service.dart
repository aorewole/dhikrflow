import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../features/session/widgets/recitation_word_highlighter.dart';
import '../recognition/text/arabic_normalizer.dart';

/// Lightweight, 100% on-device Arabic Speech Guide service.
///
/// Uses native OS speech synthesis (AVSpeechSynthesizer on iOS, Android TTS on Android)
/// with zero cloud network requests, zero telemetry, and minimal CPU footprint.
class ArabicSpeechGuideService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isPlaying = false;
  void Function(bool isPlaying)? onPlayStateChanged;

  bool get isPlaying => _isPlaying;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage('ar');
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isPlaying = true;
        onPlayStateChanged?.call(true);
      });

      _tts.setCompletionHandler(() {
        _isPlaying = false;
        onPlayStateChanged?.call(false);
      });

      _tts.setErrorHandler((dynamic msg) {
        _isPlaying = false;
        onPlayStateChanged?.call(false);
        if (kDebugMode) {
          debugPrint('[ArabicSpeechGuideService] TTS error: $msg');
        }
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArabicSpeechGuideService] Initialization failed: $e');
      }
    }
  }

  /// Speaks the given liturgical Arabic phrase at a speed mapped to [pacingSpeed].
  Future<void> speakDhikr(String arabicPhrase, PacingSpeed pacingSpeed) async {
    if (!_isInitialized) {
      await init();
    }
    try {
      // Map pacing speed to TTS rate (iOS: 0.0 - 1.0, default ~0.5)
      double rate;
      switch (pacingSpeed) {
        case PacingSpeed.slow:
          rate = 0.32;
          break;
        case PacingSpeed.medium:
          rate = 0.46;
          break;
        case PacingSpeed.fast:
          rate = 0.60;
          break;
      }

      await _tts.setSpeechRate(rate);
      // Clean phrase for natural speech synthesis and strictly enforce waqf (sukūn coda)
      // to eliminate unwanted terminal case vowels (e.g. "laha" instead of "lah").
      final clean = ArabicNormalizer.enforceSukunCoda(
        arabicPhrase.replaceAll(RegExp(r'[^\u0600-\u06FF\s]'), ''),
      );
      // Appending a full-stop period forces native TTS (AVSpeechSynthesizer / Android TTS)
      // to apply liturgical Waqf (pausal silence on final vowel, e.g. "lah" instead of "laha").
      final speakable = clean.isNotEmpty ? '$clean.' : arabicPhrase;
      await _tts.speak(speakable);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArabicSpeechGuideService] Speak error: $e');
      }
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      _isPlaying = false;
    } catch (_) {}
  }

  void dispose() {
    _tts.stop();
  }
}
