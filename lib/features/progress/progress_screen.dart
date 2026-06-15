import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/progress_models.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/widgets.dart';
import 'lift_widgets.dart';
import 'progress_format.dart';
import 'progress_providers.dart';

/// Progress — a glance layer over `GET /api/me/progress/overview` (PHASE-1 §3 IA), plus a
/// conditional Body section that loads independently.
///   1. This week — DARK HERO panel: headline verdict line + adherence ring
///   2. Strength — top-lift e1RM direction strip (each row taps through to the per-lift drill-down)
///   3. Consistency — 12-week blue heatmap + big % / streak
///   4. Personal records — a display-only PR teaser (brand trophy)
///   5. Body — bodyweight trend (Section 5, conditional) — watches `bodyweightSeriesProvider`,
///      renders a smoothed EMA line or a log-your-weight invite; quiet on error, never blocks §1–4.
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
              // Bespoke hero-shaped skeleton (design `LoadingBody`) — NOT the generic GbSkeletonList.
              loading: () => const _LoadingBody(),
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
                          _ThisWeekSection(overview: o),
                          const SizedBox(height: AppSpacing.lg),
                          _StrengthSection(lifts: o.topLifts),
                          const SizedBox(height: AppSpacing.lg),
                          _ConsistencySection(consistency: o.consistency),
                          const SizedBox(height: AppSpacing.lg),
                          _PrSection(prs: o.recentPrs),
                          const SizedBox(height: AppSpacing.lg),
                          // Section 5 (conditional). Each watches its own provider, so a slow/absent
                          // metrics/nutrition endpoint never blocks the overview above.
                          const _BodySection(),
                          const SizedBox(height: AppSpacing.lg),
                          const _NutritionSection(),
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

/// A mono uppercase micro-label (design `.gb-label`) — JetBrains Mono, 10px / 600 / +0.12em, tracked.
/// The Progress tab's tracked caption channel (eyebrows, hero sub-labels, heatmap legend).
class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.color, this.fontSize});
  final String text;
  final Color? color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    var style = AppText.monoLabel().copyWith(color: color ?? context.gb.progInk3);
    if (fontSize != null) style = style.copyWith(fontSize: fontSize);
    return Text(text.toUpperCase(), style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// Section header (design `SectionTitle`) — a 3px brand keyline, an uppercase 12.5/800 ink title, and
/// a flex hairline rule. The recurring brand signature down the page. (The design's optional right
/// action links to drill-down screens this Phase-1 flow doesn't route to, so it is intentionally
/// omitted — the page adds no navigation it can't honour.)
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

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
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: gb.progInk,
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(child: Container(height: 1, color: gb.progLine)),
      ],
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
    const heroTrack = Color(0x38FFFFFF); // --hero-track (rgba(255,255,255,0.22))
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
            const _MonoLabel('This week', color: heroMut),
            const SizedBox(height: AppSpacing.sm),
            // The verdict headline — green (hero-pos) or neutral white, NEVER red (PHASE-1 §1 card 1a).
            _HeadlineText(overview: overview, fg: heroFg, pos: const Color(0xFF74E6B0)),
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
  const _HeadlineText({required this.overview, required this.fg, required this.pos});
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
  return remaining == 1 ? '1 session to your goal' : '$remaining sessions to your goal';
}

/// "2 days left · rest days count" / "Last day · rest days count" — a forgiving nudge, only with a plan.
String _daysLeftCaption(WeekAdherence week) {
  final start = week.weekStart;
  if (start == null) return 'Rest days count';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekEnd = DateTime(start.year, start.month, start.day)
      .add(const Duration(days: 6));
  final left = weekEnd.difference(today).inDays;
  final leftPart = left <= 0
      ? 'Last day'
      : (left == 1 ? '1 day left' : '$left days left');
  return '$leftPart · rest days count';
}

// ── Section 2 — Strength (top-lift direction strip) ─────────────────────────

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.lifts});
  final List<LiftDirection> lifts;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final stall = _stallCallout(lifts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Strength'),
        const SizedBox(height: AppSpacing.sm),
        if (lifts.isEmpty)
          const _QuietCard(
            text: 'Log a few working sets to see your strength trend.',
          )
        else
          _ProgCard(
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
          ),
      ],
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

