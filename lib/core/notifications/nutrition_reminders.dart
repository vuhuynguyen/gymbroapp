import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/nutrition_models.dart';
import '../../domain/enums.dart';
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
  static const _workoutChannelId = 'workout_alerts';
  // Meal reminders use ids 0..(_mealIdMax-1); the rest-timer alert uses a fixed high id so the two never
  // collide (scheduleDay only clears the meal range, never the rest alert).
  static const _mealIdMax = 50;
  static const _restDoneId = 9001;
  bool _ready = false;

  /// App-wide instance (the plugin is a singleton under the hood).
  static final NutritionReminders instance = NutritionReminders(FlutterLocalNotificationsPlugin());

  /// Invoked when the user taps a notification while the app is running (or resumes from background).
  /// Wired by `main()` to the app router so a meal reminder opens the Log tab and a rest alert reopens
  /// the live session. Null until [init]. Cold-start taps are handled via [launchPayload] instead.
  void Function(String? payload)? _onTap;

  /// Initialize the plugin once at startup. Safe to call when notifications are unsupported (no-op on
  /// failure). [onTap] receives a tapped notification's payload (e.g. `'log'`, `'session:<id>'`).
  Future<void> init({void Function(String? payload)? onTap}) async {
    _onTap = onTap;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (resp) => _onTap?.call(resp.payload),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// The payload of the notification that cold-launched the app (app was terminated), or null. `main()`
  /// routes on it after the first frame so navigation lands once the router is mounted.
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details!.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  /// Reschedule a day's upcoming meal reminders: cancel all, then schedule each meal whose planned time is
  /// still in the future. Best-effort and idempotent (cancel-then-set), so calling it on every Today load is fine.
  Future<void> scheduleDay(DailyNutritionLog day) async {
    if (!_ready || !day.hasPlan) return;
    try {
      if (!await _ensurePermission()) return;

      // Clear only the meal-reminder id range (never the rest-timer alert) before rescheduling.
      for (var id = 0; id < _mealIdMax; id++) {
        await _plugin.cancel(id);
      }

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
        if (r.id >= _mealIdMax || !r.at.isAfter(now)) continue;
        // Precise, friendly copy: how many items are still to log, calling out supplements.
        final meal = day.meals.firstWhere(
          (m) => m.name == r.mealName,
          orElse: () => NutritionMeal(name: r.mealName),
        );
        await _plugin.zonedSchedule(
          r.id,
          'Time for ${r.mealName} 🍴',
          _mealBody(meal),
          r.at,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Tapping a meal reminder opens the Log tab (today's checklist).
          payload: 'log',
        );
      }
    } catch (_) {
      // Reminders are a convenience — never let them surface an error into the logging flow.
    }
  }

  /// Precise, friendly body for a meal reminder: a clear tap cue + how many items, with a supplement
  /// call-out. Leads with "Tap to log" so the action is obvious from the lock screen.
  static String _mealBody(NutritionMeal meal) {
    final planned = meal.plannedItems;
    final n = planned.length;
    if (n == 0) return 'Tap to open today’s plan';
    final supps = planned.where((i) => i.kind == FoodKind.supplement).length;
    final base = 'Tap to log your $n item${n == 1 ? '' : 's'}';
    return supps > 0
        ? '$base · incl. $supps supplement${supps == 1 ? '' : 's'}'
        : base;
  }

  /// Schedule a "rest's over" alert [seconds] from now (fires even if the app is backgrounded/screen off).
  /// Replaces any pending rest alert. Cancel it when the set is logged early or the rest is skipped.
  /// [sessionId] makes a tap reopen that live session; without it the tap falls back to the Log tab.
  Future<void> scheduleRestDone(int seconds, {String? sessionId}) async {
    if (!_ready || seconds <= 0) return;
    try {
      if (!await _ensurePermission()) return;
      final at = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
      await _plugin.zonedSchedule(
        _restDoneId,
        "Rest's over 💪",
        'Tap to log your next set',
        at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _workoutChannelId,
            'Workout alerts',
            channelDescription: 'Rest-timer and workout alerts',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: sessionId != null ? 'session:$sessionId' : 'log',
      );
    } catch (_) {
      // Best-effort: a denied permission or exact-alarm restriction must never break the workout.
    }
  }

  /// Cancel a pending "rest's over" alert (the set was logged early, the rest was skipped, or the in-app
  /// countdown already finished while foregrounded).
  Future<void> cancelRestDone() async {
    try {
      await _plugin.cancel(_restDoneId);
    } catch (_) {}
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
