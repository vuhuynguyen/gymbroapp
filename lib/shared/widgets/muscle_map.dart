import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'muscle_map_paths.dart';

/// Muscle-activation figure — front + back anatomical body with the exercise's worked muscles highlighted as a
/// **red heat-map** (primary = solid red, secondary = light red, the rest neutral). The vector anatomy is from
/// `react-native-body-highlighter` (MIT — see `THIRD_PARTY_NOTICES.md`); we recolor *individual* muscles by
/// involvement and render via `flutter_svg`.
///
/// Our catalog now carries the *specific* worked muscles per exercise (`detailedPrimary`/`detailedSecondary`,
/// e.g. `['hamstring']` for a leg curl). When present, those drive the heat-map directly — accurate by data, not
/// guesswork. We only fall back to inferring muscles from the exercise name, then to lighting the whole coarse
/// group (Chest/Back/Shoulders/Arms/Legs/Core), when the catalog doesn't carry specifics.
/// See `docs/master-data/MEDIA_STRATEGY.md` §1.
class MuscleMapFigure extends StatelessWidget {
  const MuscleMapFigure({
    required this.exerciseName,
    required this.primary,
    required this.secondary,
    this.detailedPrimary = const [],
    this.detailedSecondary = const [],
    super.key,
  });

  /// Exercise name (drives the specific-muscle heuristic, e.g. "Lying Leg Curl" → hamstrings).
  final String exerciseName;

  /// Coarse worked muscle names flagged primary (e.g. `['Legs']`).
  final List<String> primary;

  /// Coarse worked muscle names flagged secondary.
  final List<String> secondary;

  /// Specific (fine) muscle slugs from the catalog, flagged primary — preferred over the name heuristic.
  final List<String> detailedPrimary;

  /// Specific (fine) muscle slugs from the catalog, flagged secondary.
  final List<String> detailedSecondary;

  @override
  Widget build(BuildContext context) {
    final involve = muscleMapInvolvement(
      exerciseName,
      primary,
      secondary,
      detailedPrimary: detailedPrimary,
      detailedSecondary: detailedSecondary,
    );
    if (involve.values.every((v) => v == 0)) return const SizedBox.shrink();
    return SvgPicture.string(_buildSvg(involve), fit: BoxFit.contain);
  }
}

/// Whether the supplied muscle data maps onto any body region (else there's nothing to draw). Catalog-supplied
/// specific muscles count too — they resolve via [_canon] even when the coarse names wouldn't.
bool muscleMapHasContent(
  List<String> primary,
  List<String> secondary, {
  List<String> detailedPrimary = const [],
  List<String> detailedSecondary = const [],
}) =>
    [...detailedPrimary, ...detailedSecondary].any((m) => _canon(m) != null) ||
    [...primary, ...secondary].any((m) => _fineSetFor(m).isNotEmpty);

// Red heat-map palette (a fixed diagram palette, not theme-tinted).
const String _primaryFill = '#DC2626';
const String _secondaryFill = '#F87171';
const String _baseFill = '#D7DCE3';
const String _structFill = '#EAEDF1';
const String _stroke = '#AAB3C0';

// Individual muscles, in draw order.
const List<String> _fine = [
  'chest', 'obliques', 'abs', 'biceps', 'triceps', 'forearm', 'trapezius', 'deltoids',
  'upper-back', 'lower-back', 'adductors', 'quadriceps', 'tibialis', 'calves', 'hamstring', 'gluteal',
];

// Coarse group keyword → the muscles it spans (used as the fallback when the movement is unknown).
const Map<String, List<String>> _groupFine = {
  'chest': ['chest'],
  'core': ['abs', 'obliques'],
  'arm': ['biceps', 'triceps', 'forearm'],
  'shoulder': ['deltoids'],
  'back': ['upper-back', 'lower-back', 'trapezius'],
  'leg': ['quadriceps', 'hamstring', 'gluteal', 'calves', 'adductors', 'tibialis'],
};

