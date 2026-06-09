/// Design-system barrel — import this for tokens, palette, colors, typography, and the assembled
/// theme in one line. Feature code typically imports `shared/widgets/widgets.dart`, which re-exports
/// this barrel, so a single import yields both the design tokens and the reusable widgets.
library;

export '../tokens/app_durations.dart';
export '../tokens/app_radius.dart';
export '../tokens/app_shadows.dart';
export '../tokens/app_sizes.dart';
export '../tokens/app_spacing.dart';
export 'app_colors.dart';
export 'app_palette.dart';
export 'app_theme.dart';
export 'app_typography.dart';
