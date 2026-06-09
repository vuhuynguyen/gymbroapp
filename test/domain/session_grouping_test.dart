import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/session_models.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:gymbroapp/domain/session_grouping.dart';

SessionSummary _summary(String id, DateTime startedAt, {SessionStatus status = SessionStatus.completed, double vol = 0, int pr = 0}) =>
    SessionSummary(
      id: id,
      traineeId: 't',
      source: SessionSource.fromAssignment,
      status: status,
      startedAt: startedAt,
      totalSets: 10,
      totalExercises: 3,
      totalVolumeKg: vol,
      prCount: pr,
    );

void main() {
  test('mondayOf returns the Monday of the week', () {
    expect(mondayOf(DateTime(2026, 6, 3)), DateTime(2026, 6, 1)); // Wed → Mon
    expect(mondayOf(DateTime(2026, 6, 1)), DateTime(2026, 6, 1)); // Mon → Mon
    expect(mondayOf(DateTime(2026, 6, 7)), DateTime(2026, 6, 1)); // Sun → Mon
  });

  test('groupSessionsByWeek groups Monday-anchored, newest first', () {
    final sessions = [
      _summary('a', DateTime(2026, 6, 3), vol: 1000, pr: 1), // this week
      _summary('b', DateTime(2026, 6, 2), vol: 500), // this week
      _summary('c', DateTime(2026, 5, 27), vol: 800), // prior week
    ];
    final weeks = groupSessionsByWeek(sessions);
    expect(weeks.length, 2);
    expect(weeks.first.weekStart, DateTime(2026, 6, 1));
    expect(weeks.first.sessions.length, 2);
    expect(weeks.first.volumeKg, 1500);
    expect(weeks.first.prCount, 1);
    expect(weeks.first.completedCount, 2);
    expect(weeks.last.weekStart, DateTime(2026, 5, 25));
  });
}
