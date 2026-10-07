import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../home/home_screen.dart';

/// Interactive onboarding & tutorial carousel for DhikrPulse.
class OnboardingScreen extends StatefulWidget {
  final bool isRevisit;

  const OnboardingScreen({super.key, this.isRevisit = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_TutorialSlide> _slides = const [
    _TutorialSlide(
      icon: Icons.graphic_eq_rounded,
      badgeText: 'HANDS-FREE RECITATION',
      title: 'Welcome to DhikrPulse',
      subtitle:
          'A serene, hands-free companion for sacred remembrance. Set your phone down, recite naturally, and let the app count your adhkar without touching the screen.',
      details: [
        'Pure on-device mathematical acoustic detection',
        '100% offline — zero audio is ever uploaded or saved',
        'Functions fully in Airplane Mode with zero tracking',
      ],
    ),
    _TutorialSlide(
      icon: Icons.air_rounded,
      badgeText: 'PACING & BREATH CADENCE',
      title: 'Rhythmic Recitation & Breath',
      subtitle:
          'Never rush or lose breath during long litanies. DhikrPulse provides measured visual pacing and automatic breathing pauses.',
      details: [
        'Right-to-Left letter sweep guides your natural tempo',
        'Slow, Medium, and Fast speed presets',
        'Automatic 1.8s pause every 3 adhkar: "Take a breath... 🌿"',
        'Customizable breath cycles from 1 to 10 repetitions',
      ],
    ),
    _TutorialSlide(
      icon: Icons.auto_stories_rounded,
      badgeText: 'AUTHENTIC SUNNAH LIBRARY',
      title: '27 Prophetic Adhkar',
      subtitle:
          'Explore a comprehensive collection of authentic morning, evening, praise, and forgiveness litanies.',
      details: [
        '6 filter categories: Tasbih, Istighfar, Tahlil, Protection...',
        'Standardized liturgical pausal waqf & sukūn codas',
        'Accurate phonetic transliterations & English meanings',
        'Quick-target chips: 33, 100, custom, or open-ended',
      ],
    ),
    _TutorialSlide(
      icon: Icons.vibration_rounded,
      badgeText: 'TACTILE & SILENT MODES',
      title: 'Pocket Mode & Manual +1',
      subtitle:
          'Perform dhikr with eyes closed, phone in pocket, or silently in the mosque without distracting others.',
      details: [
        'Haptic vibration pulses softly at every count & target',
        'Large tactile "Manual +1 Tap" button works even when paused',
        'Detailed History log preserves past sessions locally',
        'Revisit this tutorial anytime from Settings → Help & Guide',
      ],
    ),
  ];

  void _finishOnboarding(BuildContext context) {
    AppScope.of(context).settingsController.setHasCompletedOnboarding(true);
    if (widget.isRevisit) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.isRevisit,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: () => _finishOnboarding(context),
              child: const Text('Skip', style: TextStyle(fontSize: 15)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // App Brand Icon
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.25),
                                colorScheme.primary.withValues(alpha: 0.05),
                              ],
                            ),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 42,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            slide.badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Subtitle
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.45,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Detail Cards
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: slide.details.map((detail) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 17,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        detail,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pagination Dots & Navigation Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Next / Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () {
                        if (isLastPage) {
                          _finishOnboarding(context);
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLastPage
                            ? (widget.isRevisit ? 'Done' : 'Get Started')
                            : 'Continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
  }
}

class _TutorialSlide {
  final IconData icon;
  final String badgeText;
  final String title;
  final String subtitle;
  final List<String> details;

  const _TutorialSlide({
    required this.icon,
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.details,
  });
}
