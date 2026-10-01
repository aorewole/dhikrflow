import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/constants.dart';
import '../../domain/recognition/recognition_config.dart';

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
                'Recognition Sensitivity & Calibration',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calibration Preset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adjusts confidence thresholds and speech sensitivity to match your environment.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'sensitive',
                            label: Text('Sensitive'),
                          ),
                          ButtonSegment(
                            value: 'balanced',
                            label: Text('Balanced'),
                          ),
                          ButtonSegment(value: 'strict', label: Text('Strict')),
                        ],
                        selected: {
                          if (settings.recognitionConfig.acceptThreshold <=
                              0.80)
                            'sensitive'
                          else if (settings.recognitionConfig.acceptThreshold >=
                              0.90)
                            'strict'
                          else
                            'balanced',
                        },
                        onSelectionChanged: (selected) {
                          final choice = selected.first;
                          if (choice == 'sensitive') {
                            settings.setRecognitionConfig(
                              RecognitionConfig.sensitive,
                            );
                          } else if (choice == 'strict') {
                            settings.setRecognitionConfig(
                              RecognitionConfig.strict,
                            );
                          } else {
                            settings.setRecognitionConfig(
                              RecognitionConfig.balanced,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Accept Confidence: ${(settings.recognitionConfig.acceptThreshold * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'VAD Floor: ${settings.recognitionConfig.speechThresholdDbfs.toInt()} dBFS',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Development Diagnostics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.memory_rounded),
                      title: const Text('Recognition Engine'),
                      subtitle: const Text(
                        'Phase 1: Deterministic Mock Engine\nPhase 4: sherpa-onnx Local ASR',
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Auto-Simulate Recitation'),
                      subtitle: const Text(
                        'Simulate voice repetition every 4 seconds in development sessions',
                      ),
                      value: settings.autoSimulateVoiceInDebug,
                      onChanged: (val) {
                        settings.setAutoSimulateVoiceInDebug(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Center(
                child: Text(
                  '${AppConstants.appName} v1.0.0 (Phase 1 Build)',
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
