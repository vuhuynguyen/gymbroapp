import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Disable Google Fonts' network fetch in tests — golden/widget tests run offline and the
/// runtime fetch throws. Fonts fall back to the bundled default, which is fine for layout checks.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