/// A hairline rule inset to match the card's horizontal row padding (design `.rule` with `0 14px`).
class _RuleInset extends StatelessWidget {
  const _RuleInset({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Container(height: 1, color: color));
}

/// A single lift row: name · big e1RM (+ "est. 1RM") · gradient sparkline (donut endpoint; dots-only
/// for <4 pts) · the mono DirTag (PHASE-1 §1 card 2). Tapping it opens the per-lift e1RM drill-down
/// (`/progress/lift/:exerciseId`, Phase 2). Wrapped in an [InkWell] so the ripple and the
/// dividers/padding inside the strip card stay intact.
class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.lift});
  final LiftDirection lift;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final spark = lift.sparkE1rmKg;
    final few = spark.length < 4;
    return InkWell(
      onTap: () => context.push('/progress/lift/${lift.exerciseId}'),
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
                  const SizedBox(height: 5),
                  if (few)
                    _MonoLabel('Log a few more to see trend',
                        color: gb.progInk3, fontSize: 10.5)
                  else
                    // Big e1RM with a kg unit suffix + an "est. 1RM" micro-label.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: fmtKg(lift.currentE1rmKg),
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
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Gradient-filled sparkline (donut endpoint), or dots-only for thin data.
            SizedBox(
              width: 64,
              height: 28,
              child: _Sparkline(
                points: spark,
                color: sparkColor(gb, lift.direction),
                cardColor: gb.card,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            LiftDirectionTag(
              direction: lift.direction,
              stalled: lift.stalled,
              stallSessions: lift.stallSessions,
            ),
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
                  style: TextStyle(color: gb.progWarn, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ]),
              style: TextStyle(fontSize: 12.5, height: 1.35, color: gb.progInk2),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Consistency'),
        const SizedBox(height: AppSpacing.sm),
        _ProgCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big % + flame streak header — only the parts the data honestly supports.
              if (pct != null || streak > 0) ...[
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
                            _MonoLabel('Hit goal · last 12 wks', color: gb.progInk3),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    if (streak > 0) _StreakChip(streak: streak),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              SizedBox(
                height: 92,
                width: double.infinity,
                child: _Heatmap(
                  days: consistency.days,
                  windowWeeks: consistency.windowWeeks,
                  ramp: gb.progHeatRamp,
                  nullCell: gb.progLine,
                ),
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
          style: AppText.mono(const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
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
        _MonoLabel('Less', color: label, fontSize: 8.5),
        const SizedBox(width: 5),
        for (final c in ramp) ...[
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(2.5)),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 2),
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

/// A display-only PR teaser row (design) — a brand trophy IconTile (brand-soft fill), the lift name +
/// a "New best" mono tag (top row only), and a mono caption "140 kg × 3 · est. 1RM 153 · 2d ago". No
/// tap-through in Phase 1 (PHASE-1 §1 card 4).
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
              border: Border.all(color: gb.primary600.withValues(alpha: 0.22)),
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
                      _MonoLabel('New best', color: gb.progBrandInk, fontSize: 9),
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
    final unitSuffix =
        (series.unit != null && series.unit!.isNotEmpty) ? ' ${series.unit}' : '';

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
              style: AppText.mono(const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                  .copyWith(color: gb.progInk2),
            )
          else
            // No goal yet → the minimal set-a-goal affordance (Phase 3 §1 empty state).
            _SetGoalAffordance(
              onTap: () => _showSetGoalWeightSheet(context, ref, initialKg: latest),
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
                style: AppText.mono(const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                )).copyWith(color: gb.progPos)),
            const SizedBox(width: AppSpacing.xxs),
            Icon(Icons.edit_outlined, size: AppSizes.iconXs, color: gb.progInk4),
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
            Icon(Icons.flag_outlined, size: AppSizes.iconMd, color: gb.primary600),
            const SizedBox(width: AppSpacing.xs),
            Text('Set a goal weight',
                style: AppText.label.copyWith(color: gb.primary600, fontSize: 13)),
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
    final plotH = (size.height - topPad - bottomPad).clamp(1.0, double.infinity);

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
      await widget.parentRef
          .read(progressRepositoryProvider)
          .setGoalWeight(kg);
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!,
                style: AppText.meta.copyWith(color: gb.danger)),
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

// ── Section 5b — Nutrition adherence (conditional) ───────────────────────────

/// Recent nutrition adherence (MOBILE-DASHBOARD §5 / Decision **D13**). A `ConsumerWidget` watching
/// its own `nutritionAdherenceProvider`, so it loads independently and **never blocks §1–4**. When
/// `hasPlan` is false the trainee follows no meal plan → a "follow a meal plan" invite (never a 0%
/// ring). With a plan + closed days it renders a compact current-week ring + a 7-day bar strip.
/// **Quiet** on loading and error (collapses to nothing) — adherence is opt-in evidence, not a
/// headline. Styled to the Graphite system: a surf-quiet invite, and a surf card for the populated
/// state, consistent with the Body section.
class _NutritionSection extends ConsumerWidget {
  const _NutritionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherence = ref.watch(nutritionAdherenceProvider);
    return adherence.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (a) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Nutrition'),
            const SizedBox(height: AppSpacing.sm),
            if (!a.hasPlan)
              // Empty-state invite — no plan, so no adherence to chart (never a 0% ring).
              const _QuietCard(
                text: 'Follow a meal plan to track nutrition adherence.',
              )
            else if (a.isEmpty)
              const _QuietCard(
                text: 'Close out a day to see your nutrition adherence.',
              )
            else
              _NutritionAdherenceCard(adherence: a),
          ],
        );
      },
    );
  }
}

