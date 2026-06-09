import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/session_models.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session_grouping.dart';

/// Progress is **derived client-side** from the trainee's unified cross-gym history
/// (`GET /api/me/sessions`) — there is no reports API (USER_FLOWS).
class ProgressStats {
  const ProgressStats({
    required this.totalSessions,
    required this.totalVolumeKg,
    required this.totalPrs,
    required this.weeklyVolumeKg,
    required this.prSessions,
  });

  final int totalSessions;
  final double totalVolumeKg;
  final int totalPrs;

  /// Newest-last list of (weekStart, volumeKg) for the bar chart (most recent weeks).
  final List<MapEntry<DateTime, double>> weeklyVolumeKg;

  /// Recent sessions that set at least one PR (name + date + count). Per-lift PR names need the
  /// detail endpoint; the list endpoint only exposes counts, so we surface PR sessions honestly.
  final List<SessionSummary> prSessions;
}

final progressStatsProvider = FutureProvider.autoDispose<ProgressStats>((ref) async {
  final list = await ref.read(sessionRepositoryProvider).myHistory(pageSize: 100);
  final completed =
      list.items.where((s) => s.status == SessionStatus.completed).toList();

  final weeks = groupSessionsByWeek(completed);
  final weekly = [
    for (final w in weeks.take(6).toList().reversed) MapEntry(w.weekStart, w.volumeKg),
  ];

  return ProgressStats(
    totalSessions: completed.length,
    totalVolumeKg: completed.fold(0, (a, s) => a + s.totalVolumeKg),
    totalPrs: completed.fold(0, (a, s) => a + s.prCount),
    weeklyVolumeKg: weekly,
    prSessions: completed.where((s) => s.prCount > 0).take(10).toList(),
  );
});
