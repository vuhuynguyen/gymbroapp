import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/relative_day.dart';
import '../../data/models/progress_models.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/nutrition_providers.dart';
import 'lift_widgets.dart';
import 'progress_format.dart';
import 'progress_providers.dart';
import 'today_insights.dart';

/// Progress — a glance layer over `GET /api/me/progress/overview` (PHASE-1 §3 IA), plus a
/// conditional Body section that loads independently.
///   1. This week — DARK HERO panel: headline verdict line + adherence ring
///   2. Strength — top-lift e1RM direction strip (each row taps through to the per-lift drill-down)
///   3. Consistency — 12-week blue heatmap + big % / streak
///   4. Personal records — a display-only PR teaser (brand trophy)
///   5. Body — bodyweight trend (Section 5, conditional) — watches `bodyweightSeriesProvider`,
///      renders a smoothed EMA line or a log-your-weight invite; quiet on error, never blocks §1–4.
///   6. Sleep — hours-slept trend (conditional) — same shape via `sleepSeriesProvider`, no goal line.
/// All states (loading / error / new-user hero / no-plan / thin-lift-data / no-PR) live in §5; the
/// only red the page allows is a per-lift "slipping" tag, never a page-level state.
///
/// Visual system: the "Graphite / premium-blue" Progress tab (gb-tokens.css) — a navy ink ramp on a
/// cool paper page, a deep-navy signature hero, a mono data channel for numerals/deltas, and brand
/// blue used with intent (the SectionTitle keyline, the PR trophy, the blue heatmap ramp).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(progressOverviewProvider);
    final range = ref.watch(progressRangeProvider);
    final gb = context.gb;

    return Scaffold(
      // Page background = paper (the cool blue-tinted Progress page surface).
      backgroundColor: gb.progPaper,
      body: Column(
        children: [
          GbAppHeader(
            title: 'Progress',
            actions: [
              GbBellButton(
                  onTap: () => showInfoSnack(context, 'No notifications yet'))
            ],
          ),
          Expanded(
            child: overview.when(
              // Bespoke skeleton (design `LoadingBody`), shaped to the selected view so the placeholder
              // matches what's about to load — NOT the generic GbSkeletonList.
              loading: () => _LoadingBody(range: range),
              // Neutral Graphite error panel (design `ErrorBody`) — NEVER the red ErrorRetry tile; this
              // screen's only red is a per-lift "slipping" tag (PHASE-1 §1).
              error: (e, _) => _ErrorBody(
                onRetry: () => ref.invalidate(progressOverviewProvider),
              ),
              data: (o) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(progressOverviewProvider);
                  await ref.read(progressOverviewProvider.future);
                },
                child: o.isNewUser
                    ? const _NewUserHero()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                            AppSpacing.md + 4, AppSpacing.screenH, 100),
                        children: [
                          // The view control sits under the page title: Today (snapshot + advice), or
                          // the Trends tab. On Trends the This Week glance leads, then a window
                          // sub-filter (Week / 4w / 12w) scopes the trends below it.
                          const _PeriodBar(),
                          const SizedBox(height: AppSpacing.md),
                          if (range == ProgressRange.today)
                            _TodaySection(overview: o)
                          else ...[
                            // On the Week window the current-week glance leads; on 4w / 12w a window
                            // summary strip takes its place — both sit above the window filter.
                            if (range == ProgressRange.week) ...[
                              _ThisWeekSection(overview: o),
                              const SizedBox(height: AppSpacing.md),
                            ] else ...[
                              _PeriodStatStrip(consistency: o.consistency),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            const _WindowFilter(),
                            const SizedBox(height: AppSpacing.lg),
                            _StrengthSection(lifts: o.topLifts),
                            const SizedBox(height: AppSpacing.lg),
                            // Consistency is a multi-week heatmap → only on the 4w / 12w windows.
                            if (range != ProgressRange.week) ...[
                              _ConsistencySection(consistency: o.consistency),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            _PrSection(prs: o.recentPrs),
                            const SizedBox(height: AppSpacing.lg),
                            // Section 5 (conditional). Each watches its own provider, so a slow/absent
                            // metrics/nutrition endpoint never blocks the overview above.
                            const _BodySection(),
                            const SizedBox(height: AppSpacing.lg),
                            const _SleepSection(),
                            const SizedBox(height: AppSpacing.lg),
                            const _NutritionSection(),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Graphite primitives (screen-local) ───────────────────────────────

/// An uppercase micro-label (design `.gb-label`) — app font (Inter Tight), 10px / 600 / zero tracking.
/// The Progress tab's caption channel (eyebrows, hero sub-labels, heatmap legend).
class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.color, this.fontSize});
  final String text;
  final Color? color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    var style =
        AppText.monoLabel().copyWith(color: color ?? context.gb.progInk3);
    if (fontSize != null) style = style.copyWith(fontSize: fontSize);
    return Text(text.toUpperCase(),
        style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// Section header (design `SectionTitle`) — a 3px brand keyline, an uppercase 12.5/800 ink title, and
/// a flex hairline rule. The recurring brand signature down the page. The design's optional right
/// action slot ([action]) is honoured when a section has navigation it can deliver (the Strength
/// section's all-exercises picker); the info button still trails it.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.onInfo, this.action});
  final String text;

  /// When non-null, a small "how this is counted" info button is rendered at the trailing edge of the
  /// title rule; tapping it opens the section's transparency sheet.
  final VoidCallback? onInfo;

  /// An optional right-action widget (e.g. the Strength "All exercises" affordance), rendered just
  /// before the info button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: gb.primary600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            // App font, zero tracking — uppercase section titles read tight on real hardware
            // (the design's +0.05em mono tracking was dropped with the JetBrains Mono channel).
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            color: gb.progInk,
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(child: Container(height: 1, color: gb.progLine)),
        if (action != null) ...[
          const SizedBox(width: AppSpacing.xs),
          action!,
        ],
        if (onInfo != null) ...[
          const SizedBox(width: AppSpacing.xs),
          _InfoButton(onTap: onInfo!, semanticLabel: 'How $text is counted'),
        ],
      ],
    );
  }
}

/// A small "how this is counted" info button (an outline `info` glyph in the muted ink ramp). Used on
/// each Progress section header — tapping it opens that section's transparency sheet ([_showHowSheet]).
class _InfoButton extends StatelessWidget {
  const _InfoButton({
    required this.onTap,
    required this.semanticLabel,
    this.color,
  });
  final VoidCallback onTap;
  final String semanticLabel;

  /// Glyph colour; defaults to the muted `progInk3` for the paper section headers. The hero passes a
  /// hero-ink tint so the button reads over the dark navy panel.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Semantics(
      button: true,
      label: semanticLabel,
      // The InkWell carries the gesture but is excluded from semantics, so this Semantics node is the
      // single authoritative one for the button (a clean `bySemanticsLabel` target + screen-reader node).
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: SizedBox(
            width: 26,
            height: 26,
            child:
                Icon(Icons.info_outline, size: 16, color: color ?? gb.progInk3),
          ),
        ),
      ),
    );
  }
}

/// A standard Graphite surface card — white fill, hairline `progLine` border, radius-16, soft shadow.
/// The elevated tier (design `.surf`); pass [quiet] for the recessed `.surf-quiet` (card2 fill, no
/// shadow) used by the body/nutrition invites.
class _ProgCard extends StatelessWidget {
  const _ProgCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.quiet = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final br = BorderRadius.circular(AppRadius.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: quiet ? gb.progCard2 : gb.card,
        borderRadius: br,
        border: Border.all(color: quiet ? gb.progLine2 : gb.progLine),
        boxShadow: quiet ? null : AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: br,
        // A Material ancestor so InkWell ripples on the tappable rows inside the strip card render.
        child: Material(
          color: Colors.transparent,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ── Period control (Today / Week / 4w / 12w segmented) ───────────────────────

/// The Progress page's top view control — a prog-toned segmented track (Today / Trends) under the page
/// title. Reads/writes [progressRangeProvider]: **Today** is the snapshot+advice dashboard; **Trends**
/// re-enters the last window (the window itself is picked by [_WindowFilter] below the This Week card).
/// Built inline (not the grey-toned shared [GbSegmented]) so it stays on the Graphite paper ramp.
class _PeriodBar extends ConsumerWidget {
  const _PeriodBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = ref.watch(progressRangeProvider) == ProgressRange.today;

    void setRange(ProgressRange r) =>
        ref.read(progressRangeProvider.notifier).state = r;

    return Semantics(
      label: 'Progress view',
      child: _SegmentedRow(segments: [
        _PeriodSegment(
          label: 'Today',
          selected: isToday,
          onTap: () => setRange(ProgressRange.today),
        ),
        _PeriodSegment(
          label: 'Trends',
          selected: !isToday,
          // Re-enter on the last window used (remembered), defaulting to Week.
          onTap: () => setRange(ref.read(progressTrendWindowProvider)),
        ),
      ]),
    );
  }
}

/// The trend-window filter (Week / 4w / 12w) — light underline sub-tabs shown beneath the This Week
/// card on the Trends view. Picks the look-back window and remembers it (so toggling Today <-> Trends
/// restores it).
class _WindowFilter extends ConsumerWidget {
  const _WindowFilter();

  static const _windows = [
    ProgressRange.week,
    ProgressRange.fourWeek,
    ProgressRange.twelveWeek,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(progressRangeProvider);
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _windows.length; i++) ...[
            if (i > 0) const SizedBox(width: 22),
            _WindowTab(
              label: _windows[i].label,
              selected: _windows[i] == selected,
              onTap: () {
                ref.read(progressTrendWindowProvider.notifier).state =
                    _windows[i];
                ref.read(progressRangeProvider.notifier).state = _windows[i];
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// A light underline sub-tab for the trend window — plain text with a brand underline under the active
/// one, so the window reads as a secondary refinement of the Trends view.
class _WindowTab extends StatelessWidget {
  const _WindowTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? gb.primary600 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: AppText.mono(const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            )).copyWith(color: selected ? gb.primary600 : gb.progInk3),
          ),
        ),
      ),
    );
  }
}

/// The pill-container that frames a row of [_PeriodSegment]s — shared by the top Today/Trends tabs and
/// the trend-window sub-filter so both read as the same control.
class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({required this.segments});
  final List<Widget> segments;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: gb.progCard2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: gb.progLine),
      ),
      child: Row(
        children: [for (final s in segments) Expanded(child: s)],
      ),
    );
  }
}

/// One segment of the period control — a raised white pill when selected, transparent otherwise.
class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? gb.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm - 3),
          boxShadow: selected ? AppShadows.sm : null,
        ),
        child: Text(
          label,
          // App font, tight tracking — the data-channel period labels read tight (no custom font).
          style: AppText.mono(const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          )).copyWith(color: selected ? gb.progInk : gb.progInk3),
        ),
      ),
    );
  }
}

// ── Today dashboard (snapshot + grounded advice) ─────────────────────────────

/// The **Today** view — a snapshot of today's logged facts (calories, protein, sleep, weight, weekly
/// workouts) plus grounded coaching tips. All advice is computed on-device by [buildTodayInsights]
/// from already-fetched providers (no new endpoint); nothing is fabricated — an unlogged metric simply
/// drops its tile/tip. Watches the shared nutrition/check-in/weight providers so it reflects what the
/// user logged elsewhere this session.
class _TodaySection extends ConsumerWidget {
  const _TodaySection({required this.overview});
  final ProgressOverview overview;

  static String _trim(double v) =>
      v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final nutrition = ref.watch(todayNutritionProvider).valueOrNull;
    final checkin = ref.watch(checkinProvider).valueOrNull;
    final weight = ref.watch(bodyweightSeriesProvider).valueOrNull;

    final insights = buildTodayInsights(
      nutrition: nutrition,
      checkin: checkin,
      overview: overview,
      weightTrend: weight == null
          ? const <double>[]
          : [for (final p in weight.points) p.value.toDouble()],
      now: DateTime.now(),
    );
    final s = insights.snapshot;

