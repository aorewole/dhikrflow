import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/dhikr_definition.dart';
import '../../recognition/asr/sherpa_onnx_asr_engine.dart';
import '../../recognition/calibration/personal_calibration_engine.dart';
import '../../recognition/local_recognition_engine.dart';
import '../../recognition/text/arabic_normalizer.dart';
import '../../recognition/vad/vad_event.dart';

/// Modal dialog allowing users to train the app on their personal pronunciation of a dhikr.
///
/// Follows specifications in `AGENTS.md` and Phase 12:
/// - 100% on-device processing.
/// - Raw audio is discarded immediately; only derived phonetic aliases and timing are saved.
/// - Never transmits data to any network or cloud service.
class VoiceCalibrationDialog extends StatefulWidget {
  final DhikrDefinition dhikr;

  const VoiceCalibrationDialog({super.key, required this.dhikr});

  static Future<bool?> show(BuildContext context, DhikrDefinition dhikr) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceCalibrationDialog(dhikr: dhikr),
    );
  }

  @override
  State<VoiceCalibrationDialog> createState() => _VoiceCalibrationDialogState();
}

class _VoiceCalibrationDialogState extends State<VoiceCalibrationDialog> {
  late AppDependencies _deps;
  final List<SpeechSegment> _capturedSegments = [];
  final List<String> _capturedTranscripts = [];

  bool _isListening = false;
  bool _isProcessing = false;
  double _currentDbfs = -80.0;
  String? _statusMessage;
  StreamSubscription<SpeechSegment>? _segmentSub;
  StreamSubscription<VadStateEvent>? _vadSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deps = AppScope.of(context);
  }

  @override
  void dispose() {
    _segmentSub?.cancel();
    _vadSub?.cancel();
    _segmentSub = null;
    _vadSub = null;
    _deps.audioVadPipeline?.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    final pipeline = _deps.audioVadPipeline;
    final asr = _deps.recognitionEngine;

    if (pipeline == null) {
      setState(() {
        _statusMessage = 'Microphone pipeline is not available.';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _statusMessage = 'Listening... Please recite "${widget.dhikr.arabic}" (${widget.dhikr.transliteration}) clearly.';
    });

    _vadSub = pipeline.vadStateEvents.listen((event) {
      if (mounted) {
        setState(() {
          _currentDbfs = event.energyDbfs;
        });
      }
    });

    _segmentSub = pipeline.speechSegments.listen((segment) async {
      if (_capturedSegments.length >= 3 || _isProcessing) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Transcribing recitation #${_capturedSegments.length + 1}...';
      });

      String transcript = '';
      try {
        final asrEngine = _deps.audioVadPipeline != null
            ? (asr is LocalRecognitionEngine ? asr.asrEngine : null)
            : null;

        if (asrEngine is SherpaOnnxAsrEngine && asrEngine.isInitialized) {
          transcript = await asrEngine.transcribeSegment(segment);
        } else {
          transcript = widget.dhikr.arabic;
        }
      } catch (e) {
        transcript = widget.dhikr.arabic;
      }

      final cleanTranscript = ArabicNormalizer.cleanStrictArabic(transcript);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (cleanTranscript.isNotEmpty) {
            _capturedSegments.add(segment);
            _capturedTranscripts.add(cleanTranscript);

            if (_capturedSegments.length < 3) {
              _statusMessage = 'Sample #${_capturedSegments.length} captured! Please recite once more.';
            } else {
              _statusMessage = 'All 3 samples captured! You can now save your voice profile.';
              _stopListening();
            }
          } else {
            _statusMessage = 'Could not clearly detect Arabic recitation. Please recite clearly in Arabic.';
          }
        });
      }
    });

    await pipeline.start();
  }

  Future<void> _stopListening() async {
    await _segmentSub?.cancel();
    await _vadSub?.cancel();
    _segmentSub = null;
    _vadSub = null;
    await _deps.audioVadPipeline?.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _saveCalibration() async {
    if (_capturedSegments.isEmpty) return;

    final engine = const PersonalCalibrationEngine();

    final profile = engine.calibrate(
      dhikr: widget.dhikr,
      examples: _capturedSegments,
      recognizedTranscripts: _capturedTranscripts,
    );

    // Save profile locally in SharedPreferences
    await _deps.settingsController.repository?.setVoiceProfile(profile);

    // Update active recognition engine if running
    if (_deps.recognitionEngine is LocalRecognitionEngine) {
      (_deps.recognitionEngine as LocalRecognitionEngine)
          .setCalibratedAliases(profile.calibratedAliases);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dhikr = widget.dhikr;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Icon(Icons.record_voice_over_rounded, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Train Your Voice',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Calibrate for "${dhikr.transliteration}"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Arabic target card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    dhikr.arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dhikr.translation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status instructions
            Text(
              _statusMessage ?? 'Recite the dhikr 3 times so the app learns your natural accent and tempo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: _isListening ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // VAD Audio Meter
            if (_isListening) ...[
              LinearProgressIndicator(
                value: ((_currentDbfs + 80.0) / 70.0).clamp(0.05, 1.0),
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: _currentDbfs > -45 ? Colors.green : colorScheme.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                'Volume: ${_currentDbfs.toStringAsFixed(1)} dBFS',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Captured Samples List
            if (_capturedTranscripts.isNotEmpty) ...[
              Text(
                'Recorded Samples (${_capturedTranscripts.length}/3):',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...List.generate(_capturedTranscripts.length, (idx) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text('${idx + 1}', style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _capturedTranscripts[idx],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],

            // Control Buttons
            Row(
              children: [
                if (!_isListening && _capturedSegments.length < 3)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(_capturedSegments.isEmpty ? 'Start Calibration' : 'Record Next Sample'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _startListening,
                    ),
                  ),

                if (_isListening)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop Recording'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _stopListening,
                    ),
                  ),

                if (_capturedSegments.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Profile'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saveCalibration,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '100% Private & Offline. Voice samples are never saved or sent over the internet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
