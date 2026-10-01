/// Status lifecycle of a dhikr session.
enum SessionStatus { active, paused, completed, cancelled }

/// A recorded or in-progress recitation session.
class DhikrSession {
  final String id;
  final String dhikrId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int count;
  final int? target;
  final Duration duration;
  final SessionStatus status;

  const DhikrSession({
    required this.id,
    required this.dhikrId,
    required this.startedAt,
    this.endedAt,
    this.count = 0,
    this.target,
    this.duration = Duration.zero,
    this.status = SessionStatus.active,
  });

  bool get isTargetReached => target != null && target! > 0 && count >= target!;

  double? get progress {
    if (target == null || target! <= 0) return null;
    return (count / target!).clamp(0.0, 1.0);
  }

  int? get remaining {
    if (target == null) return null;
    final diff = target! - count;
    return diff > 0 ? diff : 0;
  }

  DhikrSession copyWith({
    String? id,
    String? dhikrId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? count,
    int? target,
    bool clearTarget = false,
    Duration? duration,
    SessionStatus? status,
  }) {
    return DhikrSession(
      id: id ?? this.id,
      dhikrId: dhikrId ?? this.dhikrId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      count: count ?? this.count,
      target: clearTarget ? null : (target ?? this.target),
      duration: duration ?? this.duration,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DhikrSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dhikrId': dhikrId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'count': count,
      'target': target,
      'durationMs': duration.inMilliseconds,
      'status': status.name,
    };
  }

  factory DhikrSession.fromJson(Map<String, dynamic> json) {
    return DhikrSession(
      id: json['id'] as String,
      dhikrId: json['dhikrId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      count: json['count'] as int? ?? 0,
      target: json['target'] as int?,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.completed,
      ),
    );
  }

  @override
  int get hashCode => id.hashCode;
}
