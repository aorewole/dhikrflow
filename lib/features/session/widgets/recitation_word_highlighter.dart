import 'package:flutter/material.dart';

/// Recitation pacing modes controlling word-by-word visual guidance speed.
enum PacingSpeed {
  slow(wordDurationMs: 1300, label: 'Slow'),
  medium(wordDurationMs: 850, label: 'Medium'),
  fast(wordDurationMs: 500, label: 'Fast');

  final int wordDurationMs;
  final String label;

  const PacingSpeed({
    required this.wordDurationMs,
    required this.label,
  });

  Duration get duration => Duration(milliseconds: wordDurationMs);

  /// Calculates dynamic repetition duration proportional to phrase word count.
  /// Synchronizes with natural human liturgical cadence and speech engine synthesis rate:
  /// The first two tokens establish liturgical rhythm (1.55x), and each subsequent token
  /// breathes at a natural connected pace (~0.70x wordDurationMs).
  Duration durationForWordCount(int wordCount) {
    final count = wordCount <= 0 ? 1 : wordCount;
    int totalMs;
    if (count == 1) {
      totalMs = wordDurationMs < 900 ? 900 : wordDurationMs;
    } else if (count == 2) {
      totalMs = (wordDurationMs * 1.55).round();
    } else {
      // 3+ words: each word connects with proper tajweed and harmonic pacing
      totalMs = (wordDurationMs * 1.55 + (count - 2) * (wordDurationMs * 0.70)).round();
    }
    if (totalMs < 900) totalMs = 900;
    if (totalMs > 14000) totalMs = 14000;
    return Duration(milliseconds: totalMs);
  }
}

/// An interactive, 3-state Tartil AI-style Arabic recitation coaching highlighter.
///
/// 3 Visual States:
/// 1. **Baseline / Unread (Grey)**: Default quiet muted text for words yet to be spoken.
/// 2. **Prompt Target (Blinking Green)**: The active word currently being prompted to speak.
/// 3. **Accepted (Radiant Amber/Yellow)**: Words already spoken and accepted in the current repetition.
///
/// Completion:
/// When all words are spoken and repetition count increments (+1), the entire phrase
/// pulses with a celebratory green glow and seamlessly resets to word 0 for the next cycle.
class RecitationWordHighlighter extends StatefulWidget {
  final String arabicText;
  final bool isSpeaking;
  final int repetitionCount;
  final PacingSpeed pacingSpeed;
  final TextStyle? baseStyle;
  final TextStyle? promptStyle;
  final TextStyle? acceptedStyle;

  const RecitationWordHighlighter({
    super.key,
    required this.arabicText,
    required this.isSpeaking,
    required this.repetitionCount,
    this.pacingSpeed = PacingSpeed.medium,
    this.baseStyle,
    this.promptStyle,
    this.acceptedStyle,
  });

  @override
  State<RecitationWordHighlighter> createState() =>
      _RecitationWordHighlighterState();
}

class _RecitationWordHighlighterState extends State<RecitationWordHighlighter>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _stepController;
  late List<String> _words;
  int _activeWordIndex = 0;
  int _lastCount = 0;
  bool _isFlashingCompletion = false;

  @override
  void initState() {
    super.initState();
    _words = _splitArabicWords(widget.arabicText);
    _lastCount = widget.repetitionCount;

    // Pulse animation for the active prompt word (blinking green)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    // Step animation advancing through words based on pacing speed
    _stepController = AnimationController(
      vsync: this,
      duration: widget.pacingSpeed.duration,
    );

    _stepController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && widget.isSpeaking && !_isFlashingCompletion) {
          setState(() {
            if (_activeWordIndex < _words.length - 1) {
              _activeWordIndex++;
              _stepController.forward(from: 0.0);
            }
          });
        }
      }
    });

    if (widget.isSpeaking) {
      _stepController.forward();
    }
  }

  @override
  void didUpdateWidget(RecitationWordHighlighter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.arabicText != widget.arabicText) {
      _words = _splitArabicWords(widget.arabicText);
      _activeWordIndex = 0;
    }

    if (oldWidget.pacingSpeed != widget.pacingSpeed) {
      _stepController.duration = widget.pacingSpeed.duration;
    }

    // Handle count change: flash completion celebration and reset to word 0
    if (widget.repetitionCount > _lastCount) {
      _lastCount = widget.repetitionCount;
      _triggerCompletionPulse();
    } else if (widget.repetitionCount < _lastCount) {
      _lastCount = widget.repetitionCount;
      _activeWordIndex = 0;
    }

    // Handle speaking state transitions
    if (widget.isSpeaking && !_stepController.isAnimating && !_isFlashingCompletion) {
      _stepController.forward();
    } else if (!widget.isSpeaking && _stepController.isAnimating && !_isFlashingCompletion) {
      _stepController.stop();
    }
  }

  void _triggerCompletionPulse() {
    _isFlashingCompletion = true;
    _stepController.stop();
    if (mounted) setState(() {});

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _isFlashingCompletion = false;
        _activeWordIndex = 0;
      });
      if (widget.isSpeaking) {
        _stepController.forward(from: 0.0);
      }
    });
  }

  List<String> _splitArabicWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // State 1: Baseline / Unread (Subtle Grey)
    final defaultBaseStyle = widget.baseStyle ??
        TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface.withValues(alpha: 0.35),
          height: 1.5,
        );

    // State 2: Active Prompt (Blinking Emerald Green with subtle glow)
    final promptColor = Colors.tealAccent.shade400;

    // State 3: Accepted (Radiant Warm Amber / Gold)
    final defaultAcceptedStyle = widget.acceptedStyle ??
        TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: Colors.amber.shade400,
          height: 1.5,
          shadows: [
            Shadow(
              color: Colors.amber.shade700.withValues(alpha: 0.5),
              blurRadius: 12,
            ),
          ],
        );

    // Full Completion Celebration Style (Radiant Green)
    final completionStyle = TextStyle(
      fontSize: 33,
      fontWeight: FontWeight.w700,
      color: Colors.green.shade400,
      height: 1.5,
      shadows: [
        Shadow(
          color: Colors.green.shade600.withValues(alpha: 0.7),
          blurRadius: 16,
        ),
      ],
    );

    if (_words.isEmpty) {
      return Text(
        widget.arabicText,
        textAlign: TextAlign.center,
        style: defaultAcceptedStyle,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final pulseValue = 0.5 + (_pulseController.value * 0.5); // 0.5 to 1.0

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: List.generate(_words.length, (index) {
                TextStyle wordStyle;

                if (_isFlashingCompletion) {
                  wordStyle = completionStyle;
                } else if (index < _activeWordIndex) {
                  // State 3: Word is accepted and completed in this repetition (Amber/Gold)
                  wordStyle = defaultAcceptedStyle;
                } else if (index == _activeWordIndex) {
                  // State 2: Active target word currently being spoken/prompted (Blinking Green)
                  wordStyle = TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: promptColor.withValues(alpha: pulseValue),
                    height: 1.5,
                    shadows: [
                      Shadow(
                        color: promptColor.withValues(alpha: 0.5 * pulseValue),
                        blurRadius: 10 + (4 * pulseValue),
                      ),
                    ],
                  );
                } else {
                  // State 1: Future unread word (Calm Grey)
                  wordStyle = defaultBaseStyle;
                }

                return AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  style: wordStyle,
                  child: Text(_words[index]),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
