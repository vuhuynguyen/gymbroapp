import 'package:flutter/material.dart';

import '../../data/models/progress_models.dart';
import '../../shared/widgets/widgets.dart';

/// Feature-local formatting + colour helpers shared across the Progress surfaces (home strip, per-lift
/// drill-down, coach per-client strength). Previously these two helpers were copy-pasted into each of
/// those files; promoting them here keeps the trend numbers and direction tints identical everywhere.

/// Format a kg value: drop a trailing `.0`, otherwise one decimal ("96", "153.5"). Used for axis
/// labels, e1RM headlines, and goal/distance captions across the trend surfaces so they read alike.
String fmtKg(double kg) {
  final s = kg.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// The direction-tint for a lift's e1RM **trend-LINE** — `down` is the only state that maps to red, and
/// only at the lift level (never page-wide, PHASE-1 §5). Drives the per-lift drill-down and coach
/// strength chart lines/legends. The home-strip sparkline and the [LiftDirectionTag] caret/label use the
/// design's honest [sparkColor] channel instead (see below); this tint stays on the thicker chart lines.
Color tagColor(GbColors gb, LiftTrendDirection dir) => switch (dir) {
      LiftTrendDirection.up => gb.emeraldInk,
      LiftTrendDirection.down => gb.danger,
      LiftTrendDirection.flat => gb.grey500,
    };

/// The Progress "Graphite" honest channel — the design's deep pos / warn / neg signals (color on the
/// stroke / fill / text only). Up reads positive-green (`#157A4A`), flat reads warn-amber (`#8A6312`, an
/// attention tone, not failure), down reads negative-red (`#AD3B32`). Drives BOTH the home strip's
/// gradient-filled sparkline AND the [LiftDirectionTag] caret + label, so the tick and the thin chart
/// share one tint per row — matching the design's `DirTag`/`Caret` (`--pos`/`--warn`/`--neg`).
Color sparkColor(GbColors gb, LiftTrendDirection dir) => switch (dir) {
      LiftTrendDirection.up => gb.progPos,
      LiftTrendDirection.down => gb.progNeg,
      LiftTrendDirection.flat => gb.progWarn,
    };
