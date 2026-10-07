import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/constants.dart';
import '../onboarding/onboarding_screen.dart';

/// Settings screen for configuring haptics, theme, and reviewing privacy guarantees.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: deps.settingsController,
        builder: (context, _) {
          final settings = deps.settingsController;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Privacy Guarantee Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            size: 20,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Privacy Promise',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.privacyPromise,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusBadge(
                          context,
                          icon: Icons.wifi_off_rounded,
                          label: 'No Internet Needed',
                        ),
                        _buildStatusBadge(
                          context,
                          icon: Icons.person_off_outlined,
                          label: 'No Accounts',
                        ),
                        _buildStatusBadge(
                          context,
                          icon: Icons.graphic_eq_outlined,
                          label: 'No Audio Saved',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Feedback & Haptics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: SwitchListTile(
                  title: const Text('Haptic Vibration'),
                  subtitle: const Text(
                    'Vibrate gently when a repetition is counted',
                  ),
                  value: settings.hapticsEnabled,
                  onChanged: (val) => settings.setHapticsEnabled(val),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Screen-Off / Background Mode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Background Recitation (Opt-In)'),
                      subtitle: const Text(
                        'Continue counting repetitions when screen is locked or app is backgrounded.',
                      ),
                      value: settings.backgroundListeningOptIn,
                      onChanged: (val) {
                        settings.setBackgroundListeningOptIn(
                          val,
                          backgroundService: deps.backgroundListeningService,
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Privacy safeguard: Disabled by default. Microphone is never active silently and immediately releases when session finishes.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Appearance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Theme', style: TextStyle(fontSize: 16)),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Auto'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selected) {
                          settings.setThemeMode(selected.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Help & Guide',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.help_outline_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: const Text('App Tour & Tutorial'),
                      subtitle: const Text(
                        'Revisit the overall introduction to hands-free dhikr and library.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnboardingScreen(isRevisit: true),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.filter_vintage_rounded,
                          color: Color(0xFFD4AF37),
                          size: 20,
                        ),
                      ),
                      title: const Text('Counting Screen Walkthrough'),
                      subtitle: const Text(
                        'Re-enable the spotlight guide on the recitation screen.',
                      ),
                      trailing: const Icon(Icons.replay_rounded),
                      onTap: () async {
                        await settings.setHasCompletedSessionTutorial(false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Walkthrough re-enabled. It will show next time you start a dhikr session.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Center(
                child: Text(
                  '${AppConstants.appName} v1.0.0 • On-Device & Privacy-First',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
