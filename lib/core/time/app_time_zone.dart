import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Timezone support for the client.
///
/// The user's authoritative zone lives server-side (`User.TimeZoneId`, minted into the JWT `tz` claim so the
/// API resolves day boundaries without a per-request parameter). The client's only jobs are to (1) report its
/// current device zone so that anchor stays in step, and (2) render ANOTHER trainee's data in the trainee's
/// captured zone (coach views). A trainee's own data renders in the device zone (pass a null/empty zone).
class AppTimeZone {
  AppTimeZone._();

  static String _device = 'UTC';

  /// The device's IANA zone (e.g. "America/Toronto"); 'UTC' until [init] completes.
  static String get device => _device;

  /// Load the IANA database and detect the device zone. Call once at startup, before any formatting.
  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (info.identifier.isNotEmpty) _device = info.identifier;
    } catch (_) {
      _device = 'UTC';
    }
  }

  /// The wall-clock [DateTime] of [instant] as seen in [ianaZone] (the device zone when null/empty/unknown).
  /// Returned as a "naive" local DateTime so existing formatters can read its y/m/d/h/m fields directly.
  static DateTime wallClock(DateTime instant, [String? ianaZone]) {
    final zone = (ianaZone == null || ianaZone.isEmpty) ? _device : ianaZone;
    try {
      final z = tz.TZDateTime.from(instant, tz.getLocation(zone));
      return DateTime(z.year, z.month, z.day, z.hour, z.minute, z.second);
    } catch (_) {
      return instant.toLocal();
    }
  }
}
