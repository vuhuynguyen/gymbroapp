import 'package:flutter/material.dart';

import '../widgets/widgets.dart';

/// Shared superset grouping — turns a workout's exercises (each with an id, order, and optional
/// superset group id) into per-exercise tags: a group letter (A, B, …), the 1-based position within
/// the group, the group size, and the peer to rotate to next. Used by the plan views (show the
/// grouping) and the live session (the "next up" rotation cue). The backend models a superset as a
/// shared non-null `supersetGroupId` across consecutive exercises; a group with fewer than two
/// members is not a real superset and gets no tag.

/// A minimal projection of an exercise for grouping — works for both plan and performed exercises.
@immutable
class SupersetMember {
  const SupersetMember({
    required this.id,
    required this.order,
    required this.groupId,
    this.name,
  });
  final String id;
  final int order;
  final String? groupId;
  final String? name;
}

/// One exercise's superset membership: which group, where in the rotation, and what comes next.
@immutable
class SupersetTag {
  const SupersetTag({
    required this.letter,
    required this.position,
    required this.size,
    this.nextName,
    this.nextId,
  });

  /// Group label by first appearance in the workout (A, B, C, …).
  final String letter;

  /// 1-based position within the group (the rotation order).
  final int position;

  /// Number of exercises in the group.
  final int size;

  /// The peer to rotate to after this one (wraps back to the first after the last).
  final String? nextName;
  final String? nextId;

  /// e.g. "A1" — the group letter + position.
  String get code => '$letter$position';

  /// True for the last exercise in the round — after it the session rests, then resumes at the first.
  bool get isLastInRound => position == size;
}

/// Map exercise id → [SupersetTag] for every superset member. Standalone exercises (and degenerate
/// one-member groups) are absent from the map. Groups are lettered by their first appearance in
/// ascending [SupersetMember.order]; members within a group keep that same order as their position.
Map<String, SupersetTag> supersetTags(List<SupersetMember> members) {
  final ordered = [...members]..sort((a, b) => a.order.compareTo(b.order));

  final groups = <String, List<SupersetMember>>{};
  for (final m in ordered) {
    final g = m.groupId;
    if (g == null) continue;
    (groups[g] ??= []).add(m);
  }

  // Letter only the real (2+ member) groups, in order of first appearance.
  final letters = <String, String>{};
  var next = 0;
  for (final m in ordered) {
    final g = m.groupId;
    if (g == null || (groups[g]?.length ?? 0) < 2) continue;
    letters.putIfAbsent(g, () => String.fromCharCode(65 + (next++ % 26)));
  }

  final out = <String, SupersetTag>{};
  for (final entry in letters.entries) {
    final list = groups[entry.key]!;
    for (var i = 0; i < list.length; i++) {
      final nxt = list[(i + 1) % list.length];
      out[list[i].id] = SupersetTag(
        letter: entry.value,
        position: i + 1,
        size: list.length,
        nextName: nxt.name,
        nextId: nxt.id,
      );
    }
  }
  return out;
}

/// Compact superset chip — "⇄ A1" — a tinted brand pill that visually groups superset members in a
/// plan list (same letter = same superset; the number is the rotation order).
class SupersetChip extends StatelessWidget {
  const SupersetChip(this.tag, {super.key});
  final SupersetTag tag;

  @override
  Widget build(BuildContext context) {
    final c = context.gb.primary600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '⇄ ${tag.code}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Live-session superset cue — a tinted strip that spells out the rotation for the current exercise:
/// "Superset A · 1 of 2 — then [next peer], no rest" mid-round, or "… — then rest, back to [first]" on
/// the last exercise of the round. Mirrors exactly what the live controller does after a logged set.
class SupersetCue extends StatelessWidget {
  const SupersetCue(this.tag, {super.key});
  final SupersetTag tag;

  @override
  Widget build(BuildContext context) {
    final c = context.gb.primary600;
    final next = tag.nextName ?? 'the next exercise';
    final action =
        tag.isLastInRound ? 'then rest, back to $next' : 'then $next — no rest';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 12.5, height: 1.3, color: context.gb.grey700),
                children: [
                  TextSpan(
                    text: 'Superset ${tag.letter} · ${tag.position} of '
                        '${tag.size} — ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: c),
                  ),
                  TextSpan(text: action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
