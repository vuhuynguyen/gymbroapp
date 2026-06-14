import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/nutrition_models.dart';
import '../time/app_time_zone.dart';

/// One meal reminder: a stable id, the meal label, and the absolute instant to fire (in the trainee's zone).
@immutable
class MealReminder {
  const MealReminder({required this.id, required this.mealName, required this.at});
  final int id;
  final String mealName;
  final tz.TZDateTime at;
}

/// Pure: the reminders for a day's meals — one per meal that carries a scheduled time, resolved in [zone]
/// (device zone when null). Deterministic + testable; future-filtering and the OS scheduling live in
/// [NutritionReminders]. [localDate] is "YYYY-MM-DD"; meal times are "HH:mm[:ss]".
List<MealReminder> mealReminders(
  String localDate,
  List<({String name, String? scheduledTime})> meals, {
  String? zone,
}) {
  final date = DateTime.tryParse(localDate);
  if (date == null) return const [];

  final out = <MealReminder>[];
  for (final m in meals) {
    final time = _parseTime(m.scheduledTime);
    if (time == null) continue;
    out.add(MealReminder(
      id: out.length,
      mealName: m.name,
      at: AppTimeZone.zonedAt(date.year, date.month, date.day, time.$1, time.$2, zone),
    ));
  }
  return out;
}

(int, int)? _parseTime(String? hhmmss) {
  if (hhmmss == null) return null;
  final parts = hhmmss.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return (h, m);
}

/// Schedules local OS notifications at the day's planned meal times — no server, works offline, fires even if
/// the app is closed (the design's reminders MVP). Every call is best-effort: a failure (plugin error, denied
/// permission) is swallowed so reminders can never break logging. The meal times are deterministic and known
/// on-device, so this needs no backend.
class NutritionReminders {
  NutritionReminders(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'nutrition_reminders';
  bool _ready = false;

  /// App-wide instance (the plugin is a singleton under the hood).
  static final NutritionReminders instance = NutritionReminders(FlutterLocalNotificationsPlugin());

  /// Initialize the plugin once at startup. Safe to call when notifications are unsupported (no-op on failure).
  Future<void> init() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Reschedule a day's upcoming meal reminders: cancel all, then schedule each meal whose planned time is
  /// still in the future. Best-effort and idempotent (cancel-then-set), so calling it on every Today load is fine.
  Future<void> scheduleDay(DailyNutritionLog day) async {
    if (!_ready || !day.hasPlan) return;
    try {
      if (!await _ensurePermission()) return;

      await _plugin.cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      final reminders = mealReminders(
        day.localDate,
        [for (final m in day.meals) (name: m.name, scheduledTime: m.scheduledTime)],
        zone: AppTimeZone.device,
      );

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Meal reminders',
          channelDescription: 'Reminders to log your planned meals',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      );

      for (final r in reminders) {
        if (!r.at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          r.id,
          '${r.mealName} — tap to log',
          'Mark it done in GymBro',
          r.at,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Reminders are a convenience — never let them surface an error into the logging flow.
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
      final ios =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
