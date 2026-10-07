import 'package:flutter/material.dart';

import 'recitation_word_highlighter.dart';

/// An interactive, RTL letter-by-letter Arabic recitation coaching sweep widget.
///
/// Features:
/// 1. **Intact Arabic Typography**: Preserves Arabic cursive ligatures by applying
///    a continuous GPU-accelerated [ShaderMask] linear gradient instead of breaking words.
/// 2. **Right-to-Left Progressive Sweep**: Illuminates each letter and harakah smoothly
///    from right to left in sync with the recitation pacing speed.
/// 3. **3-State Color Hierarchy**:
///    - **Unread Letters**: Calm, muted grey for upcoming letters.
///    - **Active Letter Front**: Radiant glowing emerald/teal cursor highlighting the exact letter being pronounced.
///    - **Accepted Letters**: Warm radiant amber/gold for letters already spoken.
/// 4. **Celebration Pulse**: Full phrase radiant green glow on repetition increment (+1).
/// 5. **Breathing Pause**: Displays an elegant calming breathing prompt during breathing intervals.
class RecitationLetterSweep extends StatefulWidget {
  final String arabicText;
  final bool isSpeaking;
  final int repetitionCount;
  final PacingSpeed pacingSpeed;
  final bool isBreathingPause;
  final double sweepProgress;
  final int breathCycleReps;
  final int currentBreathStep;
  final TextStyle? baseStyle;

  const RecitationLetterSweep({
    super.key,
    required this.arabicText,
    required this.isSpeaking,
    required this.repetitionCount,
    this.pacingSpeed = PacingSpeed.medium,
    this.isBreathingPause = false,
    this.sweepProgress = 0.0,
    this.breathCycleReps = 3,
    this.currentBreathStep = 0,
    this.baseStyle,
  });

  @override
  State<RecitationLetterSweep> createState() => _RecitationLetterSweepState();
}

class _RecitationLetterSweepState extends State<RecitationLetterSweep>
    with SingleTickerProviderStateMixin {
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  int _lastCount = 0;
  bool _isFlashingCelebration = false;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.repetitionCount;

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 60,
      ),
    ]).animate(_celebrationController);
  }

  @override
  void didUpdateWidget(RecitationLetterSweep oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.repetitionCount > _lastCount) {
      _lastCount = widget.repetitionCount;
      _triggerCelebration();
    } else if (widget.repetitionCount < _lastCount) {
      _lastCount = widget.repetitionCount;
    }
  }

  void _triggerCelebration() {
    _isFlashingCelebration = true;
    _celebrationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isFlashingCelebration = false;
        });
      }
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final defaultStyle = widget.baseStyle ??
        TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.55,
          letterSpacing: 0.5,
        );

    // Color definitions
    final baseColor = colorScheme.onSurface.withValues(alpha: 0.28);
    final acceptedColor = Colors.amber.shade400;
    final activeCursorColor = Colors.tealAccent.shade400;
    final celebrationColor = Colors.green.shade400;

    // Progress clamped between 0.0 and 1.0
    final p = widget.sweepProgress.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: widget.isBreathingPause
                ? AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 0.55,
                    child: Text(
                      widget.arabicText,
                      textAlign: TextAlign.center,
                      style: defaultStyle.copyWith(color: baseColor),
                    ),
                  )
                : _isFlashingCelebration
                ? Text(
                    widget.arabicText,
                    textAlign: TextAlign.center,
                    style: defaultStyle.copyWith(
                      color: celebrationColor,
                      shadows: [
                        Shadow(
                          color: Colors.green.shade700.withValues(alpha: 0.7),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  )
                : ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (Rect bounds) {
                      // In RTL, Alignment.centerRight is where Arabic starts (0.0),
                      // and Alignment.centerLeft is where Arabic ends (1.0).
                      const double edge = 0.06;
                      final double stop0 = 0.0;
                      final double stop1 = (p - edge).clamp(0.0, 1.0);
                      final double stop2 = p;
                      final double stop3 = (p + edge).clamp(0.0, 1.0);
                      final double stop4 = 1.0;

                      return LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        stops: [stop0, stop1, stop2, stop3, stop4],
                        colors: [
                          acceptedColor,
                          acceptedColor,
                          activeCursorColor,
                          baseColor,
                          baseColor,
                        ],
                      ).createShader(bounds);
                    },
                    child: Text(
                      widget.arabicText,
                      textAlign: TextAlign.center,
                      style: defaultStyle,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 8),

        // Breathing Cadence Indicator Banner
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: widget.isBreathingPause
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.tealAccent.shade400,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                Icon(
                  Icons.air_rounded,
                  size: 17,
                  color: Colors.tealAccent.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.breathCycleReps} / ${widget.breathCycleReps} • Take a breath... 🌿',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.tealAccent.shade400,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.breathCycleReps, (_) {
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.tealAccent.shade400,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        secondChild: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.air_rounded,
                  size: 13,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cycle: ${widget.currentBreathStep} / ${widget.breathCycleReps}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 6),
                // Visual cadence dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.breathCycleReps, (index) {
                    final isFilled = index < widget.currentBreathStep;
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? Colors.tealAccent.shade400
                            : colorScheme.outline.withValues(alpha: 0.35),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