    // Calories + protein + carbs + fat (all-source) merge into one full-width macro card at the top of
    // the glance; the remaining facts (sleep, weight, weekly workouts) stay as the small tile grid.
    final hasMacros = s.consumedKcal != null;
    final tiles = <Widget>[
      if (s.sleepHours != null)
        _SnapshotTile(
            icon: Icons.bedtime_rounded,
            accent: gb.secondary300,
            label: 'Sleep',
            value: _trim(s.sleepHours!),
            sub: 'h last night'),
      if (s.weightKg != null)
        _SnapshotTile(
            icon: Icons.monitor_weight_rounded,
            accent: gb.emeraldInk,
            label: 'Weight',
            value: _trim(s.weightKg!),
            sub: 'kg'),
      if (s.sessionsThisWeek != null)
        _SnapshotTile(
          icon: Icons.fitness_center_rounded,
          accent: gb.progBrandInk,
          label: 'This week',
          value: '${s.sessionsThisWeek}',
          sub: s.weeklyGoal != null ? '/ ${s.weeklyGoal} done' : 'done',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMacros || tiles.isNotEmpty) ...[
          const _MonoLabel('Today at a glance'),
          const SizedBox(height: AppSpacing.sm),
          if (hasMacros) ...[
            _MacroGlanceCard(snapshot: s),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (tiles.isNotEmpty) _snapshotGrid(tiles),
          const SizedBox(height: AppSpacing.lg),
        ],
        const _MonoLabel('Advice'),
        const SizedBox(height: AppSpacing.sm),
        if (insights.tips.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: gb.progField,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: gb.progLine),
            ),
            child: Text(
              'Log a meal, your sleep or a workout to see today’s advice.',
              style: TextStyle(fontSize: 13, height: 1.4, color: gb.progInk3),
            ),
          )
        else
          for (final t in insights.tips) ...[
            _TipCard(tip: t),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

/// Lay the snapshot tiles out in an even 3-column grid (equal widths, last row left-aligned) — tidier
/// than a Wrap when the count isn't a multiple of three.
Widget _snapshotGrid(List<Widget> tiles, {int cols = 3}) {
  final rows = <Widget>[];
  for (var i = 0; i < tiles.length; i += cols) {
    final children = <Widget>[];
    for (var c = 0; c < cols; c++) {
      if (c > 0) children.add(const SizedBox(width: AppSpacing.sm));
      final idx = i + c;
      children.add(Expanded(
          child: idx < tiles.length ? tiles[idx] : const SizedBox.shrink()));
    }
    rows.add(IntrinsicHeight(
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ));
    if (i + cols < tiles.length)
      rows.add(const SizedBox(height: AppSpacing.sm));
  }
  return Column(children: rows);
}

/// One fact tile in the Today snapshot grid — a tinted, metric-coloured icon chip over the value.
class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 1),
      decoration: BoxDecoration(
        color: gb.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: gb.progLine),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(height: 10),
          _MonoLabel(label, fontSize: 9.5),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.5,
                  color: gb.progInk)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: gb.progInk3)),
        ],
      ),
    );
  }
}

/// The multi-week (4w / 12w) headline glance — a compact stat strip that takes the Trends hero slot in
/// place of the Week-only This Week card. Summarises the window from the consistency payload: total
/// sessions and sessions/week, plus — when a goal is set — the % of weeks on goal and the current
/// streak. All real data; the goal-relative tiles simply drop when there's no goal.
class _PeriodStatStrip extends StatelessWidget {
  const _PeriodStatStrip({required this.consistency});
  final Consistency consistency;

  @override
  Widget build(BuildContext context) {
    final weeks = consistency.windowWeeks <= 0 ? 1 : consistency.windowWeeks;
    final sessions =
        consistency.days.fold<int>(0, (sum, d) => sum + d.sessionCount);
    final perWeek = sessions / weeks;
    final pct = consistency.consistencyPct;
    final streak = consistency.currentStreakWeeks;

    String trim(double v) => v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);

    return _snapshotGrid(
      <Widget>[
        _PeriodStat(value: '$sessions', label: 'Sessions'),
        _PeriodStat(value: trim(perWeek), label: 'Per week'),
        if (pct != null) ...[
          _PeriodStat(value: '$pct%', label: 'Weeks on goal'),
          _PeriodStat(value: '${streak}w', label: 'Streak'),
        ],
      ],
      cols: 2,
    );
  }
}

/// One tile in the multi-week stat strip — a big value over an uppercase micro-label, in the same
/// white card as [_SnapshotTile] (minus the icon) so the two stat surfaces read as one family.
class _PeriodStat extends StatelessWidget {
  const _PeriodStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 1, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: gb.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: gb.progLine),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.5,
                color: gb.progInk,
              )),
          const SizedBox(height: 5),
          _MonoLabel(label, fontSize: 9.5),
        ],
      ),
    );
  }
}

/// The merged macros card at the top of the Today glance — calories + protein + carbs + fat in one row
/// (all-source: planned + ad-hoc), so the day's fuel reads at a glance rather than as separate tiles.
class _MacroGlanceCard extends StatelessWidget {
  const _MacroGlanceCard({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final s = snapshot;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: gb.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: gb.progLine),
        boxShadow: AppShadows.sm,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _cell(gb, 'Calories', '${s.consumedKcal}',
                  s.targetKcal != null ? '/ ${s.targetKcal} kcal' : 'kcal'),
            ),
            _divider(gb),
            Expanded(child: _cell(gb, 'Protein', '${s.proteinG ?? 0}', 'g')),
            _divider(gb),
            Expanded(child: _cell(gb, 'Carbs', '${s.carbsG ?? 0}', 'g')),
            _divider(gb),
            Expanded(child: _cell(gb, 'Fat', '${s.fatG ?? 0}', 'g')),
          ],
        ),
      ),
    );
  }

  Widget _divider(GbColors gb) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs - 2),
        color: gb.progLine,
      );

  Widget _cell(GbColors gb, String label, String value, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonoLabel(label, fontSize: 9.5),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.5,
                  color: gb.progInk)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: gb.progInk3)),
        ],
      );
}

/// One advice tip — a tinted card whose colour/icon follows the tip's [TipTone].
class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});
  final TodayTip tip;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Richer accent families than the muted prog* tones so the advice list reads clearly: emerald for
    // wins, amber for cautions, brand blue for neutral nudges.
    final (Color fg, Color bg, IconData icon) = switch (tip.tone) {
      TipTone.good => (
          gb.emeraldInk,
          gb.emeraldSoft,
          Icons.check_circle_rounded
        ),
      TipTone.warn => (gb.amberInk, gb.amberSoft, Icons.warning_amber_rounded),
      TipTone.info => (
          gb.progBrandInk,
          gb.progBrandSoft,
          Icons.lightbulb_rounded
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: fg.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: fg),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: gb.progInk)),
                const SizedBox(height: 2),
                Text(tip.detail,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.35, color: gb.progInk2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── "How this is counted" transparency sheets ────────────────────────────────

/// The four Progress sections that carry a "how this is counted" transparency sheet.
enum _HowCounted { thisWeek, strength, consistency, nutrition }

/// Title + plain-language body for each section's transparency sheet. The copy is intentionally
/// apostrophe-free and phrased "over the selected period" so it stays accurate with the period control.
extension _HowCountedCopy on _HowCounted {
  String get title => switch (this) {
        _HowCounted.thisWeek => 'This Week',
        _HowCounted.strength => 'Strength',
        _HowCounted.consistency => 'Consistency',
        _HowCounted.nutrition => 'Nutrition',
      };

  String get body => switch (this) {
        _HowCounted.thisWeek =>
          'Completed sessions in the current week (Mon to Sun, your time zone) versus your weekly plan goal. Rest days count — the goal is number of sessions, not every day.',
        _HowCounted.strength =>
          'Estimated 1RM per lift from your top working set (Epley formula), over the selected period. A lift appears once it has at least 4 qualifying sessions. Flat / has not moved means no new best in your last few exposures.',
        _HowCounted.consistency =>
          'The percent of weeks you hit your session goal, over the selected period. The grid marks each day you trained. With no goal set, we show your session count instead.',
        _HowCounted.nutrition =>
          'Calories you logged each day (all foods). The dashed line is your plan calories on days that have a plan — days with no plan show your intake only.',
      };
}

/// Opens the section's "how this is counted" transparency sheet (reuses the app [showGbSheet] pattern,
/// with a [GbSheetHeader] + the plain-language body).
void _showHowSheet(BuildContext context, _HowCounted section) {
  showGbSheet<void>(
    context,
    builder: (_) => _HowCountedSheet(section: section),
  );
}

/// The transparency sheet body — a sheet header ("How <Section> is counted") + the section's plain
/// explanation. Graphite tokens, app font; no numbers, no fabricated data.
class _HowCountedSheet extends StatelessWidget {
  const _HowCountedSheet({required this.section});
  final _HowCounted section;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GbSheetHeader(title: 'How ${section.title} is counted'),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            section.body,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: gb.progInk2),
          ),
        ],
      ),
    );
  }
}

// ── Section 1 — This week (DARK HERO: headline verdict + adherence ring) ─────

/// Composes the 5-second verdict line from this week's adherence + the top lifts, then renders the
/// adherence ring (hidden in the no-plan state, which shows the raw completed count instead). The
/// design's signature dark hero panel: deep-navy gradient, radius 18, a verdict headline (with the
/// "trending up" fragment in hero-pos green), a hairline divider, then the ring + caption (or the big
/// raw-count number in the no-plan variant).
class _ThisWeekSection extends StatelessWidget {
  const _ThisWeekSection({required this.overview});
  final ProgressOverview overview;

  @override
  Widget build(BuildContext context) {
    final week = overview.thisWeek;
    final hasPlan = week.hasActivePlan && (week.goal ?? 0) > 0;
    const heroFg = Colors.white;
    const heroMut = Color(0xBDDFE9FF); // --hero-mut (rgba(223,233,255,0.74))
    const heroLine = Color(0x2EFFFFFF); // --hero-line (rgba(255,255,255,0.18))
    const heroTrack =
        Color(0x38FFFFFF); // --hero-track (rgba(255,255,255,0.22))
    const heroRing = Color(0xFFCFE0FF); // --hero-ring
    const heroShadow = [
      BoxShadow(
        color: Color(0x59182BBE), // 0 18px 36px -22px rgba(33,72,190,0.5)
        blurRadius: 36,
        spreadRadius: -22,
        offset: Offset(0, 18),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: GbColors.progressHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg - 2), // 18
        boxShadow: heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Eyebrow + the "how this is counted" info button. The button is tinted on hero ink
            // (heroMut) since the hero sits on the dark navy panel, not the paper page.
            Row(
              children: [
                const Expanded(child: _MonoLabel('This week', color: heroMut)),
                _InfoButton(
                  onTap: () => _showHowSheet(context, _HowCounted.thisWeek),
                  semanticLabel: 'How This Week is counted',
                  color: heroMut,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // The verdict headline — green (hero-pos) or neutral white, NEVER red (PHASE-1 §1 card 1a).
            _HeadlineText(
                overview: overview, fg: heroFg, pos: const Color(0xFF74E6B0)),
            const SizedBox(height: AppSpacing.md + 2),
            Container(height: 1, color: heroLine),
            const SizedBox(height: AppSpacing.md + 2),
            if (hasPlan)
              Row(
                children: [
                  GbRing(
                    value: week.ringValue,
                    size: 86,
                    stroke: 7,
                    gradient: const [heroRing, heroRing],
                    trackColor: heroTrack,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${week.completedSessions}',
                          style: AppText.mono(const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          )).copyWith(color: heroFg),
                        ),
                        TextSpan(
                          text: '/${week.goal}',
                          style: AppText.mono(const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          )).copyWith(color: heroMut),
                        ),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _goalCaption(week),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.16,
                            color: heroFg,
                          ),
                        ),
                        const SizedBox(height: 7),
                        _MonoLabel(_daysLeftCaption(week), color: heroMut),
                      ],
                    ),
                  ),
                ],
              )
            else
              // No active plan → hide the ring, show the raw completed count (PHASE-1 §5).
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${week.completedSessions}',
                    style: AppText.mono(const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      height: 0.86,
                    )).copyWith(color: heroFg),
                  ),
                  const SizedBox(width: AppSpacing.md + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MonoLabel(
                          week.completedSessions == 1
                              ? 'Session this week'
                              : 'Sessions this week',
                          color: heroMut,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Get a plan assigned to track a weekly goal — your training still counts.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: heroMut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The verdict headline as rich text — a neutral or "lift up" lead with the up-trend fragment painted
/// in hero-pos green, the rest white. Never red (PHASE-1 §1). The composition logic is unchanged from
/// the prior screen ([_headline]); only the per-fragment colouring is new.
class _HeadlineText extends StatelessWidget {
  const _HeadlineText(
      {required this.overview, required this.fg, required this.pos});
  final ProgressOverview overview;
  final Color fg;
  final Color pos;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: -0.3,
      color: fg,
    );
    final up = overview.topLifts
        .where((l) => l.direction == LiftTrendDirection.up)
        .map((l) => _shortName(l.exerciseName))
        .where((n) => n.isNotEmpty)
        .take(2)
        .toList();
    final week = overview.thisWeek;
    final sessionPart = (week.hasActivePlan && week.goal != null)
        ? '${week.completedSessions} of ${week.goal} this week'
        : (week.completedSessions == 1
            ? '1 session this week'
            : '${week.completedSessions} sessions this week');

    if (up.isNotEmpty) {
      final lifts = up.length == 1 ? up.first : up.join(' & ');
      // "<lifts> up · <session>" with the " up" fragment in hero-pos green.
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: '$lifts '),
          TextSpan(
            text: 'up',
            style: TextStyle(color: pos, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' · $sessionPart'),
        ]),
        style: base,
      );
    }
    return Text(_capitalize(sessionPart), style: base);
  }
}

