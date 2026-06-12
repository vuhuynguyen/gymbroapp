import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/widgets.dart';
import 'nutrition_providers.dart';
import 'nutrition_widgets.dart';

/// The Nutrition segment of the coach's client monitor — the client's recent adherence days, with a
/// missed-vs-skipped signal so a coach spots ghosting (missed) vs deliberate deviation (skipped).
/// Tapping a day opens its read-only detail (client custom/edited foods tagged unverified there).
class ClientNutritionPanel extends ConsumerWidget {
  const ClientNutritionPanel({required this.clientId, required this.clientName, super.key});
  final String clientId;
  final String clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final async = ref.watch(clientNutritionProvider(clientId));

    return AsyncValueView(
      value: async,
      onRetry: () async => ref.invalidate(clientNutritionProvider(clientId)),
      loading: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: GbSkeleton(height: 180, radius: AppRadius.md),
      ),
      data: (list) {
        if (list.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text('No nutrition plan assigned yet.',
                  style: TextStyle(fontSize: 13, color: gb.grey400)),
            ),
          );
        }

        final days = [...list.items]
          ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
        final logged = days.where((d) => d.plannedCount > 0).toList();
        final avg = logged.isEmpty
            ? 0
            : (logged.fold<int>(0, (a, d) => a + d.adherencePct) / logged.length).round();
        final missed = days.fold<int>(0, (a, d) => a + d.missedCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: GbStatTile(value: '$avg', unit: '%', label: 'Adherence', accent: gb.primary500)),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(child: GbStatTile(value: '${logged.length}', label: 'Days logged')),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                    child: GbStatTile(value: '$missed', label: 'Missed', accent: missed > 0 ? gb.danger : null)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const GbSectionTitle('Recent days'),
            const SizedBox(height: AppSpacing.sm),
            for (final d in days)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: NutriDayCard(
                  day: d,
                  onTap: () => context.push(
                      '/nutrition-day/${d.localDate}?clientId=$clientId&name=${Uri.encodeComponent(clientName)}'),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text('Missed = never logged (a gap) · skipped = a deliberate pass.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: gb.grey400)),
          ],
        );
      },
    );
  }
}
