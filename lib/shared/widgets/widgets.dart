/// Reusable UI kit barrel. A single import gives feature code BOTH the design tokens/theme and the
/// shared widgets:
///
/// ```dart
/// import '../../shared/widgets/widgets.dart';
/// ```
///
/// Organize new reusable widgets into the focused files below (foundation/buttons/cards/…), not as
/// one-off styling inside screens.
library;

// Design system (tokens, palette, colors, typography, theme).
export '../../core/theme/theme.dart';

// Widget kit.
export 'buttons.dart';
export 'cards.dart';
export 'chips_badges.dart';
export 'feedback.dart';
export 'foundation.dart';
export 'headers.dart';
export 'inputs.dart';
export 'session.dart';
export 'sheets.dart';
export 'stats.dart';