/// Per-muscle involvement (0 none, 1 secondary, 2 primary). Public for tests.
///
/// Resolution order, most-trustworthy first: (1) catalog-supplied specific muscles
/// [detailedPrimary]/[detailedSecondary]; (2) the exercise-name heuristic; (3) the coarse group names.
Map<String, int> muscleMapInvolvement(
  String exerciseName,
  List<String> primary,
  List<String> secondary, {
  List<String> detailedPrimary = const [],
  List<String> detailedSecondary = const [],
}) {
  final m = {for (final f in _fine) f: 0};

  // 0. Catalog-supplied specific muscles (data-driven — accurate, no guessing).
  if (detailedPrimary.isNotEmpty || detailedSecondary.isNotEmpty) {
    for (final raw in detailedSecondary) {
      final f = _canon(raw);
      if (f != null) m[f] = 1;
    }
    for (final raw in detailedPrimary) {
      final f = _canon(raw);
      if (f != null) m[f] = 2;
    }
    if (m.values.any((v) => v != 0)) return m;
  }

  // 1. Specific-muscle heuristic from the exercise name (most accurate of the inferred paths).
  final h = _exerciseHeuristic(exerciseName);
  if (h != null) {
    for (final f in h[1]) {
      if (m.containsKey(f)) m[f] = 1;
    }
    for (final f in h[0]) {
      if (m.containsKey(f)) m[f] = 2;
    }
    return m;
  }

  // 2. Fall back to the coarse muscle names (fine if recognised, else the whole group).
  void apply(List<String> names, int level) {
    for (final raw in names) {
      for (final f in _fineSetFor(raw)) {
        m[f] = level;
      }
    }
  }

  apply(secondary, 1);
  apply(primary, 2);
  return m;
}

