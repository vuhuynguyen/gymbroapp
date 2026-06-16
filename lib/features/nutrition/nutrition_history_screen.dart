import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/nutrition_models.dart';
import '../../domain/session_grouping.dart' show mondayOf;
import '../../shared/paging/paged.dart';
import '../../shared/widgets/widgets.dart';
import 'nutrition_providers.dart';
import 'nutrition_widgets.dart';

/// The trainee's nutrition tracking history — day cards grouped by week (most recent first). Tapping
/// a day opens its read-only detail. Self-scoped (cross-gym).
class NutritionHistoryScreen extends ConsumerWidget {
  const NutritionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(nutritionHistoryProvider);
    return Scaffold(
      backgroundColor: context.gb.canvas,
      body: Column(
        children: [
          GbDetailHeader(
              title: 'Tracking history', onLeading: () => context.pop()),
          Expanded(
            child: AsyncValueView(
              value: history,
              onRetry: () async => ref.invalidate(nutritionHistoryProvider),
              loading: const GbSkeletonList(count: 6, itemHeight: 64),
              data: (paged) {
                if (paged.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_menu,
                    title: 'No nutrition logged yet',
                    subtitle: 'Open Today to start following your plan.',
                  );
                }
                final groups = _byWeek(paged.items);
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(nutritionHistoryProvider.notifier).refresh(),
                  child: InfiniteScroll(
                    onLoadMore: () =>
                        ref.read(nutritionHistoryProvider.notifier).loadMore(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                          AppSpacing.gap, AppSpacing.screenH, 100),
                      children: [
                        for (final g in groups) ...[
                          _WeekHeader(label: g.label, avgPct: g.avgPct),
                          for (final d in g.days)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: NutriDayCard(
                                day: d,
                                onTap: () => context
                                    .push('/nutrition-day/${d.localDate}'),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        PagingFooter(loadingMore: paged.loadingMore),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekGroup {
  _WeekGroup(this.label, this.days);
  final String label;
  final List<NutritionDaySummary> days;

  /// Average adherence over PLAN days only — ad-hoc / no-plan days have no real % (they'd report a
  /// meaningless 100%), so they're excluded. Null when the week has no plan days.
  int? get avgPct {
    final planDays = days.where((d) => d.hasPlan).toList();
    if (planDays.isEmpty) return null;
    return (planDays.fold<int>(0, (a, d) => a + d.adherencePct) /
            planDays.length)
        .round();
  }
}

/// Group day summaries by their Monday-anchored week, labelled This week / Last week / Week of d MMM.
List<_WeekGroup> _byWeek(List<NutritionDaySummary> days) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final sorted = [...days]
    ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
  final thisMonday = mondayOf(DateTime.now());
  final buckets = <DateTime, List<NutritionDaySummary>>{};
  for (final d in sorted) {
    final date = d.date;
    if (date == null) continue;
    buckets.putIfAbsent(mondayOf(date), () => []).add(d);
  }
  final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final monday in keys)
      _WeekGroup(
        () {
          final diff = thisMonday.difference(monday).inDays ~/ 7;
          if (diff == 0) return 'This week';
          if (diff == 1) return 'Last week';
          return 'Week of ${monday.day} ${months[monday.month - 1]}';
        }(),
        buckets[monday]!,
      ),
  ];
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.label, required this.avgPct});
  final String label;
  final int? avgPct;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, AppSpacing.xs),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: gb.ink,
                  letterSpacing: -0.14)),
          const Spacer(),
          if (avgPct != null)
            Text('avg $avgPct%',
                style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: gb.grey500)
                    .tabular),
        ],
      ),
    );
  }
}