/// "1 session to your goal" / "On track" — the right-of-ring lead line in the planned hero.
String _goalCaption(WeekAdherence week) {
  final goal = week.goal ?? 0;
  final remaining = goal - week.completedSessions;
  if (remaining <= 0) return 'Goal reached this week';
  return remaining == 1
      ? '1 session to your goal'
      : '$remaining sessions to your goal';
}

/// "2 days left · rest days count" / "Last day · rest days count" — a forgiving nudge, only with a plan.
String _daysLeftCaption(WeekAdherence week) {
  final start = week.weekStart;
  if (start == null) return 'Rest days count';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekEnd =
      DateTime(start.year, start.month, start.day).add(const Duration(days: 6));
  final left = weekEnd.difference(today).inDays;
  final leftPart =
      left <= 0 ? 'Last day' : (left == 1 ? '1 day left' : '$left days left');
  return '$leftPart · rest days count';
}

// ── Section 2 — Strength (top-lift direction strip + muscle / exercise filters) ──

/// The canonical muscle-group buckets, in display order. The chip row renders ONLY the subset of these
/// that the user has actually trained (derived from the lifts' `primaryMuscleGroup`), so it never shows
/// a dead chip. Stored lowercase to match the canonicalized wire token; [_muscleLabel] gives the chip
/// caption.
const _muscleOrder = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];

/// Title-case label for a muscle token's chip / picker group header.
String _muscleLabel(String token) =>
    token.isEmpty ? token : '${token[0].toUpperCase()}${token.substring(1)}';

/// Section 2 — Strength. A [ConsumerStatefulWidget] so it can hold the selected muscle-chip state and
/// watch [strengthLiftsProvider] (the wider per-lift list behind the home top-3 glance). The default
/// "All" chip keeps the EXISTING top-3 glance strip (driven by the overview's [topLifts]) unchanged.
/// Selecting a muscle chip swaps in the filtered lift list for that group (reusing [_LiftRow], honest
/// about thin lifts). The header's right-action opens a searchable all-exercises picker.
class _StrengthSection extends ConsumerStatefulWidget {
  const _StrengthSection({required this.lifts});

  /// The overview's honesty-gated top lifts — the "All" glance strip (unchanged from Phase 1).
  final List<LiftDirection> lifts;

  @override
  ConsumerState<_StrengthSection> createState() => _StrengthSectionState();
}

class _StrengthSectionState extends ConsumerState<_StrengthSection> {
  /// The selected muscle chip, or null for "All" (the default — the unchanged top-3 glance strip).
  String? _muscle;

  @override
  Widget build(BuildContext context) {
    final liftsAsync = ref.watch(strengthLiftsProvider);
    // The trained muscle set drives the chip row; null while loading/errored (chips simply hide).
    final allLifts = liftsAsync.valueOrNull?.lifts ?? const <StrengthLift>[];
    final trained = _trainedMuscles(allLifts);

    // If the selected chip's group vanished (period change dropped it), fall back to "All" so we never
    // render a selected-but-dead chip.
    final selected =
        (_muscle != null && trained.contains(_muscle)) ? _muscle : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Strength',
          onInfo: () => _showHowSheet(context, _HowCounted.strength),
          // The all-exercises picker is offered only once there are lifts to list.
          action: allLifts.isEmpty
              ? null
              : _AllExercisesAction(
                  onTap: () => _showAllExercisesSheet(context, allLifts),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Muscle chip row — "All" plus only the trained groups (never a dead chip). Hidden entirely
        // until at least one trained group is known.
        if (trained.isNotEmpty) ...[
          _MuscleChipRow(
            trained: trained,
            selected: selected,
            onSelect: (m) => setState(() => _muscle = m),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // "All" → the unchanged top-3 glance strip; a muscle → that group's filtered lift list.
        if (selected == null)
          _GlanceStrip(lifts: widget.lifts)
        else
          _MuscleLiftList(
            lifts: [
              for (final l in allLifts)
                if (l.primaryMuscleGroup == selected) l
            ],
          ),
      ],
    );
  }

  /// The set of trained muscle groups present in [lifts] (non-null tokens only), in canonical display
  /// order, with any unexpected server token appended after the known set — so the chip row is honest
  /// (only trained groups) and stable.
  static List<String> _trainedMuscles(List<StrengthLift> lifts) {
    final present = <String>{
      for (final l in lifts)
        if (l.primaryMuscleGroup != null) l.primaryMuscleGroup!
    };
    return [
      for (final m in _muscleOrder)
        if (present.contains(m)) m,
      // Any non-canonical token the server sent still gets a chip (kept stable + de-duped).
      for (final m in present)
        if (!_muscleOrder.contains(m)) m,
    ];
  }
}

/// The "All" top-3 glance strip (unchanged from Phase 1): the overview's honesty-gated [topLifts] in a
/// surface card, with the stall callout row. Extracted verbatim so the "All" chip preserves the exact
/// existing behavior.
class _GlanceStrip extends StatelessWidget {
  const _GlanceStrip({required this.lifts});
  final List<LiftDirection> lifts;

  @override
  Widget build(BuildContext context) {
    if (lifts.isEmpty) {
      return const _QuietCard(
        text: 'Log a few working sets to see your strength trend.',
      );
    }
    final gb = context.gb;
    final stall = _stallCallout(lifts);
    return _ProgCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < lifts.length; i++) ...[
            if (i > 0) _RuleInset(color: gb.progLine2),
            _LiftRow(lift: lifts[i]),
          ],
          // The stall callout row — a warn dot + "… time to change something" (PHASE-1 §1).
          if (stall != null) ...[
            _RuleInset(color: gb.progLine2),
            _StallCallout(lift: stall),
          ],
        ],
      ),
    );
  }

  /// The first stalled flat lift, if any — drives the design's amber stall callout row.
  static LiftDirection? _stallCallout(List<LiftDirection> lifts) {
    for (final l in lifts) {
      if (l.direction == LiftTrendDirection.flat &&
          l.stalled &&
          l.stallSessions > 0) {
        return l;
      }
    }
    return null;
  }
}

/// The filtered lift list for a selected muscle chip — every lift in that group (reusing [_LiftRow],
/// which is honest about thin lifts: a `hasTrend == false` lift shows name + e1RM + "N sessions" with
/// no direction tag / spark). An empty group shows the existing honest empty state (the [_QuietCard]).
class _MuscleLiftList extends StatelessWidget {
  const _MuscleLiftList({required this.lifts});
  final List<StrengthLift> lifts;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    if (lifts.isEmpty) {
      return const _QuietCard(
        text: 'Log a few working sets to see your strength trend.',
      );
    }
    return _ProgCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < lifts.length; i++) ...[
            if (i > 0) _RuleInset(color: gb.progLine2),
            _LiftRow.fromStrength(lifts[i]),
          ],
        ],
      ),
    );
  }
}

/// The horizontal muscle chip row under the Strength title: "All" plus one chip per trained group. A
/// scrollable single-line row so a long set never overflows. Reuses the shared prog tints; the selected
/// chip fills primary, the rest read as quiet outlined pills.
class _MuscleChipRow extends StatelessWidget {
  const _MuscleChipRow({
    required this.trained,
    required this.selected,
    required this.onSelect,
  });

  /// Trained muscle tokens, display-ordered.
  final List<String> trained;

  /// The selected token, or null for "All".
  final String? selected;

  /// Called with null for "All", or a muscle token for a group chip.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: [
          _ProgChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final m in trained) ...[
            const SizedBox(width: AppSpacing.xs),
            _ProgChip(
              label: _muscleLabel(m),
              selected: selected == m,
              onTap: () => onSelect(m),
            ),
          ],
        ],
      ),
    );
  }
}

/// A prog-toned selectable filter pill (primary fill when selected, quiet outline otherwise) — the
/// Strength muscle filter's chip. Built inline (not the grey-toned shared [GbChip]) so it stays on the
/// Graphite paper ramp.
class _ProgChip extends StatelessWidget {
  const _ProgChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final fg = selected ? Colors.white : gb.progInk2;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? gb.primary600 : gb.card,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? gb.primary600 : gb.progLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.13,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Strength header right-action — a small "All exercises" text+chevron affordance that opens the
/// searchable all-exercises picker. Lives in the [_SectionTitle] action slot.
class _AllExercisesAction extends StatelessWidget {
  const _AllExercisesAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Semantics(
      button: true,
      label: 'All exercises',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'All exercises',
                  style: AppText.mono(const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  )).copyWith(color: gb.progBrandInk),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 15, color: gb.progBrandInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the searchable all-exercises picker (reusing the app [showGbSheet] pattern, scrollable). Lists
/// every performed lift grouped by muscle group, each with its current e1RM; tapping one routes to the
/// EXISTING per-lift drill-down (`/progress/lift/:exerciseId`) — no new detail screen.
void _showAllExercisesSheet(BuildContext context, List<StrengthLift> lifts) {
  showGbSheet<void>(
    context,
    scrollable: true,
    builder: (_) => _AllExercisesSheet(lifts: lifts),
  );
}

/// The searchable all-exercises picker (reuses [showGbSheet], scrollable). Lists every performed lift
/// grouped by muscle group (display-ordered, null/unresolved group last under "Other"), each with its
/// current e1RM; a live search field filters by lift name. Tapping a lift pops the sheet then routes to
/// the EXISTING per-lift drill-down (`/progress/lift/:exerciseId`) — no new detail screen is added.
class _AllExercisesSheet extends StatefulWidget {
  const _AllExercisesSheet({required this.lifts});
  final List<StrengthLift> lifts;

