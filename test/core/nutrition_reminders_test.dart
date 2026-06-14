import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:gymbroapp/core/notifications/nutrition_reminders.dart';

void main() {
  // AppTimeZone.init() loads the IANA db at app start; load it directly for the test.
  setUpAll(tzdata.initializeTimeZones);

  test('schedules one reminder per timed meal at the right local wall-clock', () {
    final reminders = mealReminders(
      '2026-03-15',
      [
        (name: 'Breakfast', scheduledTime: '08:00:00'),
        (name: 'Lunch', scheduledTime: '12:30:00'),
        (name: 'Off-plan', scheduledTime: null), // unscheduled bucket → no reminder
      ],
      zone: 'America/Toronto',
    );

    expect(reminders.length, 2);
    expect(reminders[0].mealName, 'Breakfast');
    expect([reminders[0].at.year, reminders[0].at.month, reminders[0].at.day], [2026, 3, 15]);
    expect([reminders[0].at.hour, reminders[0].at.minute], [8, 0]);
    expect(reminders[0].at.location.name, 'America/Toronto');
    expect(reminders[1].mealName, 'Lunch');
    expect([reminders[1].at.hour, reminders[1].at.minute], [12, 30]);
  });

  test('is empty for a bad date or meals with no scheduled time', () {
    expect(mealReminders('not-a-date', [(name: 'X', scheduledTime: '08:00:00')]), isEmpty);
    expect(mealReminders('2026-03-15', [(name: 'X', scheduledTime: null)]), isEmpty);
  });
}
