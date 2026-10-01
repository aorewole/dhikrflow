import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/dhikr_session.dart';

/// Screen listing recorded past dhikr sessions and aggregate counts.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recitation History')),
      body: FutureBuilder<List<DhikrSession>>(
        future: deps.sessionRepository.getAllSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recitation history yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Completed dhikr sessions will appear here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final totalRepetitions = sessions.fold<int>(
            0,
            (sum, s) => sum + s.count,
          );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHistoryStat(
                      context,
                      label: 'TOTAL REPETITIONS',
                      value: '$totalRepetitions',
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    _buildHistoryStat(
                      context,
                      label: 'COMPLETED SESSIONS',
                      value: '${sessions.length}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Past Sessions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),

              ...sessions.map((session) {
                final dhikr = deps.dhikrRepository.getById(session.dhikrId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      foregroundColor: colorScheme.primary,
                      child: Text(
                        '${session.count}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dhikr?.transliteration ?? session.dhikrId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          dhikr?.arabic ?? '',
                          style: TextStyle(
                            fontSize: 18,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Text(
                            _formatDate(session.startedAt),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: theme.textTheme.bodySmall),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(session.duration),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (session.target != null) ...[
                            const SizedBox(width: 8),
                            Text('•', style: theme.textTheme.bodySmall),
                            const SizedBox(width: 8),
                            Text(
                              'Target: ${session.target}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: session.isTargetReached
                                    ? Colors.green
                                    : null,
                                fontWeight: session.isTargetReached
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.0,
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      final hours = dt.hour.toString().padLeft(2, '0');
      final minutes = dt.minute.toString().padLeft(2, '0');
      return 'Today $hours:$minutes';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.month}/${dt.day}/${dt.year}';
    }
  }
}
