import '../../domain/models/dhikr_session.dart';

/// Repository interface for Dhikr sessions.
abstract interface class SessionRepository {
  Future<void> saveSession(DhikrSession session);
  Future<List<DhikrSession>> getAllSessions();
  Future<List<DhikrSession>> getRecentSessions({int limit = 5});
  Future<int> getTotalCount();
  Future<void> deleteSession(String id);
}

/// In-memory implementation of [SessionRepository] for Phase 1.
class InMemorySessionRepository implements SessionRepository {
  final List<DhikrSession> _sessions = [];

  InMemorySessionRepository() {
    _seedRecentSessions();
  }

  void _seedRecentSessions() {
    final now = DateTime.now();
    _sessions.addAll([
      DhikrSession(
        id: 'seed-1',
        dhikrId: 'astaghfirullah',
        startedAt: now.subtract(const Duration(hours: 3)),
        endedAt: now.subtract(const Duration(hours: 3, minutes: -5)),
        count: 100,
        target: 100,
        duration: const Duration(minutes: 5, seconds: 12),
        status: SessionStatus.completed,
      ),
      DhikrSession(
        id: 'seed-2',
        dhikrId: 'subhanallah',
        startedAt: now.subtract(const Duration(days: 1, hours: 2)),
        endedAt: now.subtract(const Duration(days: 1, hours: 2, minutes: -2)),
        count: 33,
        target: 33,
        duration: const Duration(minutes: 2, seconds: 4),
        status: SessionStatus.completed,
      ),
      DhikrSession(
        id: 'seed-3',
        dhikrId: 'alhamdulillah',
        startedAt: now.subtract(const Duration(days: 1, hours: 1)),
        endedAt: now.subtract(const Duration(days: 1, hours: 1, minutes: -2)),
        count: 33,
        target: 33,
        duration: const Duration(minutes: 1, seconds: 58),
        status: SessionStatus.completed,
      ),
    ]);
  }

  @override
  Future<void> saveSession(DhikrSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.insert(0, session);
    }
  }

  @override
  Future<List<DhikrSession>> getAllSessions() async {
    return List.unmodifiable(_sessions);
  }

  @override
  Future<List<DhikrSession>> getRecentSessions({int limit = 5}) async {
    return List.unmodifiable(_sessions.take(limit));
  }

  @override
  Future<int> getTotalCount() async {
    return _sessions.fold<int>(0, (sum, s) => sum + s.count);
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
  }
}
