import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../recognition/mock_recognition_engine.dart';
import 'session_complete_screen.dart';

/// The primary active recitation and repetition counting screen.
class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showDebugBar = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
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
            ],
          ),
          body: SafeArea(
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

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Arabic Dhikr Text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          dhikr.arabic,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.primary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dhikr.translation,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Giant Counter Display
                      Text(
                        '${session.count}',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w200,
                          fontSize: 84,
                          letterSpacing: -2,
                          color: session.isTargetReached
                              ? Colors.green
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'REPETITIONS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatDuration(session.duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
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
                    onPressed: isPaused
                        ? null
                        : () => deps.sessionController.incrementManual(),
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
                          onPressed: () {
                            if (isPaused) {
                              deps.sessionController.resumeSession();
                            } else {
                              deps.sessionController.pauseSession();
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
        );
      },
    );
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
        ],
      ),
    );
  }

  void _confirmExitSession(BuildContext context) {
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