  @override
  State<_AllExercisesSheet> createState() => _AllExercisesSheetState();
}

class _AllExercisesSheetState extends State<_AllExercisesSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Lifts matching the current query (case-insensitive name contains), grouped by muscle in display
  /// order with an "Other" bucket last for null/unresolved groups. Within a group, the server's e1RM
  /// desc order is preserved.
  List<(String, List<StrengthLift>)> _grouped() {
    final q = _query.trim().toLowerCase();
    final matched = [
      for (final l in widget.lifts)
        if (q.isEmpty || (l.exerciseName ?? '').toLowerCase().contains(q)) l
    ];
    final byMuscle = <String, List<StrengthLift>>{};
    for (final l in matched) {
      // Null/unresolved → an "other" bucket (never a fabricated muscle group).
      final key = l.primaryMuscleGroup ?? 'other';
      (byMuscle[key] ??= []).add(l);
    }
    final order = [..._muscleOrder, 'other'];
    return [
      for (final m in order)
        if (byMuscle[m] != null) (m, byMuscle[m]!),
      // Any non-canonical group, appended after the known set.
      for (final e in byMuscle.entries)
        if (!order.contains(e.key)) (e.key, e.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final groups = _grouped();
    // Cap the sheet at ~80% of screen height; the list scrolls within.
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GbSheetHeader(
              title: 'All exercises',
              subtitle: 'Tap a lift to see its trend.',
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            GbSearchField(
              controller: _search,
              hint: 'Search exercises…',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: groups.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text(
                        'No exercises match "${_query.trim()}".',
                        style: TextStyle(
                            fontSize: 13.5, height: 1.5, color: gb.progInk3),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final (muscle, ls) in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 6, 0, 6),
                            child: _MonoLabel(
                              muscle == 'other'
                                  ? 'Other'
                                  : _muscleLabel(muscle),
                              color: gb.progInk3,
                            ),
                          ),
                          for (final l in ls)
                            _AllExercisesRow(
                              lift: l,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/progress/lift/${l.exerciseId}');
                              },
                            ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the all-exercises picker — the lift name + its current e1RM (mono), a trailing chevron.
class _AllExercisesRow extends StatelessWidget {
  const _AllExercisesRow({required this.lift, required this.onTap});
  final StrengthLift lift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lift.exerciseName ?? 'Exercise',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.14,
                    color: gb.progInk,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: fmtKg(lift.currentE1rmKg),
                    style: AppText.mono(const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    )).copyWith(color: gb.progInk2),
                  ),
                  TextSpan(
                    text: ' kg',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: gb.progInk3,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: gb.progInk4),
            ],
          ),
        ),
      ),
    );
  }
}

/// A hairline rule inset to match the card's horizontal row padding (design `.rule` with `0 14px`).
class _RuleInset extends StatelessWidget {
  const _RuleInset({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(height: 1, color: color));
}

/// A single lift row: name · big e1RM (+ "est. 1RM") · gradient sparkline (donut endpoint; dots-only
/// for <4 pts) · the mono DirTag (PHASE-1 §1 card 2). Tapping it opens the per-lift e1RM drill-down
/// (`/progress/lift/:exerciseId`, Phase 2). Wrapped in an [InkWell] so the ripple and the
/// dividers/padding inside the strip card stay intact.
///
/// Two construction paths so the SAME visual serves both the home top-3 glance (a [LiftDirection], all
/// honesty-gated so always a trend) and the muscle-group filtered list (a [StrengthLift], which may be
/// thin). The named `.lift` ctor is the legacy [LiftDirection] path (unchanged); `.fromStrength`
/// adapts a [StrengthLift] and respects its `hasTrend` gate — a thin lift shows name + e1RM +
/// "N sessions" with NO direction tag and NO sparkline (never a fabricated trend, WIRE CONTRACT).
class _LiftRow extends StatelessWidget {
  _LiftRow({required LiftDirection lift})
      : exerciseId = lift.exerciseId,
        exerciseName = lift.exerciseName,
        currentE1rmKg = lift.currentE1rmKg,
        direction = lift.direction,
        stalled = lift.stalled,
        stallSessions = lift.stallSessions,
        sparkE1rmKg = lift.sparkE1rmKg,
        // The home strip is honesty-gated server-side (≥4 sessions), so it always shows the trend.
        hasTrend = true,
        sessionCount = null;

  _LiftRow.fromStrength(StrengthLift lift)
      : exerciseId = lift.exerciseId,
        exerciseName = lift.exerciseName,
        currentE1rmKg = lift.currentE1rmKg,
        direction = lift.direction,
        stalled = lift.stalled,
        stallSessions = lift.stallSessions,
        sparkE1rmKg = lift.sparkE1rmKg,
        hasTrend = lift.hasTrend,
        sessionCount = lift.sessionCount;

  final String exerciseId;
  final String? exerciseName;
  final double currentE1rmKg;
  final LiftTrendDirection direction;
  final bool stalled;
  final int stallSessions;
  final List<double> sparkE1rmKg;

  /// When false (a thin lift), the row drops the direction tag + sparkline and shows the honest
  /// "N sessions" caption instead — never a fabricated trend.
  final bool hasTrend;

  /// Session count for the no-trend caption; null on the legacy home-strip path (always a trend there).
  final int? sessionCount;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final spark = sparkE1rmKg;
    // On the legacy home-strip path (always-trend), a thin spark still degrades the *value* line to a
    // "log a few more" hint (the original behavior). For the muscle-filtered path the honesty gate is
    // explicit (`hasTrend`): a thin lift shows e1RM + "N sessions" and no spark/tag at all.
    final fewSpark = spark.length < 4;
    final showValueHint = hasTrend && sessionCount == null && fewSpark;
    return InkWell(
      onTap: () => context.push('/progress/lift/$exerciseId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exerciseName ?? 'Exercise',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.14,
                      color: gb.progInk,
                    ),
                  ),
                  // Design: 4px above the thin-data hint, 5px above the e1RM row.
                  SizedBox(height: showValueHint ? 4 : 5),
                  if (showValueHint)
                    _MonoLabel('Log a few more to see trend',
                        color: gb.progInk3, fontSize: 10.5)
                  else
                    // Big e1RM with a kg unit suffix + an "est. 1RM" micro-label — always honest data.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: fmtKg(currentE1rmKg),
                              style: AppText.mono(const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                              )).copyWith(color: gb.progInk),
                            ),
                            TextSpan(
                              text: ' kg',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: gb.progInk3,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        _MonoLabel('est. 1RM', color: gb.progInk4, fontSize: 9),
                        // A thin (no-trend) lift annotates the honest session count inline instead of
                        // a (forbidden) fabricated direction tag.
                        if (!hasTrend && sessionCount != null) ...[
                          const SizedBox(width: 8),
                          _MonoLabel(
                            '${sessionCount!} ${sessionCount == 1 ? 'session' : 'sessions'}',
                            color: gb.progInk3,
                            fontSize: 9,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            // Sparkline + DirTag ONLY when there's a real trend. A thin lift shows neither — name +
            // e1RM + "N sessions" only (WIRE CONTRACT: never fabricate a direction for a thin lift).
            if (hasTrend) ...[
              const SizedBox(width: AppSpacing.sm),
              // Gradient-filled sparkline (donut endpoint), or dots-only for thin spark data.
              // Design `Sparkline width={92} height={36}`.
              SizedBox(
                width: 92,
                height: 36,
                child: _Sparkline(
                  points: spark,
                  color: sparkColor(gb, direction),
                  cardColor: gb.card,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Design right-aligns the DirTag in a ~78px trailing slot so the deltas line up. As the
              // last row child it already trails; a 78px min-width box (right-aligned) reserves that
              // column, and Flexible lets a longer tag shrink rather than overflow (the Expanded name
              // absorbs the rest).
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 78),
                    child: LiftDirectionTag(
                      direction: direction,
                      stalled: stalled,
                      stallSessions: stallSessions,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The strength stall callout row (design): a small warn dot + "Squat hasn't moved in N sessions —
/// time to change something", with the closing fragment in warn amber. Honest — only shown when a top
/// lift is genuinely stalled.
class _StallCallout extends StatelessWidget {
  const _StallCallout({required this.lift});
  final LiftDirection lift;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final name = lift.exerciseName ?? 'This lift';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: gb.progWarn,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text:
                        "$name hasn't moved in ${lift.stallSessions} sessions — "),
                TextSpan(
                  text: 'time to change something',
                  style: TextStyle(
                      color: gb.progWarn, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ]),
              style:
                  TextStyle(fontSize: 12.5, height: 1.35, color: gb.progInk2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section 3 — Consistency (big % + flame streak + blue heatmap + legend) ───

class _ConsistencySection extends StatelessWidget {
  const _ConsistencySection({required this.consistency});
  final Consistency consistency;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final pct = consistency.consistencyPct;
    final streak = consistency.currentStreakWeeks;
    // No goal (no plan) → there's no "% hit goal", but every completed ad-hoc session is already in
    // `days`. Self-training without a plan still counts: derive the total session count and headline it
    // instead of leaving an empty "% hit goal". The streak chip is goal-relative, so it's dropped here.
    final hasGoal = pct != null;
    final totalSessions = hasGoal
        ? 0
        : consistency.days.fold<int>(0, (sum, d) => sum + d.sessionCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Consistency',
            onInfo: () => _showHowSheet(context, _HowCounted.consistency)),
        const SizedBox(height: AppSpacing.sm),
        _ProgCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big % + flame streak header — only the parts the data honestly supports.
              if (hasGoal || streak > 0) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pct != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: '$pct',
                                  style: AppText.mono(const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    height: 0.86,
                                    letterSpacing: -1.8,
                                  )).copyWith(color: gb.progInk),
                                ),
                                TextSpan(
                                  text: '%',
                                  style: AppText.mono(const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  )).copyWith(color: gb.progInk3),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 8),
                            _MonoLabel(
                                'Hit goal · last ${consistency.windowWeeks} wks',
                                color: gb.progInk3),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    if (streak > 0) _StreakChip(streak: streak),
                  ],
                ),
                const SizedBox(height: 18),
              ]
              // No goal, but completed (ad-hoc) sessions exist → headline the raw session count so
              // self-training counts, with no fabricated "% hit goal" and no goal-relative streak chip.
              else if (totalSessions > 0) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalSessions',
                      style: AppText.mono(const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 0.86,
                        letterSpacing: -1.8,
                      )).copyWith(color: gb.progInk),
                    ),
                    const SizedBox(height: 8),
                    _MonoLabel(
                      'Sessions · last ${consistency.windowWeeks} wks',
                      color: gb.progInk3,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              // Override: the heatmap sizes its cells off the available card WIDTH (cell ≈
              // gridWidth/12), so the grid fills the card with visibly larger ~square cells and
              // the card height follows — instead of the prior fixed 92px cap that squeezed the
              // grid to ~9px cells centred in a half-empty card.
              _Heatmap(
                days: consistency.days,
                windowWeeks: consistency.windowWeeks,
                ramp: gb.progHeatRamp,
                nullCell: gb.progLine,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _HeatLegend(ramp: gb.progHeatRamp, label: gb.progInk4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "N wk streak" flame chip (design) — a small flame glyph + a mono uppercase label, neutral ink.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, size: 13, color: gb.progInk3),
        const SizedBox(width: 5),
        Text(
          '$streak wk streak'.toUpperCase(),
          // App font + tabular figures, zero tracking — the flame streak caption reads tight.
          style: AppText.mono(const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          )).copyWith(color: gb.progInk2),
        ),
      ],
    );
  }
}

/// The blue single-hue heatmap legend (design `HeatLegend`) — "Less" + 5 ramp swatches + "More".
class _HeatLegend extends StatelessWidget {
  const _HeatLegend({required this.ramp, required this.label});
  final List<Color> ramp;
  final Color label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Design `HeatLegend`: a uniform inline-flex gap:5 between "Less", each swatch, and "More".
        _MonoLabel('Less', color: label, fontSize: 8.5),
        for (final c in ramp) ...[
          const SizedBox(width: 5),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2.5)),
          ),
        ],
        const SizedBox(width: 5),
        _MonoLabel('More', color: label, fontSize: 8.5),
      ],
    );
  }
}

// ── Section 4 — Personal records (display-only teaser, brand trophy) ─────────

class _PrSection extends StatelessWidget {
  const _PrSection({required this.prs});
  final List<PersonalRecord> prs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Personal records'),
        const SizedBox(height: AppSpacing.sm),
        if (prs.isEmpty)
          const _QuietCard(text: 'Your PRs will appear here.')
        else
          for (var i = 0; i < prs.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs + 1),
            _PrRow(pr: prs[i], isBest: i == 0),
          ],
      ],
    );
  }
}

/// A PR teaser row (design) — a brand trophy IconTile (brand-soft fill), the lift name +
/// a "New best" mono tag (top row only), and a mono caption "140 kg × 3 · est. 1RM 153 · 2d ago".
/// Taps through to the per-lift e1RM drill-down (`/progress/lift/:exerciseId`), same as a strength row.
class _PrRow extends StatelessWidget {
  const _PrRow({required this.pr, required this.isBest});
  final PersonalRecord pr;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final when = _relativeWhen(pr.achievedAt);
    final caption = StringBuffer(
        '${fmtKg(pr.weightKg)} kg × ${pr.reps} · est. 1RM ${fmtKg(pr.estimatedOneRepMaxKg)}');
    if (when.isNotEmpty) caption.write(' · $when');

