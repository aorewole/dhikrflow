import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/dhikr_definition.dart';
import '../../domain/models/dhikr_session.dart';
import '../dhikr_detail/dhikr_detail_screen.dart';
import '../dhikr_library/dhikr_library_screen.dart';
import '../history/history_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../session/active_session_screen.dart';
import '../settings/settings_screen.dart';

/// The central hub of the application.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeDashboardView(),
          DhikrLibraryScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Adhkar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_toggle_off_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboardView extends StatefulWidget {
  const _HomeDashboardView();

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<_HomeDashboardView> {
  // Incrementing this key forces the draft FutureBuilder to re-execute its future.
  int _draftFetchKey = 0;
  // Incrementing this key forces the recent sessions FutureBuilder to re-execute.
  int _recentFetchKey = 0;

  // Track the previous active-session state so we can detect completion.
  bool _hadActiveSession = false;

  void _invalidateDraft() => setState(() => _draftFetchKey++);
  void _invalidateRecent() => setState(() => _recentFetchKey++);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context).sessionController;
    controller.removeListener(_onSessionChanged);
    controller.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    try {
      AppScope.of(context).sessionController.removeListener(_onSessionChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final hasActive =
        AppScope.of(context).sessionController.hasActiveSession;
    if (_hadActiveSession && !hasActive) {
      // A session just completed — refresh both sections.
      _invalidateDraft();
      _invalidateRecent();
    }
    _hadActiveSession = hasActive;
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryDhikr =
        deps.dhikrRepository.getById('astaghfirullah') ??
        deps.dhikrRepository.getAll().first;
    final favorites = deps.dhikrRepository.getFavorites();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DhikrPulse'),
        actions: [
          IconButton(
            tooltip: 'App Tour & Guide',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(isRevisit: true),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _invalidateDraft();
          _invalidateRecent();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Greeting Header
            Text(
              'Peace be upon you',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a dhikr to begin your hands-free count.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Interrupted Session Recovery Banner
            // ValueKey(_draftFetchKey) forces FutureBuilder to re-run when _invalidateDraft() is called.
            FutureBuilder<DhikrSession?>(
              key: ValueKey(_draftFetchKey),
              future: deps.sessionRepository.getActiveDraftSession(),
              builder: (context, snapshot) {
                final draft = snapshot.data;
                if (draft == null || draft.count == 0) {
                  return const SizedBox.shrink();
                }
                final draftDhikr = deps.dhikrRepository.getById(draft.dhikrId);
                if (draftDhikr == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.restore_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Interrupted Recitation Found',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${draftDhikr.transliteration} • ${draft.count} repetitions recorded',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await deps.sessionController
                                    .restoreSessionFromDraft(
                                      draft: draft,
                                      dhikr: draftDhikr,
                                    );
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ActiveSessionScreen(),
                                    ),
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Resume'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Discard recitation?'),
                                  content: Text(
                                    'This will discard ${draft.count} recorded '
                                    'repetitions of ${draftDhikr.transliteration}.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Keep'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                      ),
                                      child: const Text('Discard'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                await deps.sessionRepository.clearActiveDraftSession();
                                _invalidateDraft();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Hero Card: Quick Start Primary Dhikr
            _buildHeroQuickStart(context, primaryDhikr),
            const SizedBox(height: 28),

            // Favorites section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Adhkar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DhikrLibraryScreen(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = favorites[index];
                  return _buildFavoriteChip(context, item);
                },
              ),
            ),
            const SizedBox(height: 28),

            // Recent Sessions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Recitations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                  child: const Text('History'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<DhikrSession>>(
              key: ValueKey(_recentFetchKey),
              future: deps.sessionRepository.getRecentSessions(limit: 3),
              builder: (context, snapshot) {
                final recentSessions = snapshot.data ?? [];
                if (recentSessions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No recitations recorded yet.\nStart your first session above.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return Column(
                  children: recentSessions.map((session) {
                    final dhikr = deps.dhikrRepository.getById(session.dhikrId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          foregroundColor: colorScheme.primary,
                          child: const Icon(Icons.check_rounded, size: 20),
                        ),
                        title: Text(
                          dhikr?.transliteration ?? session.dhikrId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${session.count} repetitions • ${_formatDuration(session.duration)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          dhikr?.arabic ?? '',
                          style: const TextStyle(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroQuickStart(BuildContext context, DhikrDefinition dhikr) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.mic_rounded, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            dhikr.arabic,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              color: Colors.white,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dhikr.transliteration,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            dhikr.translation,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DhikrDetailScreen(dhikr: dhikr),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.black87),
            label: const Text(
              'Start Dhikr',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteChip(BuildContext context, DhikrDefinition dhikr) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DhikrDetailScreen(dhikr: dhikr)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dhikr.arabic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dhikr.transliteration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              dhikr.category,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
