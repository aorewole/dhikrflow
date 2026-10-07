import 'package:flutter/material.dart';

/// Interactive in-app spotlight walkthrough overlay for the Active Counting Screen.
///
/// Introduces key screen elements to first-time users:
/// 1. Recitation pacing & audio guide modes
/// 2. Hands-free acoustic repetition counting
/// 3. Breath cadence pauses
/// 4. Manual +1 thumb tap button & collapsible settings
class SessionTutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const SessionTutorialOverlay({
    super.key,
    required this.onDismiss,
  });

  @override
  State<SessionTutorialOverlay> createState() => _SessionTutorialOverlayState();
}

class _SessionTutorialOverlayState extends State<SessionTutorialOverlay> {
  int _currentStep = 0;

  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      badge: 'Step 1 of 4',
      title: 'Recitation Pacing & Audio Guide',
      description:
          'Follow the golden letter sweep as you recite. Choose between spoken Voice Guide, silent Pocket Haptics, or Mute in thumb settings.',
      icon: Icons.graphic_eq_rounded,
      accentColor: Color(0xFFD4AF37), // Warm Islamic gold
    ),
    _TutorialStep(
      badge: 'Step 2 of 4',
      title: 'Hands-Free Counting',
      description:
          'Recite naturally into your phone. The acoustic speech analyzer increments your count automatically after every repetition—no screen touches needed.',
      icon: Icons.hearing_rounded,
      accentColor: Color(0xFF0D5C54), // Deep teal
    ),
    _TutorialStep(
      badge: 'Step 3 of 4',
      title: 'Mindful Breath Cadence',
      description:
          'After each cycle (e.g. 3 or 7 adhkar), a calm breathing pause gives your lungs space to inhale and resets your rhythm with a soothing haptic wave.',
      icon: Icons.air_rounded,
      accentColor: Color(0xFF2A8B78), // Sage teal
    ),
    _TutorialStep(
      badge: 'Step 4 of 4',
      title: 'Manual +1 & Thumb Settings',
      description:
          'Prefer counting silently or holding your phone? Tap the large button at the bottom anytime—even while paused. Expand settings to tune speed and feedback.',
      icon: Icons.touch_app_rounded,
      accentColor: Color(0xFFD4AF37),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: step.accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Top row: Step badge + Skip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: step.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        step.badge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: step.accentColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onDismiss,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.grey,
                      ),
                      child: const Text('Skip Tour'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Icon Snapshot Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: step.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step.accentColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    step.icon,
                    size: 34,
                    color: step.accentColor,
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.8,
                    ),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),

                // Step Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentStep == index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _currentStep == index
                            ? step.accentColor
                            : Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Navigation Buttons (Back & Next / Start)
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _currentStep--;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _currentStep > 0 ? 2 : 1,
                      child: FilledButton(
                        onPressed: () {
                          if (isLast) {
                            widget.onDismiss();
                          } else {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: step.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isLast ? 'Start Reciting' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _TutorialStep {
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _TutorialStep({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}
