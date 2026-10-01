import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/dhikr_definition.dart';
import '../../domain/recognition/recognition_profile.dart';
import '../calibration/voice_calibration_dialog.dart';
import '../session/active_session_screen.dart';

/// Pre-session detail screen for selecting targets and starting recitation.
class DhikrDetailScreen extends StatefulWidget {
  final DhikrDefinition dhikr;

  const DhikrDetailScreen({super.key, required this.dhikr});

  @override
  State<DhikrDetailScreen> createState() => _DhikrDetailScreenState();
}

class _DhikrDetailScreenState extends State<DhikrDetailScreen> {
  int? _selectedTarget;
  final TextEditingController _customTargetController = TextEditingController();
  RecognitionProfile? _voiceProfile;
  bool _useVoiceCalibration = true;

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.dhikr.defaultTarget;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVoiceProfile());
  }

  Future<void> _loadVoiceProfile() async {
    final deps = AppScope.of(context);
    final repo = deps.settingsController.repository;
    if (repo == null) return;
    final profile = await repo.getVoiceProfile(widget.dhikr.id);
    final useCalibration = await repo.getUseVoiceCalibration(widget.dhikr.id);
    if (mounted) {
      setState(() {
        _voiceProfile = profile;
        _useVoiceCalibration = useCalibration;
      });
    }
  }

  @override
  void dispose() {
    _customTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.dhikr;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.transliteration),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.isFavorite ? Colors.amber : null,
            ),
            onPressed: () {
              setState(() {
                deps.dhikrRepository.toggleFavorite(item.id);
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  // Arabic Display Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          item.arabic,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.primary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.transliteration,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.translation,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Target Selector Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Repetitions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selectedTarget == null
                            ? 'Open-ended'
                            : '$_selectedTarget count',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Target Option Chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildTargetChip(label: 'No target', value: null),
                      _buildTargetChip(label: '33', value: 33),
                      _buildTargetChip(label: '100', value: 100),
                      _buildCustomTargetChip(),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Voice Calibration & Pronunciation Section
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _voiceProfile != null && _useVoiceCalibration
                            ? Colors.green.withValues(alpha: 0.5)
                            : colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: _voiceProfile != null && _useVoiceCalibration ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _voiceProfile != null && _useVoiceCalibration
                                  ? Icons.verified_user_rounded
                                  : Icons.record_voice_over_rounded,
                              size: 22,
                              color: _voiceProfile != null && _useVoiceCalibration
                                  ? Colors.green
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _voiceProfile != null
                                    ? 'Personal Voice Profile'
                                    : 'Train App on Your Voice',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_voiceProfile != null)
                              Switch.adaptive(
                                value: _useVoiceCalibration,
                                activeTrackColor: Colors.green,
                                onChanged: (val) async {
                                  setState(() {
                                    _useVoiceCalibration = val;
                                  });
                                  await deps.settingsController.repository?.setUseVoiceCalibration(item.id, val);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_voiceProfile != null) ...[
                          Text(
                            _useVoiceCalibration
                                ? 'Active: Tailored to your pronunciation (${_voiceProfile!.calibratedAliases.length} phrases registered).'
                                : 'Disabled: Using standard generic Arabic speech detection.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Re-train Voice'),
                                onPressed: () async {
                                  final res = await VoiceCalibrationDialog.show(context, item);
                                  if (res == true) _loadVoiceProfile();
                                },
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                label: const Text('Reset', style: TextStyle(color: Colors.red)),
                                onPressed: () async {
                                  await deps.settingsController.repository?.removeVoiceProfile(item.id);
                                  _loadVoiceProfile();
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'If the default recognition misses your accent, dialect, or rapid tempo, recite 3 samples so the counter learns how you say it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.mic_rounded, size: 18),
                            label: const Text('Train My Voice (3 Recitations)'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () async {
                              final res = await VoiceCalibrationDialog.show(context, item);
                              if (res == true) _loadVoiceProfile();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Start Button Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () async {
                  await deps.sessionController.startSession(
                    dhikr: item,
                    target: _selectedTarget,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ActiveSessionScreen(),
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded),
                    SizedBox(width: 10),
                    Text(
                      'Start Hands-Free Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetChip({required String label, required int? value}) {
    final isSelected = _selectedTarget == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _selectedTarget = value;
        });
      },
    );
  }

  Widget _buildCustomTargetChip() {
    final isCustom =
        _selectedTarget != null &&
        _selectedTarget != 33 &&
        _selectedTarget != 100;
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(isCustom ? '$_selectedTarget' : 'Custom'),
      selected: isCustom,
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      onSelected: (_) => _showCustomTargetDialog(),
    );
  }

  void _showCustomTargetDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set Custom Target'),
          content: TextField(
            controller: _customTargetController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. 50, 70, 500'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(_customTargetController.text);
                if (parsed != null && parsed > 0) {
                  setState(() {
                    _selectedTarget = parsed;
                  });
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}
