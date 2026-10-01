import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/dhikr_session.dart';

/// Repository interface for Dhikr sessions and interruption recovery.
abstract interface class SessionRepository {
  Future<void> saveSession(DhikrSession session);
  Future<List<DhikrSession>> getAllSessions();
  Future<List<DhikrSession>> getRecentSessions({int limit = 5});
  Future<int> getTotalCount();
  Future<void> deleteSession(String id);

  /// Saves the current in-progress session to survive lifecycle interruptions.
  Future<void> saveActiveDraftSession(DhikrSession? session);

  /// Retrieves any saved in-progress session after unexpected exit.
  Future<DhikrSession?> getActiveDraftSession();

  /// Clears the active draft session when completed or discarded.
  Future<void> clearActiveDraftSession();
}

/// Persistent implementation of [SessionRepository] backed by SharedPreferences.
class LocalSessionRepository implements SessionRepository {
  static const _keyCompletedSessions = 'sessions_completed_history_json';
  static const _keyActiveDraft = 'session_active_draft_json';

  final SharedPreferences? _prefs;
  final List<DhikrSession> _sessions = [];

  LocalSessionRepository([this._prefs]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final listJson = _prefs?.getStringList(_keyCompletedSessions);
    if (listJson != null && listJson.isNotEmpty) {
      for (final itemStr in listJson) {
        try {
          final map = jsonDecode(itemStr) as Map<String, dynamic>;
          _sessions.add(DhikrSession.fromJson(map));
        } catch (_) {
          // Skip corrupt records
        }
      }
      // Sort newest first
      _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }
  }

  @override
  Future<void> saveSession(DhikrSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.insert(0, session);
    }

    _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _persistCompletedSessions();
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
    await _persistCompletedSessions();
  }

  @override
  Future<void> saveActiveDraftSession(DhikrSession? session) async {
    if (session == null) {
      await clearActiveDraftSession();
      return;
    }
    final jsonStr = jsonEncode(session.toJson());
    await _prefs?.setString(_keyActiveDraft, jsonStr);
  }

  @override
  Future<DhikrSession?> getActiveDraftSession() async {
    final jsonStr = _prefs?.getString(_keyActiveDraft);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DhikrSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearActiveDraftSession() async {
    await _prefs?.remove(_keyActiveDraft);
  }

  Future<void> _persistCompletedSessions() async {
    final listJson = _sessions.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs?.setStringList(_keyCompletedSessions, listJson);
  }
}
