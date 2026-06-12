import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/widgets.dart';
import 'nutrition_providers.dart';
import 'nutrition_widgets.dart';

/// Read-only detail for one past day — used by both the trainee history and the coach client monitor.
/// When [clientId] is set it reads the tenant-scoped coach view (and tags client custom/edited foods
/// as unverified); otherwise the self-scoped trainee view.
class NutritionDayDetailScreen extends ConsumerWidget {
  const NutritionDayDetailScreen(
      {required this.date, this.clientId, this.clientName, super.key});

  final String date;
  final String? clientId;
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final isCoach = clientId != null;
    final async = isCoach
        ? ref.watch(clientNutritionDayProvider((clientId: clientId!, date: date)))
        : ref.watch(nutritionDayProvider(date));

    return Scaffold(
      backgroundColor: gb.canvas,
      body: Column(
        children: [
          GbDetailHeader(
            title: clientName ?? _dateTitle(date),
            onLeading: () => context.pop(),
          ),
          Expanded(
            child: AsyncValueView(
              value: async,
              onRetry: () async => ref.invalidate(isCoach
                  ? clientNutritionDayProvider((clientId: clientId!, date: date))
                  : nutritionDayProvider(date)),
              loading: const GbSkeletonList(count: 5),
              data: (log) {
                if (!log.hasPlan && log.meals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_menu,
                    title: 'No nutrition logged',
                    subtitle: 'Nothing was logged on this day.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, AppSpacing.xxl),
                  children: [
                    if (isCoach)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(_dateTitle(date),
                            style: TextStyle(fontSize: 13, color: gb.grey500)),
                      ),
                    NutriAdherenceCard(log: log),
                    const SizedBox(height: AppSpacing.gap),
                    for (final meal in log.meals) ...[
                      NutriMealHeader(meal: meal),
                      for (final item in meal.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: NutriItemRow(
                            item: item,
                            readOnly: true,
                            showUnverified: isCoach,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Text(
                        log.isClosed
                            ? 'Read-only · this day is closed.'
                            : 'Read-only',
                        style: TextStyle(fontSize: 12, color: gb.grey400),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _dateTitle(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }
}