    return _ProgCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/progress/lift/${pr.exerciseId}'),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              // Brand trophy tile (brand-soft fill, faint brand border, brand glyph).
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: gb.progBrandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                  border:
                      Border.all(color: gb.primary600.withValues(alpha: 0.22)),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.emoji_events, size: 22, color: gb.primary600),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pr.exerciseName ?? 'Exercise',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.32,
                              color: gb.progInk,
                            ),
                          ),
                        ),
                        if (isBest) ...[
                          const SizedBox(width: AppSpacing.xs + 1),
                          _MonoLabel('New best',
                              color: gb.progBrandInk, fontSize: 9),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      caption.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      )).copyWith(color: gb.progInk3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section 5 — Body progress (conditional bodyweight trend) ─────────────────

/// Bodyweight trend (MOBILE-DASHBOARD §5), now **goal-aware** (Phase 3). A `ConsumerWidget` so it
/// watches its own `bodyweightSeriesProvider` and loads independently of the overview call — a slow or
/// absent metrics endpoint must never block §1–4. The goal is watched one level down in
/// [_BodyTrendCard]. Renders a smoothed EMA `CustomPaint` line on a labeled, non-zero axis when there
/// are weigh-ins (with a horizontal goal line + a "X kg to go" caption when a goal is set), an
/// empty-state invite when there are none, and stays **quiet on error** (collapses to nothing).
class _BodySection extends ConsumerWidget {
  const _BodySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(bodyweightSeriesProvider);

    return series.when(
      // While loading (or quietly on error), occupy no space — the section is opt-in evidence, not a
      // headline, and must never push the glance layer around or surface a page-level error.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Body'),
          const SizedBox(height: AppSpacing.sm),
          if (s.isEmpty)
            const _QuietCard(text: 'Log your weight to see your trend.')
          else
            _BodyTrendCard(series: s),
        ],
      ),
    );
  }
}

/// Trim a trailing `.0` from a metric number for display ("8" not "8.0", "7.5" stays).
String _trimNum(num v) => v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);

/// The Sleep section — an hours-slept trend mirroring [_BodySection] (no goal line). Watches its own
/// [sleepSeriesProvider], loads independently, shows a "log your sleep" invite on no data, and stays
/// quiet on loading/error so it never blocks the glance layer.
class _SleepSection extends ConsumerWidget {
  const _SleepSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(sleepSeriesProvider);
    return series.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Sleep'),
          const SizedBox(height: AppSpacing.sm),
          if (s.isEmpty)
            const _QuietCard(text: 'Log your sleep to see your trend.')
          else
            _SleepTrendCard(series: s),
        ],
      ),
    );
  }
}

/// The sleep trend card: the EMA line over the period + last-night and average captions. Reuses the
/// shared trend painter ([_BodyweightTrend]) with no goal line.
class _SleepTrendCard extends StatelessWidget {
  const _SleepTrendCard({required this.series});
  final MetricSeries series;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final values = [for (final p in series.points) p.value];
    final latest = values.last;
    final avg = values.reduce((a, b) => a + b) / values.length;
    return _ProgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MonoLabel('Hours slept', color: gb.progInk3)),
              Text(
                'avg ${_trimNum(avg)}h',
                style: AppText.mono(const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0))
                    .copyWith(color: gb.progInk2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: _BodyweightTrend(
              points: values,
              unit: 'h',
              goalKg: null,
              line: gb.primary600,
              raw: gb.progInk4,
              label: gb.progInk3,
              goal: gb.progPos,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Last night ${_trimNum(latest)}h',
            style: AppText.mono(
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                .copyWith(color: gb.progInk2),
          ),
        ],
      ),
    );
  }
}

/// The bodyweight trend card: the EMA chart (with an optional goal overlay), the distance-to-goal
/// caption, and — when no goal is set — a small "set a goal weight" affordance (Phase 3 §1/§2). It
/// watches `goalWeightProvider` itself so a goal load/save redraws only this card.
class _BodyTrendCard extends ConsumerWidget {
  const _BodyTrendCard({required this.series});
  final MetricSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    // Goal weight loads alongside but never gates the card — null (no goal / still loading / errored)
    // simply renders the "set a goal" affordance instead of the goal line.
    final goalKg = ref.watch(goalWeightProvider).valueOrNull;
    final latest = series.points.last.value;
    final unitSuffix = (series.unit != null && series.unit!.isNotEmpty)
        ? ' ${series.unit}'
        : '';

    return _ProgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MonoLabel('Bodyweight', color: gb.progInk3)),
              if (goalKg != null)
                // A quiet "Goal 75 kg" chip-as-text + an edit affordance.
                _GoalChip(goalKg: goalKg, unitSuffix: unitSuffix),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: _BodyweightTrend(
              points: [for (final p in series.points) p.value],
              unit: series.unit,
              goalKg: goalKg,
              line: gb.primary600,
              raw: gb.progInk4,
              label: gb.progInk3,
              goal: gb.progPos,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (goalKg != null)
            // Distance-to-goal caption, e.g. "3.2 kg to go" / "At your goal weight".
            Text(
              _distanceCaption(latest, goalKg, unitSuffix),
              style: AppText.mono(const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))
                  .copyWith(color: gb.progInk2),
            )
          else
            // No goal yet → the minimal set-a-goal affordance (Phase 3 §1 empty state).
            _SetGoalAffordance(
              onTap: () =>
                  _showSetGoalWeightSheet(context, ref, initialKg: latest),
            ),
        ],
      ),
    );
  }
}

/// A quiet "Goal 75 kg" label with a small edit pencil — taps open the set-goal sheet to revise.
class _GoalChip extends ConsumerWidget {
  const _GoalChip({required this.goalKg, required this.unitSuffix});
  final double goalKg;
  final String unitSuffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => _showSetGoalWeightSheet(context, ref, initialKg: goalKg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Goal ${fmtKg(goalKg)}$unitSuffix',
                // App font + tabular figures, zero tracking — the goal chip reads tight.
                style: AppText.mono(const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                )).copyWith(color: gb.progPos)),
            const SizedBox(width: AppSpacing.xxs),
            Icon(Icons.edit_outlined,
                size: AppSizes.iconXs, color: gb.progInk4),
          ],
        ),
      ),
    );
  }
}

/// The minimal "Set a goal weight" affordance shown under the trend when no goal exists.
class _SetGoalAffordance extends StatelessWidget {
  const _SetGoalAffordance({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined,
                size: AppSizes.iconMd, color: gb.primary600),
            const SizedBox(width: AppSpacing.xs),
            Text('Set a goal weight',
                style:
                    AppText.label.copyWith(color: gb.primary600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// "3.2 kg to go" / "1.0 kg over goal" / "At your goal weight" — forgiving, never red. Direction
/// (above/below) is intentionally not framed as good/bad: a cut and a bulk both read as "to go".
String _distanceCaption(double latest, double goal, String unitSuffix) {
  final diff = (latest - goal).abs();
  if (diff < 0.05) return 'At your goal weight';
  return '${fmtKg(diff)}$unitSuffix to go';
}

/// Smoothed bodyweight trend on a **non-zero, labeled** axis (MOBILE-DASHBOARD §5): faint raw
/// weigh-ins + a bold EMA overlay so hydration noise doesn't read as a trend, plus an optional
/// horizontal **goal line** (Phase 3). CustomPaint, no chart library (D11). The axis is bounded to
/// the data range **and the goal** so a goal off the data range stays visible.
class _BodyweightTrend extends StatelessWidget {
  const _BodyweightTrend({
    required this.points,
    required this.unit,
    required this.line,
    required this.raw,
    required this.label,
    required this.goal,
    this.goalKg,
  });
  final List<double> points;
  final String? unit;
  final Color line;
  final Color raw;
  final Color label;

  /// Goal-line colour.
  final Color goal;

  /// The current goal weight, or null when no goal is set (then no goal line is drawn).
  final double? goalKg;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BodyweightPainter(
        points: points,
        unit: unit,
        line: line,
        raw: raw,
        label: label,
        goal: goal,
        goalKg: goalKg,
      ),
      size: Size.infinite,
    );
  }
}

class _BodyweightPainter extends CustomPainter {
  _BodyweightPainter({
    required this.points,
    required this.unit,
    required this.line,
    required this.raw,
    required this.label,
    required this.goal,
    this.goalKg,
  });
  final List<double> points;
  final String? unit;
  final Color line;
  final Color raw;
  final Color label;
  final Color goal;
  final double? goalKg;

  /// The smoothed EMA series — depends only on the (immutable) [points], so computed once per painter
  /// instance instead of on every `paint` (paint also fires on layout/ancestor repaint).
  late final List<double> _smoothed = _ema(points);

  /// Axis bounds (min, max, span) over the raw + smoothed series AND the goal — likewise input-only, so
  /// derived once. Empty for an empty series (paint early-returns before reading them).
  late final (double, double, double) _bounds = _computeBounds();

  /// Exponential moving average — separates signal from daily hydration spikes.
  static List<double> _ema(List<double> xs, {double alpha = 0.3}) {
    if (xs.isEmpty) return const [];
    final out = <double>[xs.first];
    for (var i = 1; i < xs.length; i++) {
      out.add(alpha * xs[i] + (1 - alpha) * out[i - 1]);
    }
    return out;
  }

  /// Min/max/span over the raw + smoothed series AND the goal (so a goal off the data range still gets
  /// a labeled axis that includes it — Phase 3 §1); padded for a flat series.
  (double, double, double) _computeBounds() {
    if (points.isEmpty) return (0, 0, 0);
    final all = [...points, ..._smoothed, if (goalKg != null) goalKg!];
    var minV = all.reduce(math.min);
    var maxV = all.reduce(math.max);
    if ((maxV - minV).abs() < 1e-6) {
      final pad = maxV.abs() < 1e-6 ? 1.0 : maxV.abs() * 0.02;
      minV -= pad;
      maxV += pad;
    }
    return (minV, maxV, maxV - minV);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final smoothed = _smoothed;
    final (minV, maxV, span) = _bounds;

    const leftGutter = 34.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final plotLeft = leftGutter;
    final plotW = (size.width - plotLeft).clamp(1.0, double.infinity);
    final plotTop = topPad;
    final plotH =
        (size.height - topPad - bottomPad).clamp(1.0, double.infinity);

    final n = points.length;
    double x(int i) =>
        n == 1 ? plotLeft + plotW / 2 : plotLeft + plotW * (i / (n - 1));
    double y(double v) => plotTop + plotH - ((v - minV) / span) * plotH;

    final u = (unit != null && unit!.isNotEmpty) ? ' ${unit!}' : '';
    _drawLabel(canvas, '${fmtKg(maxV)}$u', Offset(0, plotTop), label);
    _drawLabel(canvas, fmtKg(minV), Offset(0, plotTop + plotH - 9), label);

    // Dashed horizontal goal line + a small "goal" tick label, behind the trend.
    if (goalKg != null) {
      final gy = y(goalKg!);
      _drawDashedLine(
        canvas,
        Offset(plotLeft, gy),
        Offset(plotLeft + plotW, gy),
        goal.withValues(alpha: 0.7),
      );
    }

    // Faint raw weigh-ins.
    final rawPaint = Paint()..color = raw.withValues(alpha: 0.5);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i])), 2.0, rawPaint);
    }

    // Bold EMA overlay (needs ≥2 points to draw a line; a single weigh-in shows just the dot).
    if (n >= 2) {
      final path = Path()..moveTo(x(0), y(smoothed[0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(x(i), y(smoothed[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawCircle(
        Offset(x(n - 1), y(smoothed.last)), 2.8, Paint()..color = line);
  }

  /// Hand-rolled dashed horizontal line (Canvas has no native dash) for the goal overlay.
  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    const dash = 5.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var startX = a.dx;
    while (startX < b.dx) {
      final endX = math.min(startX + dash, b.dx);
      canvas.drawLine(Offset(startX, a.dy), Offset(endX, b.dy), paint);
      startX += dash + gap;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 32);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_BodyweightPainter old) =>
      old.unit != unit ||
      old.line != line ||
      old.raw != raw ||
      old.label != label ||
      old.goal != goal ||
      old.goalKg != goalKg ||
      !listEquals(old.points, points);
}

// ── Set-goal-weight affordance (minimal, restylable) ─────────────────────────

/// A minimal sheet to record a goal weight (Phase 3 §2 / Decision **D12**). Writes a `goal_weight`
/// `MetricEntry` via the existing metric-write path, then invalidates [goalWeightProvider] so the
/// Body section redraws with the new goal line.
void _showSetGoalWeightSheet(
  BuildContext context,
  WidgetRef ref, {
  double? initialKg,
}) {
  showGbSheet<void>(
    context,
    builder: (_) => _SetGoalWeightSheet(parentRef: ref, initialKg: initialKg),
  );
}

class _SetGoalWeightSheet extends StatefulWidget {
  const _SetGoalWeightSheet({required this.parentRef, this.initialKg});

  /// The Progress screen's [WidgetRef] — used to invalidate [goalWeightProvider] after a write so the
  /// Body section refetches (the sheet's own element is gone by then).
  final WidgetRef parentRef;
  final double? initialKg;

  @override
  State<_SetGoalWeightSheet> createState() => _SetGoalWeightSheetState();
}

class _SetGoalWeightSheetState extends State<_SetGoalWeightSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialKg == null ? '' : fmtKg(widget.initialKg!),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kg = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      setState(() => _error = 'Enter a weight in kg.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.parentRef.read(progressRepositoryProvider).setGoalWeight(kg);
      // Refetch the goal so the new line shows immediately.
      widget.parentRef.invalidate(goalWeightProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't save your goal. Try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GbSheetHeader(
            title: 'Set a goal weight',
            subtitle: 'We\'ll draw it on your bodyweight trend.',
          ),
          const SizedBox(height: AppSpacing.md),
          GbTextField(
            controller: _controller,
            label: 'Goal weight (kg)',
            hint: '75',
            icon: Icons.flag_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!, style: AppText.meta.copyWith(color: gb.danger)),
          ],
          const SizedBox(height: AppSpacing.md),
          GbButton(
            label: 'Save goal',
            full: true,
            busy: _busy,
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ── Section 5b — Nutrition CALORIES TREND (conditional) ──────────────────────

/// Recent nutrition as an honest **CALORIES TREND** (MOBILE-DASHBOARD §5 / Decision **D13**, rebuilt).
/// A `ConsumerWidget` watching its own `nutritionAdherenceProvider`, so it loads independently and
/// **never blocks §1–4**. The per-day payload now carries `consumedKcal` (all-source) and a plan-derived
/// `targetKcal` (null when hidden), so the card draws consumed-kcal bars over the trailing window —
/// the **same bars for plan and no-plan users** (the data is all-source). A faint dashed "Plan" target
/// line is drawn only on days that actually have a target; bars are tinted deficit/surplus only against
/// a present target, neutral otherwise. **Quiet** on loading and error (collapses to nothing) —
/// nutrition is opt-in evidence, not a headline.
class _NutritionSection extends ConsumerWidget {
  const _NutritionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherence = ref.watch(nutritionAdherenceProvider);
    return adherence.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (a) {
        // The all-source CALORIES-LOGGED day list: every logged day (plan or ad-hoc) in the window.
        // It drives BOTH the trend and the explicit list, so an ad-hoc/no-plan logger sees both.
        final hasLog = a.caloriesByDay.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Nutrition',
                onInfo: () => _showHowSheet(context, _HowCounted.nutrition)),
            const SizedBox(height: AppSpacing.sm),
            if (hasLog) ...[
              // The consumed-kcal TREND now charts the ALL-SOURCE [caloriesByDay] (ad-hoc + planned),
              // so a no-plan logger sees a trend too. The list below complements it with explicit rows.
              _CaloriesTrendCard(adherence: a),
              const SizedBox(height: AppSpacing.sm),
              // ALWAYS show the all-source list when there's anything logged.
              _CaloriesLogCard(days: a.caloriesByDay),
            ] else if (a.hasPlan)
              // A plan, but no closed days yet → a "log a day" nudge, not an empty trend.
              const _QuietCard(
                text: 'Close out a day to see your calories trend.',
              )
            else if (a.hasAnyLogging)
              // No plan and some self-logging, but nothing in the recent window to chart yet → the
              // honest "keep logging" nudge (never a fabricated 100% ring / target).
              const _QuietCard(
                text: 'Keep logging to see your calories trend.',
              )
            else
              // Genuinely nothing logged yet → the follow-a-meal-plan invite (never a 0% ring).
              const _QuietCard(
                text: 'Log your food to see your calories trend.',
              ),
          ],
        );
      },
    );
  }
}