/// One (coarse or fine) muscle name → the individual muscles it implies.
List<String> _fineSetFor(String raw) {
  final n = raw.toLowerCase();
  final fine = _fineFromName(n);
  if (fine != null) return [fine];
  for (final e in _groupFine.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return const [];
}

/// A catalog muscle token → its canonical fine slug. Exact slug match first (the catalog already speaks our 16
/// slugs), else the fuzzy name map so authored / API-coarse names still resolve.
String? _canon(String s) {
  final n = s.toLowerCase().trim();
  if (n.isEmpty) return null;
  if (_fine.contains(n)) return n;
  return _fineFromName(n);
}

/// A specific muscle name (possibly fine-grained / authored) → its canonical muscle slug.
String? _fineFromName(String n) {
  if (n.contains('hamstring')) return 'hamstring';
  if (n.contains('quad')) return 'quadriceps';
  if (n.contains('glute')) return 'gluteal';
  if (n.contains('calf') || n.contains('calve') || n.contains('gastro') || n.contains('soleus')) return 'calves';
  if (n.contains('adductor') || n.contains('inner thigh') || n.contains('groin')) return 'adductors';
  if (n.contains('tibialis') || n.contains('shin')) return 'tibialis';
  if (n.contains('bicep')) return 'biceps';
  if (n.contains('tricep')) return 'triceps';
  if (n.contains('forearm') || n.contains('brachi')) return 'forearm';
  if (n.contains('trap')) return 'trapezius';
  if (n.contains('delt') || n.contains('shoulder')) return 'deltoids';
  if (n.contains('lat') || n.contains('upper back') || n.contains('rhombo')) return 'upper-back';
  if (n.contains('lower back') || n.contains('erector') || n.contains('spinae')) return 'lower-back';
  if (n.contains('oblique')) return 'obliques';
  if (n.contains('abdom') || n == 'abs' || n.contains('rectus') || n.contains('core')) return 'abs';
  if (n.contains('pec') || n.contains('chest')) return 'chest';
  return null;
}

/// Exercise name → [primaryMuscles, secondaryMuscles] (specific). Ordered most-specific first.
List<List<String>>? _exerciseHeuristic(String name) {
  final n = name.toLowerCase();
  bool has(List<String> ks) => ks.any(n.contains);

  if (has(['leg curl', 'hamstring curl', 'lying curl', 'seated curl', 'nordic'])) {
    return [['hamstring'], ['gluteal', 'calves']];
  }
  if (has(['leg extension', 'knee extension', 'quad extension'])) return [['quadriceps'], []];
  if (has(['calf'])) return [['calves'], []];
  if (has(['hip thrust', 'glute bridge', 'glute kick', 'hip extension', 'glute'])) {
    return [['gluteal'], ['hamstring']];
  }
  if (has(['romanian', 'rdl', 'stiff leg', 'stiff-leg', 'good morning'])) {
    return [['hamstring', 'gluteal'], ['lower-back']];
  }
  if (has(['deadlift'])) return [['hamstring', 'gluteal'], ['lower-back', 'upper-back', 'trapezius']];
  if (has(['squat', 'leg press', 'hack ', 'lunge', 'split squat', 'step up', 'step-up', 'bulgarian'])) {
    return [['quadriceps', 'gluteal'], ['hamstring', 'adductors', 'calves']];
  }
  if (has(['adduction', 'adductor'])) return [['adductors'], []];
  if (has(['abduction', 'abductor'])) return [['gluteal'], []];
  // Rear-delt work must come before chest (both contain "fly").
  if (has(['face pull', 'rear delt', 'reverse fly', 'reverse pec'])) return [['deltoids'], ['upper-back']];
  if (has(['bench', 'chest press', 'chest fly', 'pec ', 'push up', 'push-up', 'pushup', 'dip', 'fly'])) {
    return [['chest'], ['triceps', 'deltoids']];
  }
  if (has(['pulldown', 'pull up', 'pull-up', 'pullup', 'chin up', 'chin-up', 'row', ' lat '])) {
    return [['upper-back'], ['biceps']];
  }
  if (has(['shrug'])) return [['trapezius'], []];
  if (has(['hyperextension', 'back extension', 'superman'])) return [['lower-back'], ['gluteal', 'hamstring']];
  if (has(['shoulder press', 'overhead press', 'military', 'arnold', 'lateral raise', 'front raise', 'shoulder'])) {
    return [['deltoids'], ['triceps']];
  }
  if (has(['tricep', 'pushdown', 'skull', 'kickback', 'close grip', 'close-grip'])) return [['triceps'], []];
  if (has(['curl', 'bicep'])) return [['biceps'], ['forearm']]; // arm curls (leg curl handled above)
  if (has(['crunch', 'sit up', 'sit-up', 'situp', 'plank', 'leg raise', 'knee raise', 'russian twist', 'hanging', 'ab wheel', 'rollout', 'toes to bar'])) {
    return [['abs'], ['obliques']];
  }
  if (has(['oblique', 'side bend', 'woodchop', 'wood chop'])) return [['obliques'], ['abs']];
  return null;
}

String _buildSvg(Map<String, int> involve) {
  final b = StringBuffer('<svg viewBox="$muscleMapViewBox" xmlns="http://www.w3.org/2000/svg">')
    ..write('<g stroke="$_stroke" stroke-width="1.4" stroke-linejoin="round">');

  void emit(Map<String, List<String>> side) {
    for (final d in side['Structure'] ?? const <String>[]) {
      b.write('<path d="$d" fill="$_structFill"/>');
    }
    for (var state = 0; state <= 2; state++) {
      final fill = state == 2 ? _primaryFill : (state == 1 ? _secondaryFill : _baseFill);
      for (final mu in _fine) {
        if ((involve[mu] ?? 0) != state) continue;
        for (final d in side[mu] ?? const <String>[]) {
          b.write('<path d="$d" fill="$fill"/>');
        }
      }
    }
  }

  emit(muscleMapFront);
  emit(muscleMapBack);
  b.write('</g></svg>');
  return b.toString();
}