/// The populated nutrition card: a current-week adherence ring (when the server rolled one up) beside
/// a compact 7-day bar strip + a caption. Graphite tokens, mono caption.
class _NutritionAdherenceCard extends StatelessWidget {
  const _NutritionAdherenceCard({required this.adherence});
  final NutritionAdherence adherence;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final weekPct = adherence.currentWeekAvgPct;
    // Recent days, most-recent last; the strip shows the trailing 7.
    final recent = adherence.recentDays.length > 7
        ? adherence.recentDays.sublist(adherence.recentDays.length - 7)
        : adherence.recentDays;

    return _ProgCard(
      child: Row(
        children: [
          if (weekPct != null) ...[
            GbRing(
              value: (weekPct / 100).clamp(0.0, 1.0),
              size: 64,
              stroke: 7,
              gradient: [gb.progRing, gb.primary700],
              trackColor: gb.progLine,
              child: Text(
                '$weekPct%',
                style: AppText.mono(const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800))
                    .copyWith(color: gb.progInk),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _MonoLabel('This week', color: gb.progInk3),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: _AdherenceStrip(
                    days: recent,
                    bar: gb.progRing,
                    track: gb.progLine,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _adherenceCaption(weekPct, recent),
                  style: AppText.mono(const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                      .copyWith(color: gb.progInk2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Avg 84% this week · 5 days logged" / a recent-days fallback when there's no week roll-up.
String _adherenceCaption(int? weekPct, List<DailyAdherence> recent) {
  final n = recent.length;
  final logged = '$n ${n == 1 ? 'day' : 'days'} logged';
  if (weekPct != null) return 'Avg $weekPct% this week · $logged';
  return logged;
}

/// A compact 7-day adherence bar strip — one bar per recent day, height ∝ that day's %. CustomPaint,
/// no chart library (D11). A track baseline keeps the strip legible on low-adherence days.
class _AdherenceStrip extends StatelessWidget {
  const _AdherenceStrip({
    required this.days,
    required this.bar,
    required this.track,
  });
  final List<DailyAdherence> days;
  final Color bar;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AdherenceStripPainter(
        pcts: [for (final d in days) d.pct],
        bar: bar,
        track: track,
      ),
      size: Size.infinite,
    );
  }
}

class _AdherenceStripPainter extends CustomPainter {
  _AdherenceStripPainter({
    required this.pcts,
    required this.bar,
    required this.track,
  });
  final List<int> pcts;
  final Color bar;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (pcts.isEmpty) return;
    const gap = 5.0;
    final n = pcts.length;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(2.0, double.infinity);
    final radius = Radius.circular(math.min(3.0, barW / 2));

    for (var i = 0; i < n; i++) {
      final left = i * (barW + gap);
      // Faint full-height track so empty/low days still register as a column.
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barW, size.height),
        radius,
      );
      canvas.drawRRect(trackRect, Paint()..color = track);

      final frac = (pcts[i].clamp(0, 100)) / 100.0;
      final h = (size.height * frac).clamp(0.0, size.height);
      if (h <= 0) continue;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - h, barW, h),
        radius,
      );
      canvas.drawRRect(barRect, Paint()..color = bar);
    }
  }

  @override
  bool shouldRepaint(_AdherenceStripPainter old) =>
      old.bar != bar ||
      old.track != track ||
      !listEquals(old.pcts, pcts);
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
      child: Text(text,
          style: AppText.body.copyWith(color: gb.progInk3, height: 1.45)),
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
    (icon: Icons.show_chart, title: 'Strength trend', subtitle: 'Each lift, week over week'),
    (icon: Icons.calendar_today_outlined, title: 'Consistency', subtitle: 'A heatmap of every session'),
    (icon: Icons.emoji_events_outlined, title: 'Personal records', subtitle: 'Every new best, by the lift'),
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

/// The design `LoadingBody`: a hero-shaped skeleton (the navy gradient panel with translucent-white
/// shimmer placeholders + a circle for the ring), then a surf card with 3 lift-row skeletons, then a
/// surf card with a big bar + a 12×7 heatmap-grid skeleton. Kept inside a scrollable so pull-to-refresh
/// stays engaged. Reuses [GbSkeleton] for the on-card shimmer; the hero placeholders are static
/// translucent-white blocks so they read over the gradient (the grey skeleton fill would vanish there).
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
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
                const _LoadingHero(),
                const SizedBox(height: AppSpacing.lg),
                // Strength card skeleton — 3 lift-row placeholders.
                _ProgCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) _RuleInset(color: gb.progLine2),
                        const _LoadingLiftRow(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Consistency card skeleton — a big bar + a 12×7 heatmap grid.
                const _ProgCard(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GbSkeleton(width: 120, height: 28, radius: 7),
                      SizedBox(height: 18),
                      _LoadingHeatmapGrid(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero-panel skeleton: the navy gradient block with translucent-white shimmer lines and a circle
/// standing in for the adherence ring.
class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  static const _heroLine = Color(0x2EFFFFFF); // --hero-line
  static const _ph1 = Color(0x1FFFFFFF); // ~0.12 white placeholder
  static const _ph2 = Color(0x1AFFFFFF); // ~0.10 white placeholder

  Widget _bar(double widthFactor, double height, Color color) => FractionallySizedBox(
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
  const _Sparkline({required this.points, required this.color, required this.cardColor});
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
    canvas.drawCircle(last, 4.4, Paint()..color = color.withValues(alpha: 0.16));
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
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) * t, p1.dy + (p2.dy - p0.dy) * t);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) * t, p2.dy - (p3.dy - p1.dy) * t);
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

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-label column (M / · / W / · / F / · / ·).
        SizedBox(
          width: 9,
          child: CustomPaint(
            size: const Size(9, 92),
            painter: _HeatLabelPainter(color: gb.progInk4),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: CustomPaint(
            painter: _HeatmapPainter(
              counts: _countsByDay(days),
              weeks: windowWeeks <= 0 ? 12 : windowWeeks,
              ramp: ramp,
              nullCell: nullCell,
            ),
            size: Size.infinite,
          ),
        ),
      ],
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
    required this.ramp,
    required this.nullCell,
  });
  final Map<DateTime, int> counts;
  final int weeks;
  final List<Color> ramp;
  final Color nullCell;

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 7; // Mon..Sun
    const gap = 4.5;
    final cols = weeks;
    final cell = math.min((size.width - gap * (cols - 1)) / cols,
        (size.height - gap * (rows - 1)) / rows);
    if (cell <= 0) return;

    final gridW = cell * cols + gap * (cols - 1);
    final startX = (size.width - gridW) / 2;

    // Monday of the current week, in local time.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday =
        mondayThisWeek.subtract(Duration(days: 7 * (cols - 1)));

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