/// The CALORIES TREND card: per-day consumed-kcal bars over the trailing window (CustomPaint, no chart
/// library — D11), a faint dashed "Plan" target line drawn only where a target exists, bars tinted
/// cool/warm by deficit/surplus only against a present target (neutral otherwise), a small days-logged
/// sub-caption, and an honest [_caloriesAdvice] line built only from real numbers. Graphite tokens,
/// app font.
class _CaloriesTrendCard extends StatelessWidget {
  const _CaloriesTrendCard({required this.adherence});
  final NutritionAdherence adherence;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Recent days, oldest→newest; the trend shows the trailing 7. Sourced from the ALL-SOURCE
    // [caloriesByDay] (ad-hoc + planned) — NOT the plan-only [recentDays] — so the bars and the
    // "N days logged" advice agree with the all-source "this week" subtitle below.
    final recent = adherence.caloriesByDay.length > 7
        ? adherence.caloriesByDay.sublist(adherence.caloriesByDay.length - 7)
        : adherence.caloriesByDay;
    // Accurate current-week count for the "this week" caption (the trend bars span the trailing
    // window, which can reach into last week — so don't label that day count "this week").
    final loggedThisWeek = adherence.loggedDaysThisWeek;
    final advice = _caloriesAdvice(recent);

    return _ProgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonoLabel('Calories trend', color: gb.progInk3),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: _CaloriesTrend(
              days: recent,
              neutral: gb.progRing, // cool / under / no-target
              under: gb.progRing, // under plan → cool
              over: const Color(
                  0xFFFB7185), // over plan → coral (warm attention, not yellow)
              target: gb.progInk3, // dashed "Plan" line
              track: gb.progLine,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Days-logged sub-caption — the honest self-tracking signal, kept small.
          _MonoLabel(
            '$loggedThisWeek ${loggedThisWeek == 1 ? 'day' : 'days'} logged · this week',
            color: gb.progInk4,
            fontSize: 9.5,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            advice,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: gb.progInk2),
          ),
        ],
      ),
    );
  }
}

/// The honest advice line, built ONLY from real numbers — never a fabricated target, deficit, or %.
///   • No targets anywhere in the window → describe the trend: the average kcal/day over the logged
///     days (the trend's only honest summary without a target).
///   • Sparse logging (fewer than 3 logged days) → a nudge: "only N day(s) logged — log more for a
///     useful trend" (so we never over-read 1–2 points as a trend).
///   • Targets present on most logged days → compare honestly against the target on **only the days
///     that have one**: "averaging ~N kcal under/over plan on logged days".
/// A day without a target NEVER contributes a deficit/surplus number.
String _caloriesAdvice(List<DayCalories> days) {
  if (days.isEmpty) return 'Log your food to see your calories trend.';

  // Sparse logging guard — 1–2 points isn't a trend; nudge to keep logging.
  if (days.length < 3) {
    final n = days.length;
    return 'Only $n ${n == 1 ? 'day' : 'days'} logged — log more for a useful trend.';
  }

  final withTarget = days.where((d) => d.targetKcal != null).toList();
  // Targets on most logged days → an honest under/over-plan comparison over ONLY those days.
  if (withTarget.length * 2 >= days.length && withTarget.isNotEmpty) {
    final avgDelta = withTarget
            .map((d) => d.consumedKcal - d.targetKcal!)
            .fold<int>(0, (a, b) => a + b) /
        withTarget.length;
    final mag = avgDelta.abs().round();
    if (mag < 50) {
      return 'Right around your plan target on logged days.';
    }
    final dir = avgDelta < 0 ? 'under' : 'over';
    return 'Averaging ~$mag kcal $dir plan on logged days.';
  }

  // No (or too few) targets → describe the trend honestly: the average consumed kcal/day.
  final avgConsumed =
      days.map((d) => d.consumedKcal).fold<int>(0, (a, b) => a + b) /
          days.length;
  return 'Averaging ~${avgConsumed.round()} kcal/day over your logged days.';
}

/// The CALORIES TREND strip — one consumed-kcal bar per recent day, height ∝ consumed kcal (scaled to
/// the window max). Bars tint cool (under) / warm (over) against a present `targetKcal`, neutral when a
/// day has no target. A faint dashed "Plan" line/band is drawn at the target height ONLY over days that
/// have a target. CustomPaint, no chart library (D11).
class _CaloriesTrend extends StatelessWidget {
  const _CaloriesTrend({
    required this.days,
    required this.neutral,
    required this.under,
    required this.over,
    required this.target,
    required this.track,
  });
  final List<DayCalories> days;
  final Color neutral;
  final Color under;
  final Color over;
  final Color target;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CaloriesTrendPainter(
        consumed: [for (final d in days) d.consumedKcal],
        targets: [for (final d in days) d.targetKcal],
        neutral: neutral,
        under: under,
        over: over,
        target: target,
        track: track,
      ),
      size: Size.infinite,
    );
  }
}

class _CaloriesTrendPainter extends CustomPainter {
  _CaloriesTrendPainter({
    required this.consumed,
    required this.targets,
    required this.neutral,
    required this.under,
    required this.over,
    required this.target,
    required this.track,
  });

  /// Consumed kcal per day (all-source), oldest→newest.
  final List<int> consumed;

  /// Plan target kcal per day, null on days with no target (parallel to [consumed]).
  final List<int?> targets;
  final Color neutral;
  final Color under;
  final Color over;
  final Color target;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final n = consumed.length;
    if (n == 0) return;

    // Scale bars to the largest of any consumed value OR any target — so a day over target still reads
    // as a taller bar above the plan line, and the line sits inside the plot.
    var maxV = 0;
    for (final c in consumed) {
      if (c > maxV) maxV = c;
    }
    for (final t in targets) {
      if (t != null && t > maxV) maxV = t;
    }
    if (maxV <= 0)
      maxV = 1; // all-zero window → flat track only, no divide-by-zero

    const gap = 5.0;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(2.0, double.infinity);
    final radius = Radius.circular(math.min(3.0, barW / 2));
    double yOf(int kcal) => size.height - (kcal / maxV) * size.height;

    for (var i = 0; i < n; i++) {
      final left = i * (barW + gap);

      // Faint full-height track so empty/zero days still register as a column.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, 0, barW, size.height), radius),
        Paint()..color = track,
      );

      final kcal = consumed[i];
      final t = targets[i];
      // Tint ONLY against a present target: under → cool, over → warm; neutral when no target.
      final Color barColor;
      if (t == null) {
        barColor = neutral;
      } else {
        barColor = kcal > t ? over : under;
      }

      final h = ((kcal / maxV) * size.height).clamp(0.0, size.height);
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(left, size.height - h, barW, h), radius),
          Paint()..color = barColor,
        );
      }

      // The dashed "Plan" target tick — drawn ONLY on days with a target, spanning that day's column.
      if (t != null) {
        final ty = yOf(t).clamp(0.0, size.height);
        _drawDashedLine(
          canvas,
          Offset(left, ty),
          Offset(left + barW, ty),
          target.withValues(alpha: 0.7),
        );
      }
    }
  }

  /// Hand-rolled dashed horizontal line (Canvas has no native dash) for the per-day "Plan" tick.
  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    const dash = 4.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var startX = a.dx;
    while (startX < b.dx) {
      final endX = math.min(startX + dash, b.dx);
      canvas.drawLine(Offset(startX, a.dy), Offset(endX, b.dy), paint);
      startX += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_CaloriesTrendPainter old) =>
      old.neutral != neutral ||
      old.under != under ||
      old.over != over ||
      old.target != target ||
      old.track != track ||
      !listEquals(old.consumed, consumed) ||
      !listEquals(old.targets, targets);
}

// ── Section 5c — CALORIES-LOGGED LIST (all-source companion to the trend) ─────

