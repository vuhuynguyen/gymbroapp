import 'package:flutter/material.dart';

import '../../data/models/coach_models.dart';
import '../../shared/widgets/widgets.dart';

/// The roster triage chip — Quiet = amber/danger (re-engage today), Drifting = warning (nudge), On
/// track = success (skip). Quiet uses the amber soft-tint as the strongest at-risk cue. Shared by the
/// coach roster row ([CoachProgressScreen]) and the per-client strength verdict header
/// ([ClientStrengthScreen]) so the status mapping lives in exactly one place.
class RosterStatusBadge extends StatelessWidget {
  const RosterStatusBadge({required this.status, super.key});
  final RosterStatus status;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg, label) = switch (status) {
      RosterStatus.quiet => (gb.amberSoft, gb.amberInk, 'Quiet'),
      RosterStatus.drifting => (gb.warning0, gb.warning300, 'Drifting'),
      RosterStatus.onTrack => (gb.success0, gb.success, 'On track'),
    };
    return GbStatusBadge(label: label, background: bg, foreground: fg);
  }
}
