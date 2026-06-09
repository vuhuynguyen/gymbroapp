// Pure week-grouping for the Workout Log timeline and Progress chart. Weeks are Monday-anchored in
// local time, matching the Portal/design.
import '../data/models/session_models.dart';
import 'enums.dart';

DateTime mondayOf(DateTime d) {
  final local = d.toLocal();
  final dayOnly = DateTime(local.year, local.month, local.day);
  return dayOnly.subtract(Duration(days: local.weekday - 1));
}

class SessionWeek {
  SessionWeek(this.weekStart, this.sessions);

  final DateTime weekStart;
  final List<SessionSummary> sessions;

  int get completedCount =>
      sessions.where((s) => s.status == SessionStatus.completed).length;
  double get volumeKg => sessions.fold(0, (a, s) => a + s.totalVolumeKg);
  int get prCount => sessions.fold(0, (a, s) => a + s.prCount);

  /// Weekly goal from the active plan's frequency, if any session reports one.
  int? get weeklyGoal {
    for (final s in sessions) {
      if (s.weeklyGoal != null) return s.weeklyGoal;
    }
    return null;
  }

  /// Program + plan-week label for the week-group header (design: "Hypertrophy Block A · Wk 3").
  /// Derived from the week's sessions; null when none carry a program name.
  String? get programLabel {
    String? program;
    int? week;
    for (final s in sessions) {
      program ??= s.programName;
      week ??= s.planWeek;
      if (program != null && week != null) break;
    }
    if (program == null || program.isEmpty) return null;
    return week != null ? '$program · Wk $week' : program;
  }

  String label(DateTime now) {
    final thisMonday = mondayOf(now);
    final diffWeeks = thisMonday.difference(weekStart).inDays ~/ 7;
    if (diffWeeks == 0) return 'This week';
    if (diffWeeks == 1) return 'Last week';
    return '${weekStart.day}/${weekStart.month} – week of';
  }
}

/// Group sessions (most recent first) into Monday-anchored weeks, weeks ordered newest first.
List<SessionWeek> groupSessionsByWeek(List<SessionSummary> sessions) {
  final byWeek = <int, List<SessionSummary>>{};
  final weekStarts = <int, DateTime>{};
  for (final s in sessions) {
    final started = s.startedAt;
    if (started == null) continue;
    final monday = mondayOf(started);
    final key = monday.millisecondsSinceEpoch;
    (byWeek[key] ??= []).add(s);
    weekStarts[key] = monday;
  }
  final keys = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final k in keys)
      SessionWeek(
        weekStarts[k]!,
        byWeek[k]!..sort((a, b) => (b.startedAt ?? DateTime(0)).compareTo(a.startedAt ?? DateTime(0))),
      ),
  ];
}