/// The **CALORIES-LOGGED LIST** — a compact, most-recent-first list of every day the trainee logged
/// food (plan OR ad-hoc, all-source), so a no-plan logger (whose plan-only [_CaloriesTrendCard] trend
/// is empty) still sees what they actually logged. Each row pairs the relative day label
/// ("Today"/"Yesterday"/"Jun 12") with that day's consumed kcal; on days that also carry a plan
/// `targetKcal`, a small under/over delta is shown (cool when under, warm when over — NEVER red, and
/// NEVER a fabricated target on a no-target day). Capped at ~8 rows. Graphite tokens, app font,
/// tabular numerals.
class _CaloriesLogCard extends StatelessWidget {
  const _CaloriesLogCard({required this.days});

  /// Logged days, date-ASCENDING off the wire (every day with ≥1 logged item, any source).
  final List<DayCalories> days;

  /// Cap the visible rows so the list stays a glance, not a ledger.
  static const _maxRows = 8;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Most-recent-first (the wire is date-ascending), capped.
    final rows = days.reversed.take(_maxRows).toList(growable: false);

    return _ProgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonoLabel('Calories logged', color: gb.progInk3),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) _RuleInset(color: gb.progLine2),
            _CaloriesLogRow(day: rows[i]),
          ],
        ],
      ),
    );
  }
}

/// One row of the CALORIES-LOGGED LIST: the relative day label on the left, "X kcal" on the right, and
/// — only when the day carries a plan target — a small "/ Y" plus an under/over delta tinted
/// cool/warm (never red). A day with no target shows kcal only (never a fabricated target).
class _CaloriesLogRow extends StatelessWidget {
  const _CaloriesLogRow({required this.day});
  final DayCalories day;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final target = day.targetKcal;
    // Delta vs the plan target, only when present. Under → cool (progRing), over → warm (progWarn).
    final delta = target == null ? null : day.consumedKcal - target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              relativeDayLabel(day.localDate),
              style: AppText.mono(const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              )).copyWith(color: gb.progInk2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Consumed kcal — the always-present right-hand stat.
          Text(
            '${day.consumedKcal} kcal',
            style: AppText.mono(const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            )).copyWith(color: gb.progInk),
          ),
          // Plan target + signed delta — ONLY when a real target exists for the day.
          if (target != null && delta != null) ...[
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              '/ $target',
              style: AppText.mono(const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              )).copyWith(color: gb.progInk4),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              delta == 0
                  ? 'on target'
                  : '${delta > 0 ? '+' : '−'}${delta.abs()}',
              style: AppText.mono(const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              )).copyWith(
                // Coral when over, cool when under, muted when exactly on target — never alarm-red.
                color: delta == 0
                    ? gb.progInk4
                    : (delta > 0 ? const Color(0xFFBE3A5B) : gb.progRing),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared small pieces ─────────────────────────────────────────────────────

/// A quiet (not-an-error) placeholder card used for the thin-lift-data and no-PR states, and for the
/// Body/Nutrition invites. The design's recessed `.surf-quiet` surface (card2 fill, inset, no shadow).
class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return _ProgCard(
      quiet: true,
      // Design `tier=3` invite copy: 12.5px / ink3 / 1.45 line-height (not the 14px body default).
      child: Text(text,
          style: TextStyle(fontSize: 12.5, height: 1.45, color: gb.progInk3)),
    );
  }
}

/// First-run hero shown when the trainee has never completed a session (PHASE-1 §5 "New user").
/// The design `NewUserBody`: the signature dark `hero-bg` gradient panel (eyebrow + 25/700 headline +
/// honesty sub-line + a white "Start a workout" CTA), then a mono "What you'll see here" label and
/// three surf-quiet preview cards (Strength trend / Consistency / Personal records). The previews
/// describe *future* content — non-fabricated, no numbers. Kept inside a scrollable so pull-to-refresh
/// stays engaged.
class _NewUserHero extends StatelessWidget {
  const _NewUserHero();

  static const _previews = [
    (
      icon: Icons.show_chart,
      title: 'Strength trend',
      subtitle: 'Each lift, week over week'
    ),
    (
      icon: Icons.calendar_today_outlined,
      title: 'Consistency',
      subtitle: 'A heatmap of every session'
    ),
    (
      icon: Icons.emoji_events_outlined,
      title: 'Personal records',
      subtitle: 'Every new best, by the lift'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.md + 4, AppSpacing.screenH, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _NewUserHeroPanel(),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _MonoLabel('What you\'ll see here',
                      color: context.gb.progInk3),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _previews.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _PreviewCard(
                    icon: _previews[i].icon,
                    title: _previews[i].title,
                    subtitle: _previews[i].subtitle,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark gradient first-run panel (design `NewUserBody` hero): eyebrow, a 25/700 headline, an
/// honesty sub-line, and a white "Start a workout" CTA. The CTA routes to the existing `/start` flow
/// (the same destination the shell's Start action uses), so it is genuinely reachable — not a dead
/// button.
class _NewUserHeroPanel extends StatelessWidget {
  const _NewUserHeroPanel();

  static const _heroMut = Color(0xBDDFE9FF); // --hero-mut

  @override
  Widget build(BuildContext context) {
    const heroShadow = [
      BoxShadow(
        color: Color(0x59182BBE),
        blurRadius: 36,
        spreadRadius: -22,
        offset: Offset(0, 18),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: GbColors.progressHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg - 2), // 18
        boxShadow: heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MonoLabel('Welcome to GymBro', color: _heroMut),
            const SizedBox(height: 11),
            const Text(
              'Start your first session to begin tracking.',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.625,
                height: 1.18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your progress is built from your own sessions — no fake numbers to start.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _heroMut,
              ),
            ),
            const SizedBox(height: 20),
            // White CTA → the existing start-workout flow (`/start`, the same route the shell's Start
            // action pushes), so the button is honest and reachable.
            _StartWorkoutCta(onTap: () => context.push('/start')),
          ],
        ),
      ),
    );
  }
}

/// The white "Start a workout" CTA inside the new-user hero — a full-width 50px pill with a plus glyph.
class _StartWorkoutCta extends StatelessWidget {
  const _StartWorkoutCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const onWhite = Color(0xFF15171C); // design CTA fg
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 18, color: onWhite),
              const SizedBox(width: AppSpacing.xs),
              Text('Start a workout',
                  style: AppText.button.copyWith(color: onWhite)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A surf-quiet "what you'll see here" preview card (design `NewUserBody` `tier=3` cards): a neutral
/// icon tile + a title + a subtitle. Describes future content — never a fabricated number.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return _ProgCard(
      quiet: true,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          // Neutral IconTile (design): a card2 squircle with an ink2 glyph.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: gb.card,
              borderRadius: BorderRadius.circular(AppRadius.sm - 1),
              border: Border.all(color: gb.progLine),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: gb.progInk2),
          ),
          const SizedBox(width: AppSpacing.sm + 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.14,
                    color: gb.progInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: gb.progInk3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading (bespoke hero-shaped skeleton) ───────────────────────────────────

/// The design `LoadingBody`, shaped to the selected view so the skeleton matches what's about to load:
/// the **Week** goal hero, the **4w / 12w** stat strip, or the **Today** glance fill the hero slot, then
/// the strength card (every trend window) and the consistency-heatmap card (4w / 12w only) — or grounded
/// advice cards on Today. Kept inside a scrollable so pull-to-refresh stays engaged. Reuses [GbSkeleton]
/// for the on-card shimmer; the hero placeholders are static translucent-white blocks so they read over
/// the gradient (the grey skeleton fill would vanish there).
class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.range});
  final ProgressRange range;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final isToday = range == ProgressRange.today;
    final isWeek = range == ProgressRange.week;

    final children = <Widget>[
      // Hero slot — matches the loaded content for this view.
      if (isToday)
        const _LoadingTodayGlance(key: ValueKey('loadingToday'))
      else if (isWeek)
        const _LoadingHero(key: ValueKey('loadingHero'))
      else
        const _LoadingStatStrip(key: ValueKey('loadingStatStrip')),
      const SizedBox(height: AppSpacing.lg),
    ];

    if (isToday) {
      // Today = grounded advice cards — no strength card, no heatmap.
      children.addAll(const [
        _LoadingAdviceCard(),
        SizedBox(height: AppSpacing.sm),
        _LoadingAdviceCard(),
      ]);
    } else {
      // Strength card skeleton — 3 lift-row placeholders (shown on every trend window).
      children.add(_ProgCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) _RuleInset(color: gb.progLine2),
              const _LoadingLiftRow(),
            ],
          ],
        ),
      ));
      // Consistency card skeleton — a big bar + a 12×7 heatmap grid; only on the 4w / 12w windows
      // (the Week view has no heatmap). Design `LoadingBody`: pad 17, a 42%-wide / 28px bar, grid below.
      if (!isWeek) {
        children.addAll(const [
          SizedBox(height: AppSpacing.lg),
          _ProgCard(
            padding: EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.42,
                  alignment: Alignment.centerLeft,
                  child:
                      GbSkeleton(width: double.infinity, height: 28, radius: 7),
                ),
                SizedBox(height: 18),
                _LoadingHeatmapGrid(),
              ],
            ),
          ),
        ]);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.md + 4, AppSpacing.screenH, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 4w / 12w hero-slot skeleton — a 2×2 grid of tile placeholders matching [_PeriodStatStrip].
class _LoadingStatStrip extends StatelessWidget {
  const _LoadingStatStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    Widget tile() => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 1, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: gb.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: gb.progLine),
            boxShadow: AppShadows.sm,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GbSkeleton(width: 42, height: 21, radius: 6),
              SizedBox(height: 7),
              GbSkeleton(width: 58, height: 9, radius: 5),
            ],
          ),
        );
    return _snapshotGrid([tile(), tile(), tile(), tile()], cols: 2);
  }
}

/// The Today hero-slot skeleton — a macros-card placeholder over a 3-tile snapshot grid.
class _LoadingTodayGlance extends StatelessWidget {
  const _LoadingTodayGlance({super.key});

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    Widget tile() => Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 1),
          decoration: BoxDecoration(
            color: gb.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: gb.progLine),
            boxShadow: AppShadows.sm,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GbSkeleton(width: 30, height: 30, radius: 9),
              SizedBox(height: 10),
              GbSkeleton(width: 38, height: 9, radius: 5),
              SizedBox(height: 6),
              GbSkeleton(width: 28, height: 20, radius: 6),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgCard(
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GbSkeleton(width: 34, height: 20, radius: 6),
                      SizedBox(height: 6),
                      GbSkeleton(width: 26, height: 9, radius: 5),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _snapshotGrid([tile(), tile(), tile()], cols: 3),
      ],
    );
  }
}

/// One advice-card skeleton for the Today loading state — a title line over a body line.
class _LoadingAdviceCard extends StatelessWidget {
  const _LoadingAdviceCard();

  @override
  Widget build(BuildContext context) {
    return const _ProgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GbSkeleton(width: 150, height: 12, radius: 6),
          SizedBox(height: 10),
          GbSkeleton(width: double.infinity, height: 10, radius: 5),
        ],
      ),
    );
  }
}

/// The hero-panel skeleton: the navy gradient block with translucent-white shimmer lines and a circle
/// standing in for the adherence ring.
class _LoadingHero extends StatelessWidget {
  const _LoadingHero({super.key});

  static const _heroLine = Color(0x2EFFFFFF); // --hero-line
  static const _ph1 = Color(0x1FFFFFFF); // ~0.12 white placeholder
  static const _ph2 = Color(0x1AFFFFFF); // ~0.10 white placeholder

