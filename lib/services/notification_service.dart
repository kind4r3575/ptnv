import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/notification_rule.dart';
import '../state/pod.dart';

/// Wraps [FlutterLocalNotificationsPlugin] and turns the user's editable
/// [NotificationRule]s into real scheduled local notifications. A singleton so
/// `main` can initialize it once and `PodController` can call [sync] on change.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelReminders = 'reminders';
  static const String _channelCritical = 'critical';
  static const int _lowStockId = 900000; // fixed id so it never collides with rules

  /// Initialize the plugin, timezone database and request permissions. Safe to
  /// call once from `main`; failures are swallowed so the app still runs.
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('NotificationService: timezone init failed: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
      );
      _ready = true;
      await _requestPermissions();
    } catch (e) {
      debugPrint('NotificationService: init failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final mac =
        _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await mac?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails _details(PodController c, {required bool critical}) {
    final android = AndroidNotificationDetails(
      critical ? _channelCritical : _channelReminders,
      critical ? 'Critical alerts' : 'Pod reminders',
      channelDescription: 'Reminders for pod expiry, stock and rotation.',
      importance: critical ? Importance.max : Importance.high,
      priority: critical ? Priority.max : Priority.high,
      playSound: c.soundEnabled,
      enableVibration: c.vibrationEnabled,
    );
    final darwin = DarwinNotificationDetails(
      presentSound: c.soundEnabled,
      interruptionLevel:
          critical ? InterruptionLevel.critical : InterruptionLevel.active,
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  /// Cancel everything and re-schedule from the current rules + session. Called
  /// on boot and (debounced) whenever rules, the session or delivery settings
  /// change.
  Future<void> sync(PodController c) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!c.enableNotifications) return;

    final now = tz.TZDateTime.now(tz.local);
    var id = 0;
    for (final r in c.rules) {
      if (!r.enabled) continue;

      // siteRotation has no native "every N days" repeat (unlike dailyTime,
      // which uses DateTimeComponents.time) — pre-schedule a run of upcoming
      // occurrences instead of just the next one, so the reminder keeps
      // firing even if the app isn't reopened before the next cycle to
      // trigger another sync.
      final whens = r.trigger == NotificationTrigger.siteRotation
          ? _siteRotationOccurrences(r)
          : [_scheduleTimeFor(r, c)].whereType<DateTime>();

      final repeats = r.trigger == NotificationTrigger.dailyTime;
      for (final when in whens) {
        final tzWhen = tz.TZDateTime.from(when, tz.local);
        if (!repeats && !tzWhen.isAfter(now)) continue; // one-shot already past

        try {
          await _plugin.zonedSchedule(
            id: id++,
            title: r.displayTitle,
            body: c.hidePreviews ? 'Open Pod Tracker' : r.summary,
            scheduledDate: tzWhen,
            notificationDetails: _details(c, critical: c.criticalAlerts),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: repeats ? DateTimeComponents.time : null,
          );
        } catch (e) {
          debugPrint('NotificationService: schedule failed for ${r.id}: $e');
        }
      }
    }
  }

  /// When it fires: lifecycle rules relative to the session, dailyTime at the
  /// next time-of-day. Null = condition-based (or siteRotation, handled by
  /// [_siteRotationOccurrences] instead since it needs multiple dates).
  DateTime? _scheduleTimeFor(NotificationRule r, PodController c) {
    switch (r.trigger) {
      case NotificationTrigger.podExpiry:
      case NotificationTrigger.graceEnding:
      case NotificationTrigger.podOverdue:
      case NotificationTrigger.dailyTime:
        return c.nextFireFor(r);
      case NotificationTrigger.siteRotation:
      case NotificationTrigger.lowStock:
        return null;
    }
  }

  /// How many future occurrences of a [siteRotation] rule to pre-schedule at
  /// once, so it keeps recurring without depending on the app being reopened
  /// between cycles (see [sync]).
  static const int _siteRotationLookahead = 12;

  List<DateTime> _siteRotationOccurrences(NotificationRule r) {
    final now = DateTime.now();
    final base = DateTime(
        now.year, now.month, now.day, r.timeOfDayMinutes ~/ 60, r.timeOfDayMinutes % 60);
    final first = base.add(Duration(days: r.everyDays));
    return List.generate(
        _siteRotationLookahead, (i) => first.add(Duration(days: r.everyDays * i)));
  }

  /// Show an immediate low-stock notification (the condition-based trigger),
  /// respecting the global gates. Called by the controller when stock crosses
  /// the threshold.
  Future<void> showLowStockNow(PodController c) async {
    if (!_ready || !c.enableNotifications) return;
    try {
      await _plugin.show(
        id: _lowStockId,
        title: 'Low pod stock',
        body: c.hidePreviews
            ? 'Open Pod Tracker'
            : 'You have ${c.stock} ${c.stock == 1 ? 'pod' : 'pods'} left. Time to restock.',
        notificationDetails: _details(c, critical: c.criticalAlerts),
      );
    } catch (e) {
      debugPrint('NotificationService: low-stock show failed: $e');
    }
  }
}
