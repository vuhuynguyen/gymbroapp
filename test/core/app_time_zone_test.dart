import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:gymbroapp/core/time/app_time_zone.dart';

void main() {
  // The IANA database is normally loaded by AppTimeZone.init() at app start; load it directly for the test.
  setUpAll(tzdata.initializeTimeZones);

  test('wallClock renders an instant in the given zone, not the device zone', () {
    // 2026-01-08 02:00 UTC → 09:00 on the 8th in Bangkok (+7), but 21:00 on the 7th in Toronto (−5).
    final instant = DateTime.utc(2026, 1, 8, 2, 0);

    final bkk = AppTimeZone.wallClock(instant, 'Asia/Bangkok');
    expect([bkk.year, bkk.month, bkk.day, bkk.hour], [2026, 1, 8, 9]);

    final tor = AppTimeZone.wallClock(instant, 'America/Toronto');
    expect([tor.year, tor.month, tor.day, tor.hour], [2026, 1, 7, 21]);
  });

  test('wallClock falls back to device-local time for an unknown zone', () {
    final instant = DateTime.utc(2026, 1, 8, 2, 0);
    expect(AppTimeZone.wallClock(instant, 'Not/AZone'), instant.toLocal());
  });
}
