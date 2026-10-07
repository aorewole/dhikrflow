import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/dhikr_definition.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.dhikr.defaultTarget;
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
