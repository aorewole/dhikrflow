import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../domain/models/dhikr_definition.dart';
import '../../domain/models/dhikr_session.dart';
import '../../domain/recognition/recognition_engine.dart';
import '../../recognition/local_recognition_engine.dart';
import '../../recognition/mock_recognition_engine.dart';
import '../../recognition/vad/vad_event.dart';
import '../../recognition/text/arabic_normalizer.dart';
import '../../services/arabic_speech_guide_service.dart';
import 'session_complete_screen.dart';
import 'widgets/recitation_letter_sweep.dart';
import 'widgets/recitation_word_highlighter.dart';
import 'widgets/session_tutorial_overlay.dart';

/// Feedback accompaniment modes during active recitation.
enum AudioGuideMode {
  mute(label: 'Mute', icon: Icons.volume_off_rounded),
  haptic(label: 'Haptic', icon: Icons.vibration_rounded),
  voice(label: 'Voice', icon: Icons.record_voice_over_rounded);

  final String label;
  final IconData icon;

  const AudioGuideMode({required this.label, required this.icon});
}

/// The primary active recitation and repetition counting screen.
class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _sweepController;
  final ArabicSpeechGuideService _speechGuideService =
      ArabicSpeechGuideService();

  AudioGuideMode _audioGuideMode = AudioGuideMode.haptic;
  bool _isBreathingPause = false;
  int _tripletCount = 0;
  int _breathCycleReps = 3;
  bool _userVoiceDetectedThisRep = false;
  int _countAtSweepStart = 0;
  Timer? _breathingTimer;
  Timer? _initialSettlingTimer;
  DhikrDefinition? _currentDhikr;

  bool _showDebugBar = false;
  bool _showDiagnostics = false;
  bool _showSessionTutorial = false;
  bool _isTranscriptExpanded = true;
  bool _isSettingsExpanded = true;
  bool _hasSettledInitialDelay = false;
  PacingSpeed _pacingSpeed = PacingSpeed.medium;
  bool _isSpeaking = false;
  final List<RecognitionDiagnostic> _recentDiagnostics = [];
  StreamSubscription<RecognitionDiagnostic>? _diagnosticSubscription;
  RecognitionEngine? _subscribedEngine;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _sweepController = AnimationController(
      vsync: this,
      duration: _pacingSpeed.duration,
    );

    _sweepController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_currentDhikr != null) {
          _onSweepCompleted(_currentDhikr!);
        }
      }
    });

    _speechGuideService.init();
    _speechGuideService.onPlayStateChanged = (isPlaying) {
      if (!mounted) return;
      final deps = AppScope.of(context);
      final engine = deps.recognitionEngine;
      if (engine is LocalRecognitionEngine) {
        engine.isSpeakerOutputActive = isPlaying;
      }
    };
  }

  void _startRepetitionSweep(DhikrDefinition dhikr) {
    if (!mounted) return;
    final deps = AppScope.of(context);
    if (deps.sessionController.isPaused ||
        deps.sessionController.currentSession?.status != SessionStatus.active) {
      return;
    }

    _countAtSweepStart = deps.sessionController.currentSession?.count ?? 0;
    _userVoiceDetectedThisRep = false;
    final wordCount = ArabicNormalizer.tokenize(dhikr.arabic).length;
    _sweepController.duration = _pacingSpeed.durationForWordCount(wordCount);

    // Trigger feedback accompaniment at repetition onset according to mode:
    switch (_audioGuideMode) {
      case AudioGuideMode.haptic:
        HapticFeedback.selectionClick();
        break;
      case AudioGuideMode.voice:
        _speechGuideService.speakDhikr(dhikr.arabic, _pacingSpeed);
        break;
      case AudioGuideMode.mute:
        break;
    }

    _sweepController.forward(from: 0.0);
  }

  void _onSweepCompleted(DhikrDefinition dhikr) {
    if (!mounted) return;
    final deps = AppScope.of(context);
    if (deps.sessionController.isPaused ||
        deps.sessionController.currentSession?.status != SessionStatus.active) {
      return;
    }

    final currentCount = deps.sessionController.currentSession?.count ?? 0;
    final alreadyIncrementedByAsr = currentCount > _countAtSweepStart;

    if (alreadyIncrementedByAsr) {
      // Clean ASR / ARe already incremented count
      if (_audioGuideMode == AudioGuideMode.haptic) {
        HapticFeedback.mediumImpact();
      }
    } else if (_userVoiceDetectedThisRep) {
      // Verified human recitation confirmed during this sweep window
      deps.sessionController.incrementManual();
      if (_audioGuideMode == AudioGuideMode.haptic) {
        HapticFeedback.mediumImpact();
      }
    } else {
      // Silent sweep: User did not speak; count holds
    }

    _userVoiceDetectedThisRep = false;

    // Advance predictable pacing cycle step
    _tripletCount++;

    // Check breathing cadence: pause every _breathCycleReps dhikr
    if (_tripletCount >= _breathCycleReps) {
      // Keep _tripletCount at _breathCycleReps during the pause so UI displays "N / N"
      setState(() {
        _isBreathingPause = true;
      });
      // Ensure all speech audio & guide sounds stop completely during breathing pause
      _speechGuideService.stop();
      if (_audioGuideMode == AudioGuideMode.haptic) {
        _triggerBreathingHapticPattern();
      }

      _breathingTimer?.cancel();
      _breathingTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _isBreathingPause = false;
          _tripletCount = 0; // Reset after breathing pause completes
        });
        _startRepetitionSweep(dhikr);
      });
    } else {
      // Brief inter-repetition pacing gap (~220ms)
      setState(() {}); // refresh cycle dots
      _breathingTimer?.cancel();
      _breathingTimer = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _startRepetitionSweep(dhikr);
      });
    }
  }

  void _pauseGuide() {
    _sweepController.stop();
    _speechGuideService.stop();
    _breathingTimer?.cancel();
  }

  void _resumeGuide(DhikrDefinition dhikr) {
    if (_isBreathingPause) {
      _breathingTimer?.cancel();
      _breathingTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _isBreathingPause = false;
          _tripletCount = 0;
        });
        _startRepetitionSweep(dhikr);
      });
    } else {
      _startRepetitionSweep(dhikr);
    }
  }

  void _triggerBreathingHapticPattern() {
    // 3-stage calming breath wave: Inhale (heavy) -> Settle (medium) -> Exhale (light)
    // Tactilely distinct from single-tap counting feedback.
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted && _isBreathingPause) {
        HapticFeedback.mediumImpact();
      }
    });
    Future.delayed(const Duration(milliseconds: 520), () {
      if (mounted && _isBreathingPause) {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _scheduleInitialSettlingSweep() {
    final deps = AppScope.of(context);
    _initialSettlingTimer?.cancel();
    _initialSettlingTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted &&
          _currentDhikr != null &&
          !deps.sessionController.isPaused &&
          !_sweepController.isAnimating &&
          !_isBreathingPause &&
          !_showSessionTutorial) {
        _startRepetitionSweep(_currentDhikr!);
      }
    });
  }

  void _dismissTutorial() {
    final deps = AppScope.of(context);
    deps.settingsController.setHasCompletedSessionTutorial(true);
    setState(() {
      _showSessionTutorial = false;
    });
    _scheduleInitialSettlingSweep();
  }

  void _openTutorial() {
    _initialSettlingTimer?.cancel();
    _breathingTimer?.cancel();
    _sweepController.stop();
    _speechGuideService.stop();
    setState(() {
      _showSessionTutorial = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deps = AppScope.of(context);
    final dhikr = deps.sessionController.activeDhikr;
    if (dhikr != null) {
      _currentDhikr = dhikr;
      // First-time tutorial or gentle 1.2s settling delay on screen entrance
      if (!_hasSettledInitialDelay) {
        _hasSettledInitialDelay = true;
        if (!deps.settingsController.hasCompletedSessionTutorial) {
          _showSessionTutorial = true;
        } else {
          _scheduleInitialSettlingSweep();
        }
      }
    }

    final engine = deps.recognitionEngine;
    if (_subscribedEngine != engine) {
      _subscribedEngine = engine;
      _diagnosticSubscription?.cancel();
      final stream = engine.diagnostics;
      if (stream != null) {
        _diagnosticSubscription = stream.listen((diag) {
          if (mounted) {
            setState(() {
              _isSpeaking = diag.isSpeaking;
              // Transient & clap shield: Only accept verified voiced speech or valid phrase matches.
              // Impulsive acoustic transients (< 320ms, claps, taps) do NOT validate voice presence.
              // Hardware AEC eliminates speaker echo while preserving the user's near-end recitation.
              final isVerifiedSpeech =
                  diag.isVoiceVerified ||
                  (diag.asrCount != null && diag.asrCount! > 0) ||
                  (diag.areCount != null &&
                      diag.areCount! > 0 &&
                      (diag.confidence ?? 0.0) >= 0.5);

              if (isVerifiedSpeech) {
                _userVoiceDetectedThisRep = true;
              }
              if (diag.hasTranscript) {
                _recentDiagnostics.insert(0, diag);
                if (_recentDiagnostics.length > 10) {
                  _recentDiagnostics.removeLast();
                }
              }
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _initialSettlingTimer?.cancel();
    _breathingTimer?.cancel();
    _speechGuideService.dispose();
    _sweepController.dispose();
    _diagnosticSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: deps.sessionController,
      builder: (context, _) {
        final session = deps.sessionController.currentSession;
        final dhikr = deps.sessionController.activeDhikr;
        final isListening = deps.sessionController.isListening;
        final isPaused = deps.sessionController.isPaused;

        if (session == null || dhikr == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'No active session',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _confirmExitSession(context),
            ),
            title: Text(
              dhikr.transliteration,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (deps.recognitionEngine is MockRecognitionEngine)
                IconButton(
                  tooltip: 'Toggle Mock Voice Simulator',
                  icon: Icon(
                    _showDebugBar
                        ? Icons.developer_mode_rounded
                        : Icons.developer_mode_outlined,
                    size: 20,
                    color: _showDebugBar ? colorScheme.primary : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showDebugBar = !_showDebugBar;
                    });
                  },
                ),
              IconButton(
                tooltip: _showDiagnostics
                    ? 'Hide Diagnostics'
                    : 'Show Recognition Diagnostics',
                icon: Icon(
                  _showDiagnostics
                      ? Icons.troubleshoot_rounded
                      : Icons.troubleshoot_outlined,
                  size: 22,
                  color: _showDiagnostics ? colorScheme.primary : null,
                ),
                onPressed: () {
                  setState(() {
                    _showDiagnostics = !_showDiagnostics;
                    if (_showDiagnostics) {
                      _isTranscriptExpanded = true;
                    }
                  });
                },
              ),
              IconButton(
                tooltip: 'Counting Screen Guide',
                icon: const Icon(Icons.help_outline_rounded, size: 22),
                onPressed: _openTutorial,
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
              children: [
                // Listening state banner
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: isListening
                            ? _pulseController
                            : const AlwaysStoppedAnimation(0.3),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isListening
                                ? Colors.green
                                : isPaused
                                ? Colors.amber
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isListening
                            ? 'Listening locally (Offline)'
                            : isPaused
                            ? 'Session paused'
                            : 'Microphone idle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isListening ? colorScheme.primary : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // Target Progress Indicator (if target exists)
                if (session.target != null && session.target! > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: session.progress ?? 0.0,
                            minHeight: 6,
                            backgroundColor: colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              session.isTargetReached
                                  ? Colors.green
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target: ${session.target}',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              session.isTargetReached
                                  ? 'Target Reached ✓'
                                  : '${session.remaining} remaining',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: session.isTargetReached
                                    ? Colors.green
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Prominent Dhikr Counter & Timer Display (Top Focus)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Text(
                        '${session.count}',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w200,
                          fontSize: 80,
                          letterSpacing: -2,
                          color: session.isTargetReached
                              ? Colors.green
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        session.count == 1 ? 'DHIKR' : 'ADHKAR',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(session.duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Stage: Arabic Recitation Letter Sweep + Translation
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _sweepController,
                              builder: (context, _) {
                                return RecitationLetterSweep(
                                  arabicText: dhikr.arabic,
                                  isSpeaking: isListening &&
                                      (_isSpeaking || _userVoiceDetectedThisRep),
                                  repetitionCount: session.count,
                                  pacingSpeed: _pacingSpeed,
                                  isBreathingPause: _isBreathingPause,
                                  breathCycleReps: _breathCycleReps,
                                  currentBreathStep: _tripletCount,
                                  sweepProgress: _sweepController.value,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              dhikr.translation,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Collapsible Pacing & Guide Settings (Near user's thumb)
                            _buildCollapsibleSettingsCard(
                              context,
                              colorScheme,
                              dhikr,
                            ),
                            // Collapsible Live Transcription Callout (when toggled in appbar)
                            _buildLiveTranscriptionCallout(context, dhikr),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Mock Voice Simulation Controls (for Phase 1 dev/preview)
                if (_showDebugBar &&
                    deps.recognitionEngine is MockRecognitionEngine)
                  _buildMockEngineControls(
                    context,
                    deps.recognitionEngine as MockRecognitionEngine,
                  ),

                // Manual +1 Tap Fallback Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: OutlinedButton(
                    onPressed: () => deps.sessionController.incrementManual(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Manual +1 Tap',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Session Control Buttons: Pause / Resume / Finish
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      // Pause / Resume
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () async {
                            if (isPaused) {
                              await deps.sessionController.resumeSession();
                              if (mounted) {
                                _resumeGuide(dhikr);
                              }
                            } else {
                              await deps.sessionController.pauseSession();
                              if (mounted) {
                                _pauseGuide();
                              }
                            }
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                              ),
                              const SizedBox(width: 6),
                              Text(isPaused ? 'Resume' : 'Pause'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Finish Session
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            _pauseGuide();
                            final completed = await deps.sessionController
                                .completeSession();
                            if (context.mounted && completed != null) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => SessionCompleteScreen(
                                    session: completed,
                                    dhikr: dhikr,
                                  ),
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded),
                              SizedBox(width: 6),
                              Text('Finish'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showSessionTutorial)
            Positioned.fill(
              child: SessionTutorialOverlay(
                onDismiss: _dismissTutorial,
              ),
            ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildCollapsibleSettingsCard(
    BuildContext context,
    ColorScheme colorScheme,
    DhikrDefinition dhikr,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _isSettingsExpanded = !_isSettingsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pacing & Guide',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!_isSettingsExpanded) ...[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${_pacingSpeed.label} · ${_audioGuideMode.label} · Every $_breathCycleReps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  Icon(
                    _isSettingsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (_isSettingsExpanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recitation Pacing Speed Controls (Slow / Medium / Fast)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<PacingSpeed>(
                      segments: const [
                        ButtonSegment<PacingSpeed>(
                          value: PacingSpeed.slow,
                          label: Text('Slow'),
                          icon: Icon(Icons.hourglass_bottom_rounded, size: 14),
                        ),
                        ButtonSegment<PacingSpeed>(
                          value: PacingSpeed.medium,
                          label: Text('Medium'),
                          icon: Icon(Icons.speed_rounded, size: 14),
                        ),
                        ButtonSegment<PacingSpeed>(
                          value: PacingSpeed.fast,
                          label: Text('Fast'),
                          icon: Icon(Icons.bolt_rounded, size: 14),
                        ),
                      ],
                      selected: {_pacingSpeed},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _pacingSpeed = selected.first;
                          final wordCount =
                              ArabicNormalizer.tokenize(dhikr.arabic).length;
                          _sweepController.duration =
                              _pacingSpeed.durationForWordCount(wordCount);
                        });
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Feedback Accompaniment Mode (Mute / Haptic / Voice Guide)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AudioGuideMode>(
                      segments: const [
                        ButtonSegment<AudioGuideMode>(
                          value: AudioGuideMode.mute,
                          label: Text('Mute'),
                          icon: Icon(Icons.volume_off_rounded, size: 14),
                        ),
                        ButtonSegment<AudioGuideMode>(
                          value: AudioGuideMode.haptic,
                          label: Text('Haptic'),
                          icon: Icon(Icons.vibration_rounded, size: 14),
                        ),
                        ButtonSegment<AudioGuideMode>(
                          value: AudioGuideMode.voice,
                          label: Text('Voice'),
                          icon: Icon(Icons.record_voice_over_rounded, size: 14),
                        ),
                      ],
                      selected: {_audioGuideMode},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _audioGuideMode = selected.first;
                          if (_audioGuideMode != AudioGuideMode.voice) {
                            _speechGuideService.stop();
                          }
                          if (_audioGuideMode == AudioGuideMode.haptic) {
                            HapticFeedback.lightImpact();
                          }
                        });
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Configurable Breath Cadence Stepper (1 to 10 dhikr)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.air_rounded,
                        size: 15,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Breathe every:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 15),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              constraints: const BoxConstraints(),
                              onPressed: _breathCycleReps > 1
                                  ? () => setState(() => _breathCycleReps--)
                                  : null,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$_breathCycleReps ${_breathCycleReps == 1 ? "dhikr" : "adhkar"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 15),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              constraints: const BoxConstraints(),
                              onPressed: _breathCycleReps < 10
                                  ? () => setState(() => _breathCycleReps++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTranscriptionCallout(
    BuildContext context,
    DhikrDefinition dhikr,
  ) {
    if (!_showDiagnostics) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final latest =
        _recentDiagnostics.isNotEmpty ? _recentDiagnostics.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapsible Header Row
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _isTranscriptExpanded = !_isTranscriptExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Acoustic Telemetry',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildStatusBadge(latest, colorScheme),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isTranscriptExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),

          // Collapsed preview line
          if (!_isTranscriptExpanded && latest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                latest.isCounted
                    ? '✓ ${latest.fusionReason ?? "Voiced repetition counted"}'
                    : (latest.fusionReason ?? 'Listening for recitation...'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: latest.isCounted ? FontWeight.w600 : FontWeight.normal,
                  color: latest.isCounted ? Colors.green : colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Expanded Details Body
          if (_isTranscriptExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_recentDiagnostics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Recite your dhikr at your natural pace.\nLive acoustic waveform and rhythm telemetry will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Latest Utterance Focus Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (latest!.isCounted
                                  ? Colors.green
                                  : latest.isBuffering
                                      ? Colors.amber
                                      : colorScheme.outlineVariant)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'LATEST RECOGNIZED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: colorScheme.outline,
                                ),
                              ),
                              Text(
                                _formatTime(latest.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (latest.rawTranscript != null &&
                                    !latest.rawTranscript!.startsWith('['))
                                ? latest.rawTranscript!
                                : dhikr.arabic,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: latest.isCounted
                                  ? Colors.green
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Confidence meter & outcome explanation
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (latest.confidence ?? 0.0)
                                        .clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      latest.isCounted
                                          ? Colors.green
                                          : latest.isBuffering
                                              ? Colors.amber
                                              : Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                latest.confidence != null
                                    ? '${((latest.confidence!) * 100).toStringAsFixed(0)}%'
                                    : '--%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            latest.isCounted
                                ? '✓ Voiced repetition confirmed (+${latest.newOccurrences} counted)'
                                : latest.isBuffering
                                    ? '⏳ Partial phrase buffered: [${latest.pendingPrefixTokens.join(' ')}] — awaiting completion'
                                    : (latest.fusionReason ?? 'Listening for recitation...'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: latest.isCounted
                                  ? Colors.green
                                  : latest.isBuffering
                                      ? Colors.amber.shade800
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),

                          // ── Engine Detail (expanded only) ──────────────────
                          if (latest.areCount != null || latest.fusionReason != null || latest.asrCount != null) ...[
                            const SizedBox(height: 10),
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ACOUSTIC TELEMETRY DETAIL',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildEngineDetailRow(
                              label: 'Wave',
                              detail: 'Acoustic envelope & rhythm',
                              count: latest.areCount ?? latest.newOccurrences,
                              colorScheme: colorScheme,
                              extraNote: latest.confidence != null
                                  ? '${((latest.confidence!) * 100).toStringAsFixed(0)}% conf'
                                  : null,
                            ),
                            if (latest.asrCount != null &&
                                latest.rawTranscript != null &&
                                !latest.rawTranscript!.startsWith('[')) ...[
                              const SizedBox(height: 4),
                              _buildEngineDetailRow(
                                label: 'ASR',
                                detail: latest.rawTranscript!,
                                count: latest.asrCount!,
                                colorScheme: colorScheme,
                                isRtlDetail: true,
                              ),
                            ],
                            const SizedBox(height: 4),
                            _buildEngineDetailRow(
                              label: 'Guard',
                              detail: latest.isVoiceVerified
                                  ? 'Voiced speech verified'
                                  : (latest.fusionReason?.contains('Transient') ?? false)
                                      ? 'Transient shielded (<200ms)'
                                      : 'Noise / unverified',
                              count: 0,
                              colorScheme: colorScheme,
                              hideCount: true,
                              extraNote: latest.isVoiceVerified ? '✓ Valid' : '✗ Blocked',
                            ),
                            const SizedBox(height: 4),
                            _buildEngineDetailRow(
                              label: 'Pacing',
                              detail: '${_pacingSpeed.label} mode',
                              count: 0,
                              colorScheme: colorScheme,
                              hideCount: true,
                              extraNote: '${_pacingSpeed.wordDurationMs}ms/word',
                            ),
                            const SizedBox(height: 4),
                            _buildEngineDetailRow(
                              label: 'Audio',
                              detail: '${_audioGuideMode.label} mode',
                              count: 0,
                              colorScheme: colorScheme,
                              hideCount: true,
                            ),
                            const SizedBox(height: 4),
                            _buildEngineDetailRow(
                              label: 'Breath',
                              detail: 'Every $_breathCycleReps adhkar',
                              count: 0,
                              colorScheme: colorScheme,
                              hideCount: true,
                              extraNote: 'Step $_tripletCount of $_breathCycleReps',
                            ),
                            Divider(
                              height: 14,
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            _buildEngineDetailRow(
                              label: 'Final',
                              detail: latest.fusionReason ?? '',
                              count: latest.newOccurrences,
                              colorScheme: colorScheme,
                              isFinal: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Recent Utterances History (previous items)
                    if (_recentDiagnostics.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'RECENT UTTERANCES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (int i = 1;
                          i < math.min(5, _recentDiagnostics.length);
                          i++)
                        _buildRecentItemRow(_recentDiagnostics[i], colorScheme),
                    ],

                    // Action buttons: Copy Log & Clear
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _copyTranscriptionLog(context, dhikr),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text(
                            'Copy Log',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _recentDiagnostics.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_all_rounded, size: 14),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    RecognitionDiagnostic? latest,
    ColorScheme colorScheme,
  ) {
    if (latest == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Awaiting speech...',
          style: TextStyle(fontSize: 11, color: colorScheme.outline),
        ),
      );
    }

    final confStr = latest.confidence != null
        ? '${((latest.confidence!) * 100).toStringAsFixed(0)}%'
        : '';

    if (latest.isCounted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: Text(
          '✓ +${latest.newOccurrences} ($confStr)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.green,
          ),
        ),
      );
    } else if (latest.isBuffering) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: Text(
          '⏳ Buffering (${latest.pendingPrefixTokens.length} w)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.amber.shade800,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+0 No match ($confStr)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.outline,
          ),
        ),
      );
    }
  }

  /// Builds a single row in the Engine Detail section of the expanded card.
  ///
  /// Layout: [label] ... [detail clipped] → [count]
  Widget _buildEngineDetailRow({
    required String label,
    required String detail,
    required int count,
    required ColorScheme colorScheme,
    bool isRtlDetail = false,
    bool isFinal = false,
    bool hideCount = false,
    String? extraNote,
  }) {
    final labelColor =
        isFinal ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    final countColor = isFinal
        ? (count > 0 ? Colors.green : colorScheme.outline)
        : colorScheme.outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label chip
        Container(
          width: 38,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isFinal
                ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isFinal ? FontWeight.w700 : FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Detail text (clipped)
        Expanded(
          child: Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection:
                isRtlDetail ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontStyle: isRtlDetail ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
        if (extraNote != null) ...[
          const SizedBox(width: 4),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              extraNote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colorScheme.outline),
            ),
          ),
        ],
        if (!hideCount) ...[
          const SizedBox(width: 6),
          // Arrow
          Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: colorScheme.outline,
          ),
          const SizedBox(width: 4),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: countColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: countColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentItemRow(
    RecognitionDiagnostic diag,
    ColorScheme colorScheme,
  ) {
    final confStr = diag.confidence != null
        ? '${((diag.confidence!) * 100).toStringAsFixed(0)}%'
        : '--%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            _formatTime(diag.timestamp),
            style: TextStyle(fontSize: 10, color: colorScheme.outline),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              diag.rawTranscript ?? '',
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: diag.isCounted ? Colors.green : colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (diag.isCounted
                      ? Colors.green
                      : colorScheme.surfaceContainerHighest)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              diag.isCounted ? '+${diag.newOccurrences}' : '+0',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: diag.isCounted ? Colors.green : colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            confStr,
            style: TextStyle(fontSize: 10, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  void _copyTranscriptionLog(BuildContext context, DhikrDefinition dhikr) {
    if (_recentDiagnostics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transcriptions recorded in this session yet.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('--- Dhikr Counter Transcription Log ---');
    buffer.writeln('Target: ${dhikr.transliteration} (${dhikr.arabic})');
    buffer.writeln('History:');
    for (final diag in _recentDiagnostics.reversed) {
      final timeStr = _formatTime(diag.timestamp);
      final confStr = diag.confidence != null
          ? '${((diag.confidence!) * 100).toStringAsFixed(0)}%'
          : 'N/A';
      final status = diag.isCounted
          ? '+${diag.newOccurrences} Counted'
          : (diag.isBuffering
              ? 'Buffering (${diag.pendingPrefixTokens.join(' ')})'
              : '+0 No match');
      buffer.writeln(
        '[$timeStr] "${diag.rawTranscript}" -> $status (Confidence: $confStr)',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcription log copied! Paste it into the chat.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _buildMockEngineControls(
    BuildContext context,
    MockRecognitionEngine mockEngine,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Phase 1 Mock Engine Simulator:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.record_voice_over_rounded, size: 14),
                  label: const Text('+1 Voice', style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      mockEngine.simulateVoiceCount(repetitions: 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.fast_forward_rounded, size: 14),
                  label: const Text('+4 Rapid', style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      mockEngine.simulateVoiceCount(repetitions: 4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.block_rounded, size: 14),
                  label: const Text(
                    'Unrelated',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unrelated speech detected (+0 count)'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (mockEngine.pipeline != null) ...[
            const Divider(height: 14),
            StreamBuilder<VadStateEvent>(
              stream: mockEngine.pipeline!.vadStateEvents,
              builder: (context, snapshot) {
                final vadEvent = snapshot.data;
                final isSpeech = vadEvent?.isSpeech ?? false;
                final dbfs = vadEvent?.energyDbfs ?? -100.0;
                final normalizedEnergy = ((dbfs + 80.0) / 80.0).clamp(0.0, 1.0);

                return Row(
                  children: [
                    Icon(
                      isSpeech
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded,
                      size: 15,
                      color: isSpeech ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSpeech ? 'VAD: Speech' : 'VAD: Silence',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSpeech ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: normalizedEnergy,
                          minHeight: 4,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isSpeech ? Colors.green : colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dbfs.toStringAsFixed(0)} dBFS',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _confirmExitSession(BuildContext context) {
    _pauseGuide();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('End Session?'),
          content: const Text(
            'Would you like to save this recitation before exiting, or discard it?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final deps = AppScope.of(context);
                await deps.sessionController.endCurrentSessionSilently();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final deps = AppScope.of(context);
                final dhikr = deps.sessionController.activeDhikr;
                final completed = await deps.sessionController
                    .completeSession();
                if (context.mounted && completed != null && dhikr != null) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => SessionCompleteScreen(
                        session: completed,
                        dhikr: dhikr,
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save & Finish'),
            ),
          ],
        );
      },
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
