// Legacy entry point — the design system moved to `lib/core/theme/`. This re-exports the new
// barrel so older imports (`import '../../app/theme.dart';`) keep resolving to the same
// `GbColors` / `AppTheme` declarations. Prefer importing `shared/widgets/widgets.dart` (which also
// re-exports the theme) or `core/theme/theme.dart` directly in new code.
export 'package:gymbroapp/core/theme/theme.dart';
