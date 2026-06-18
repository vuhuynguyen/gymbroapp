import '../../data/models/exercise_models.dart';

/// Resolved Form Coach guide for one exercise — the content model from the design's
/// `exercise-guidance/guide-data.jsx`. The API only models instructions / muscles / warnings, so
/// authored coaching copy (tempo, breathing, setup, cues, common mistakes, safety) is merged in
/// from [_coachGuideLibrary] when an exercise is known, with the live API detail always preferred
/// for the fields it does carry.
class CoachGuide {
  const CoachGuide({
    required this.name,
    this.cue,
    this.difficulty,
    this.equipment,
    this.primary = const [],
    this.secondary = const [],
    this.setup = const [],
    this.steps = const [],
    this.tempo,
    this.breathing,
    this.cues = const [],
    this.mistakes = const [],
    this.safety,
    this.imageUrl,
    this.detailedPrimary = const [],
    this.detailedSecondary = const [],
  });

  final String name;

  /// Single highest-value coaching line shown on the zero-tap form-cue strip.
  final String? cue;
  final String? difficulty;
  final String? equipment;
  final List<String> primary;
  final List<String> secondary;
  final List<String> setup;
  final List<String> steps;
  final String? tempo;
  final String? breathing;
  final List<String> cues;
  final List<String> mistakes;

  /// Single safety callout (yellow). API warnings collapse into this when present.
  final String? safety;
  final String? imageUrl;

  /// Specific (fine) muscle slugs for the activation map (data-driven; beats the name heuristic).
  final List<String> detailedPrimary;
  final List<String> detailedSecondary;

  /// Whether there's enough content for the tabbed guide vs the "coming soon" card. Mirrors the
  /// design's `_full` gate, but our partial API-derived guides also qualify on steps/mistakes/safety.
  bool get hasTabs =>
      steps.isNotEmpty ||
      setup.isNotEmpty ||
      cues.isNotEmpty ||
      mistakes.isNotEmpty ||
      safety != null;
}

/// The single coaching cue for an exercise's form-cue strip, if one is authored.
String? authoredCueFor(String? exerciseName) =>
    exerciseName == null ? null : _coachGuideLibrary[exerciseName]?.cue;

/// Merge authored coaching content with the live [detail]. The API wins for every field it carries;
/// authored copy fills the gaps (tempo, breathing, setup, cues, mistakes) the API doesn't model.
CoachGuide resolveCoachGuide(ExerciseDetail detail) {
  final authored = _coachGuideLibrary[detail.name];
  final apiPrimary = detail.primaryMuscles.map((m) => m.name).toList();
  final apiSecondary = detail.secondaryMuscles.map((m) => m.name).toList();

  return CoachGuide(
    name: detail.name,
    cue: authored?.cue,
    difficulty:
        detail.difficulty.isNotEmpty ? detail.difficulty : authored?.difficulty,
    equipment:
        detail.equipment.isNotEmpty ? detail.equipment : authored?.equipment,
    primary: apiPrimary.isNotEmpty
        ? apiPrimary
        : (authored?.primary.isNotEmpty == true
            ? authored!.primary
            : (detail.muscleGroup.isNotEmpty ? [detail.muscleGroup] : const [])),
    secondary: apiSecondary.isNotEmpty
        ? apiSecondary
        : (authored?.secondary ?? const []),
    setup: authored?.setup ?? const [],
    steps: detail.instructions.isNotEmpty
        ? detail.instructions
        : (authored?.steps ?? const []),
    tempo: authored?.tempo,
    breathing: authored?.breathing,
    cues: authored?.cues ?? const [],
    mistakes: authored?.mistakes ?? const [],
    // API warnings collapse into the single safety callout; otherwise use the authored note.
    safety:
        detail.warnings.isNotEmpty ? detail.warnings.join('\n') : authored?.safety,
    imageUrl: detail.heroImageUrl,
    detailedPrimary: detail.detailedPrimaryMuscles,
    detailedSecondary: detail.detailedSecondaryMuscles,
  );
}