  Widget _bar(double widthFactor, double height, Color color) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const heroShadow = [
      BoxShadow(
        color: Color(0x59182BBE),
        blurRadius: 36,
        spreadRadius: -22,
        offset: Offset(0, 18),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: GbColors.progressHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg - 2), // 18
        boxShadow: heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(0.34, 10, _ph1),
            const SizedBox(height: 12),
            _bar(0.82, 16, _ph1),
            const SizedBox(height: 18),
            Container(height: 1, color: _heroLine),
            const SizedBox(height: 18),
            Row(
              children: [
                // Circle placeholder for the ring.
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: _ph2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bar(0.6, 13, _ph1),
                      const SizedBox(height: 9),
                      _bar(0.4, 10, _ph2),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One lift-row skeleton inside the loading strength card — name/value shimmer + a spark + a tag block.
class _LoadingLiftRow extends StatelessWidget {
  const _LoadingLiftRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GbSkeleton(width: 100, height: 13, radius: 6),
                SizedBox(height: 7),
                GbSkeleton(width: 64, height: 10, radius: 5),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          GbSkeleton(width: 64, height: 26, radius: 6),
          SizedBox(width: AppSpacing.sm),
          GbSkeleton(width: 48, height: 14, radius: 5),
        ],
      ),
    );
  }
}

/// A 12×7 skeleton grid standing in for the consistency heatmap while loading.
class _LoadingHeatmapGrid extends StatelessWidget {
  const _LoadingHeatmapGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 12;
        const rows = 7;
        const gap = 4.5;
        // Match the loaded heatmap: width-derived cells (≈ gridWidth/12) that fill the card, capped
        // at 24 so the skeleton grid tracks the real one and doesn't balloon on a wide surface.
        final cell =
            ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(2.0, 24.0);
        return Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              Row(
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: gap),
                    GbSkeleton(width: cell, height: cell, radius: 3),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Error (neutral Graphite panel — never red) ───────────────────────────────

/// The design `ErrorBody`: a NEUTRAL centered panel (never red — this screen's only red is a per-lift
/// "slipping" tag, PHASE-1 §1). A card2 squircle with a `cloud_off` glyph in ink3, an 18/800 ink title,
/// an ink3 body line, and a brand-gradient "Retry" button (refresh icon) that invalidates the overview
/// provider. Kept scrollable so pull-to-refresh still works in the error state.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: gb.progCard2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: gb.progLine),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.cloud_off, size: 30, color: gb.progInk3),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Text(
                  'Couldn\'t load your progress',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.36,
                    height: 1.2,
                    color: gb.progInk,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Check your connection and try again — your data is safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: gb.progInk3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _RetryButton(onTap: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The brand-gradient "Retry" button (design `ErrorBody`) — a 46px pill with a refresh glyph. Brand,
/// never danger; on white text.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: GbColors.progressHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadows.blueSm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: SizedBox(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 17, color: Colors.white),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Retry',
                      style: AppText.button.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── CustomPaint: sparkline + heatmap (no chart dependency) ───────────────────

/// A tiny e1RM sparkline (design `Sparkline`) — a smooth Catmull-Rom stroke with a faint vertical
/// gradient fill and a crisp donut endpoint. Below 4 points (thin data) it degrades to a **dots-only**
/// variant (hollow rings, neutral). The server gates lifts to ≥4 qualifying sessions, but we degrade
/// safely for thin spark series too.
class _Sparkline extends StatelessWidget {
  const _Sparkline(
      {required this.points, required this.color, required this.cardColor});
  final List<double> points;
  final Color color;

  /// The card fill the donut endpoint punches through to (so its hole matches the surface).
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(
        points: points,
        color: color,
        card: cardColor,
        dotsOnly: points.length < 4,
        neutralDot: context.gb.progInk4,
      ),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.color,
    required this.card,
    required this.dotsOnly,
    required this.neutralDot,
  });
  final List<double> points;
  final Color color;
  final Color card;
  final bool dotsOnly;
  final Color neutralDot;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final span = (maxV - minV).abs();
    final n = points.length;
    const padY = 4.0;
    const padX = 2.0;
    final plotW = (size.width - padX - 5).clamp(1.0, double.infinity);
    final h = (size.height - padY * 2).clamp(1.0, double.infinity);

    double x(int i) => n == 1 ? padX + plotW / 2 : padX + plotW * (i / (n - 1));
    double y(double v) {
      if (span < 1e-9) return size.height / 2; // flat series → centered
      return size.height - padY - ((v - minV) / span) * h;
    }

    final pts = [for (var i = 0; i < n; i++) Offset(x(i), y(points[i]))];

    // Dots-only (thin data): hollow neutral rings, no line/fill (design `dotsOnly`).
    if (dotsOnly) {
      final ring = Paint()
        ..color = neutralDot
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      for (final p in pts) {
        canvas.drawCircle(p, 2.3, ring);
      }
      return;
    }

    if (pts.length < 2) {
      canvas.drawCircle(pts.first, 2.5, Paint()..color = color);
      return;
    }

    final path = _smoothPath(pts);

    // Faint vertical gradient fill under the curve (0 → 12% opacity, bottom → top).
    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.12)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    // The smooth stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Crisp donut endpoint: a faint halo, then a card-filled core ringed in the trend colour.
    final last = pts.last;
    canvas.drawCircle(
        last, 4.4, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawCircle(last, 2.5, Paint()..color = card);
    canvas.drawCircle(
      last,
      2.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Catmull-Rom → cubic-Bézier smoothing (design `smoothPath`, tension 0.17). Falls back to straight
  /// segments below 3 points.
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length < 3) {
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return path;
    }
    const t = 0.17;
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i - 1 < 0 ? i : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 >= pts.length ? i + 1 : i + 2];
      final c1 =
          Offset(p1.dx + (p2.dx - p0.dx) * t, p1.dy + (p2.dy - p0.dy) * t);
      final c2 =
          Offset(p2.dx - (p3.dx - p1.dx) * t, p2.dy - (p3.dy - p1.dy) * t);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.card != card ||
      old.dotsOnly != dotsOnly ||
      old.neutralDot != neutralDot ||
      !listEquals(old.points, points);
}

/// A ~12-week completed-session calendar heatmap (design `Heatmap`). Columns are weeks
/// (oldest→newest, ending this week), rows are Mon→Sun. Cells are colored by session count off the
/// single-hue blue ramp; **future** cells past today are null (a dashed outline, transparent fill).
/// A thin column of M / W / F day labels sits to the left. The client fills the gaps the API omits
/// (it only sends days with ≥1 completed session).
class _Heatmap extends StatelessWidget {
  const _Heatmap({
    required this.days,
    required this.windowWeeks,
    required this.ramp,
    required this.nullCell,
  });
  final List<ConsistencyDay> days;
  final int windowWeeks;

  /// The 5-step blue ramp (heat0..heat4).
  final List<Color> ramp;

  /// The dashed-outline colour for null (future) cells.
  final Color nullCell;

  /// Label column width + the gap to the grid (design `width:8` glyph in a flex column + `gap:7`).
  static const double _labelCol = 9;
  static const double _labelGap = 7;
  static const double _cellGap = 4.5;
  static const int _rows = 7; // Mon..Sun

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final cols = windowWeeks <= 0 ? 12 : windowWeeks;
    // Override: derive the cell size from the GRID width (cell ≈ gridWidth/12), so the grid fills
    // the card with large ~square cells and the card height follows — rather than capping height and
    // letting tiny cells float centred in a half-empty card. The whole heatmap height is then exactly
    // the 7-row grid height, which the label column matches.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridW = constraints.maxWidth - _labelCol - _labelGap;
        // Cell ≈ gridWidth/12 (fills a phone card at ~21px). Capped at 24 so the grid can't balloon
        // on a wide/desktop/test surface — on a phone the width-derived size is well under the cap.
        final cell = ((gridW - _cellGap * (cols - 1)) / cols).clamp(2.0, 24.0);
        final gridH = cell * _rows + _cellGap * (_rows - 1);
        return SizedBox(
          height: gridH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day-label column (M / · / W / · / F / · / ·), aligned to the grid rows.
              SizedBox(
                width: _labelCol,
                height: gridH,
                child: CustomPaint(
                  size: Size(_labelCol, gridH),
                  painter: _HeatLabelPainter(color: gb.progInk4),
                ),
              ),
              const SizedBox(width: _labelGap),
              Expanded(
                child: CustomPaint(
                  painter: _HeatmapPainter(
                    counts: _countsByDay(days),
                    weeks: cols,
                    cell: cell,
                    ramp: ramp,
                    nullCell: nullCell,
                  ),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Index completed-session counts by the local day at midnight, so the painter can look up any
  /// grid cell. Skips malformed (null-date) rows defensively.
  static Map<DateTime, int> _countsByDay(List<ConsistencyDay> days) {
    final map = <DateTime, int>{};
    for (final d in days) {
      final date = d.date;
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      map[key] = (map[key] ?? 0) + d.sessionCount;
    }
    return map;
  }
}

/// Paints the M / W / F mono day labels down the left edge, aligned to the heatmap rows.
class _HeatLabelPainter extends CustomPainter {
  _HeatLabelPainter({required this.color});
  final Color color;

  static const _labels = ['M', '', 'W', '', 'F', '', ''];

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 7;
    const gap = 4.5;
    final cell = (size.height - gap * (rows - 1)) / rows;
    for (var r = 0; r < rows; r++) {
      final l = _labels[r];
      if (l.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: l,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cy = r * (cell + gap) + cell / 2 - tp.height / 2;
      tp.paint(canvas, Offset(0, cy));
    }
  }

  @override
  bool shouldRepaint(_HeatLabelPainter old) => old.color != color;
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.counts,
    required this.weeks,
    required this.cell,
    required this.ramp,
    required this.nullCell,
  });
  final Map<DateTime, int> counts;
  final int weeks;

  /// The width-derived square cell size (≈ gridWidth/12), computed by [_Heatmap] so the grid fills
  /// the card. The painter no longer mins against its own height — the grid IS its full height.
  final double cell;
  final List<Color> ramp;
  final Color nullCell;

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 7; // Mon..Sun
    const gap = 4.5;
    final cols = weeks;
    if (cell <= 0) return;

    // Left-aligned (no centring) — the width-derived cells already fill the available width.
    const startX = 0.0;

    // Monday of the current week, in local time.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = mondayThisWeek.subtract(Duration(days: 7 * (cols - 1)));

    final radius = Radius.circular(cell * 0.24);
    final dashPaint = Paint()
      ..color = nullCell
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final day = firstMonday.add(Duration(days: c * 7 + r));
        final rect = Rect.fromLTWH(
          startX + c * (cell + gap),
          r * (cell + gap),
          cell,
          cell,
        );
        final rrect = RRect.fromRectAndRadius(rect, radius);
        if (day.isAfter(today)) {
          // Future cell → a dashed outline over a transparent fill (design `v == null`).
          _drawDashedRRect(canvas, rrect, dashPaint);
          continue;
        }
        final nSessions = counts[DateTime(day.year, day.month, day.day)] ?? 0;
        final level = nSessions <= 0
            ? 0
            : (nSessions >= 3 ? 4 : (nSessions == 1 ? 2 : 3));
        canvas.drawRRect(rrect, Paint()..color = ramp[level]);
      }
    }
  }

  /// A hand-rolled dashed rounded-rect outline (Canvas has no native dash) for future/null cells.
  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    const dash = 2.5, gap = 2.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.weeks != weeks ||
      old.cell != cell ||
      old.nullCell != nullCell ||
      !listEquals(old.ramp, ramp) ||
      !mapEquals(old.counts, counts);
}

// ── Formatting helpers ──────────────────────────────────────────────────────

/// First word of a lift name, lowercased, for the compact headline ("Barbell Bench Press" → "bench"
/// is too lossy, so keep the first meaningful word as-is). Returns '' for null/empty.
String _shortName(String? name) {
  if (name == null) return '';
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(RegExp(r'\s+'));
  // Skip a leading equipment qualifier so "Barbell Bench Press" reads "Bench".
  const skip = {'barbell', 'dumbbell', 'machine', 'cable', 'smith'};
  final meaningful =
      words.where((w) => !skip.contains(w.toLowerCase())).toList();
  final pick = (meaningful.isNotEmpty ? meaningful.first : words.first);
  return pick.toLowerCase();
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Relative day label for a PR row caption.
String _relativeWhen(DateTime? d) {
  if (d == null) return '';
  final local = d.toLocal();
  final today = DateTime.now();
  final dayOnly = DateTime(local.year, local.month, local.day);
  final todayOnly = DateTime(today.year, today.month, today.day);
  final diff = todayOnly.difference(dayOnly).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return '1d ago';
  if (diff > 1 && diff < 7) return '${diff}d ago';
  return '${local.day}/${local.month}';
}