/// Authored coaching content keyed by exact exercise name — ported verbatim from the design's
/// `COACH_GUIDE` (exercise-guidance/guide-data.jsx). Pending API support for these richer fields.
const Map<String, CoachGuide> _coachGuideLibrary = {
  'Barbell Bench Press': CoachGuide(
    name: 'Barbell Bench Press',
    cue: 'Plant your feet, pinch your shoulder blades, bar to mid-chest',
    difficulty: 'Intermediate',
    primary: ['Chest'],
    secondary: ['Triceps', 'Front delts'],
    equipment: 'Barbell + flat bench',
    setup: [
      'Lie back with your eyes directly under the bar',
      'Pinch your shoulder blades together and tuck them down',
      'Plant both feet flat, slight arch in the lower back',
      'Grip just outside shoulder width, full grip around the bar',
    ],
    steps: [
      'Unrack and hold the bar locked out over your chest',
      'Lower under control to your mid-chest / nipple line',
      'Touch lightly — never bounce the bar',
      'Press up and slightly back toward your face to lockout',
    ],
    tempo: '2s down · 1s up',
    breathing: 'Inhale on the way down, exhale as you press',
    cues: [
      'Feel the stretch then the squeeze across your chest',
      'Keep wrists stacked over your elbows',
      'Tuck elbows to ~45°, not flared out to 90°',
      'Keep your hips on the bench the entire set',
    ],
    mistakes: [
      'Bouncing the bar off your chest for momentum',
      'Flaring elbows straight out — strains the shoulder',
      'Lifting your hips off the bench to grind a rep',
    ],
    safety: 'Use a spotter or set the safety pins for working sets near failure.',
  ),
  'Seated Overhead Press': CoachGuide(
    name: 'Seated Overhead Press',
    cue: 'Brace your core and press straight up — don’t lean back',
    difficulty: 'Intermediate',
    primary: ['Shoulders'],
    secondary: ['Triceps', 'Upper chest'],
    equipment: 'Dumbbells + upright bench',
    setup: [
      'Sit tall with your back supported, feet planted',
      'Bring the dumbbells to shoulder height, palms forward',
      'Brace your abs and squeeze your glutes',
    ],
    steps: [
      'Press both dumbbells overhead until your arms are nearly locked',
      'Let them drift slightly together at the top',
      'Lower under control back to shoulder height',
      'Keep your forearms vertical throughout',
    ],
    tempo: '2s down · 1s up',
    breathing: 'Exhale as you press overhead',
    cues: [
      'Feel it in your shoulders, not your lower back',
      'Ribs down — don’t arch to cheat the press',
      'Keep your wrists stacked over your elbows',
    ],
    mistakes: [
      'Leaning back and turning it into an incline press',
      'Pressing the dumbbells too far out in front of you',
      'Shrugging your shoulders up toward your ears',
    ],
    safety: 'If your lower back arches, drop the weight — bracing comes first.',
  ),
  'Incline DB Press': CoachGuide(
    name: 'Incline DB Press',
    cue: 'Bench at ~30°, press up and in over your upper chest',
    difficulty: 'Beginner',
    primary: ['Upper chest'],
    secondary: ['Front delts', 'Triceps'],
    equipment: 'Dumbbells + incline bench',
    setup: [
      'Set the bench to roughly 30°',
      'Kick the dumbbells up to shoulder height with your thighs',
      'Pinch your shoulder blades into the pad',
    ],
    steps: [
      'Press the dumbbells up and slightly together',
      'Stop just short of lockout to keep tension on the chest',
      'Lower until you feel a stretch across your upper chest',
      'Keep a slight bend at the bottom',
    ],
    tempo: '2s down · 1s up',
    breathing: 'Inhale down, exhale up',
    cues: [
      'Drive through the upper chest, not the front delts',
      'Keep your elbows ~45° to your torso',
    ],
    mistakes: [
      'Bench angle too steep — it becomes a shoulder press',
      'Clashing the dumbbells together at the top',
    ],
    safety: 'Control the dumbbells at the bottom — don’t drop into the stretch.',
  ),
  'Cable Fly': CoachGuide(
    name: 'Cable Fly',
    cue: 'Soft, fixed elbows — hug a wide tree and squeeze the middle',
    difficulty: 'Beginner',
    primary: ['Chest'],
    secondary: ['Front delts'],
    equipment: 'Cable machine',
    setup: [
      'Set the pulleys to chest height or just above',
      'Grab the handles and step forward into a split stance',
      'Soft bend in the elbows, lean slightly forward',
    ],
    steps: [
      'Bring both handles together in front of your chest',
      'Imagine hugging a wide tree',
      'Squeeze your chest for a beat at the middle',
      'Open back up until you feel a stretch — keep the tension',
    ],
    tempo: 'Slow & controlled',
    breathing: 'Exhale as you bring the handles together',
    cues: [
      'Keep the elbow angle fixed — it’s a fly, not a press',
      'Lead with your elbows, not your hands',
    ],
    mistakes: [
      'Bending and straightening the elbows — turns it into a press',
      'Too much weight, so the shoulders take over',
    ],
    safety: 'Lighten the load if your shoulders take over the movement.',
  ),
  'Triceps Pushdown': CoachGuide(
    name: 'Triceps Pushdown',
    cue: 'Pin your elbows to your sides — only the forearms move',
    difficulty: 'Beginner',
    primary: ['Triceps'],
    secondary: [],
    equipment: 'Cable machine',
    setup: [
      'Attach a bar or rope to the high pulley',
      'Stand tall with a slight forward lean',
      'Tuck your elbows tight to your sides',
    ],
    steps: [
      'Push the attachment down until your arms are straight',
      'Squeeze your triceps hard at the bottom',
      'Let it rise back to ~90° under control',
      'Keep your elbows pinned the whole time',
    ],
    tempo: '1s down · 2s up',
    breathing: 'Exhale as you push down',
    cues: [
      'Only your forearms should move',
      'Keep your shoulders down and back',
    ],
    mistakes: [
      'Elbows drifting forward — recruits the shoulders',
      'Leaning your whole bodyweight into the bar',
    ],
    safety: null,
  ),
  'Dumbbell Bench Press': CoachGuide(
    name: 'Dumbbell Bench Press',
    cue: 'Press up and in, let the dumbbells stretch your chest at the bottom',
    difficulty: 'Beginner',
    primary: ['Chest'],
    secondary: ['Triceps', 'Front delts'],
    equipment: 'Dumbbells + flat bench',
    setup: [
      'Sit on the end of the bench, dumbbells on your thighs',
      'Kick them up as you lie back, shoulder blades pinned',
      'Plant your feet, dumbbells at chest height',
    ],
    steps: [
      'Press both dumbbells up and slightly together',
      'Stop just short of lockout to keep tension',
      'Lower until you feel a stretch across the chest',
      'Keep your wrists stacked over your elbows',
    ],
    tempo: '2s down · 1s up',
    breathing: 'Inhale down, exhale up',
    cues: [
      'Greater range of motion than a barbell — use it',
      'Keep elbows ~45° to the torso',
    ],
    mistakes: [
      'Clashing the dumbbells at the top',
      'Dropping fast into the stretch',
    ],
    safety: 'Control the dumbbells at the bottom of every rep.',
  ),
  'Machine Chest Press': CoachGuide(
    name: 'Machine Chest Press',
    cue: 'Set the seat so the handles sit at mid-chest, then press smooth',
    difficulty: 'Beginner',
    primary: ['Chest'],
    secondary: ['Triceps', 'Front delts'],
    equipment: 'Chest-press machine',
    setup: [
      'Adjust the seat so the handles line up with mid-chest',
      'Sit back with your shoulder blades against the pad',
      'Grip the handles, elbows slightly below shoulder height',
    ],
    steps: [
      'Press the handles forward until your arms are nearly straight',
      'Squeeze your chest at the end',
      'Return under control until you feel a stretch',
      'Keep your back against the pad throughout',
    ],
    tempo: '2s out · 2s back',
    breathing: 'Exhale as you press forward',
    cues: [
      'Great low-skill option — chase a deep, controlled stretch',
      'Keep your shoulders down, not shrugged',
    ],
    mistakes: [
      'Seat too low so it becomes a shoulder press',
      'Letting the stack slam at the bottom',
    ],
    safety: null,
  ),
};
