import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/notification_rule.dart';
import '../state/pod.dart';

// ===========================================================================
// File-private constants & helpers, shared between [NotificationService] and
// [onBackgroundNotificationResponse] (a top-level function — see below for
// why it can't be an instance method).
// ===========================================================================

const String _channelReminders = 'reminders';
const String _channelCritical = 'critical';
const String _channelQuiet = 'quiet'; // Quiet Hours: same content, silent delivery
const int _lowStockId = 900000; // fixed id so it never collides with a rule's
const int _snoozeFallbackId = 900001; // used only if a tapped response has no id

const String _snoozeActionId = 'snooze';
const String _categorySnoozable = 'snoozable'; // iOS action category identifier

const List<AndroidNotificationAction> _androidActions = [
  AndroidNotificationAction(
    _snoozeActionId,
    'Snooze',
    showsUserInterface: false, // → always routes to onBackgroundNotificationResponse
    cancelNotification: true,
  ),
];

/// Registered once at init via `DarwinInitializationSettings.notificationCategories`;
/// every outgoing notification then points at it via `categoryIdentifier` so
/// its Snooze action shows up. Not `const`: [DarwinNotificationAction.plain]
/// is a factory, not a const constructor.
final DarwinNotificationCategory _snoozeCategory = DarwinNotificationCategory(
  _categorySnoozable,
  actions: [DarwinNotificationAction.plain(_snoozeActionId, 'Snooze')],
);

/// Quiet Hours window shown on the Notifications screen: 22:00–07:00 local
/// time, wrapping past midnight.
const int _quietStartMinutes = 22 * 60;
const int _quietEndMinutes = 7 * 60;

bool _isQuietHour(DateTime t) {
  final minutes = t.hour * 60 + t.minute;
  return minutes >= _quietStartMinutes || minutes < _quietEndMinutes;
}

/// Builds the platform notification details shared by every call site —
/// scheduled reminders, the immediate low-stock alert, and a rescheduled
/// snooze — so Quiet Hours muting and the Snooze action stay consistent no
/// matter which of them posted the notification. When [muted], the
/// notification is posted to a dedicated low-importance, silent channel
/// instead of just having `playSound`/`enableVibration` flipped off:
/// Android locks a channel's sound/vibration/importance in at first use, so
/// reusing the normal channel with those flags toggled per-call wouldn't
/// actually change anything after its first notification.
NotificationDetails _buildDetails({
  required bool critical,
  required bool muted,
  required bool soundEnabled,
  required bool vibrationEnabled,
}) {
  final channelId = muted ? _channelQuiet : (critical ? _channelCritical : _channelReminders);
  final channelName = muted ? 'Quiet reminders' : (critical ? 'Critical alerts' : 'Pod reminders');
  final android = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: muted
        ? 'Reminders delivered silently during Quiet Hours.'
        : 'Reminders for pod expiry, stock and rotation.',
    importance: muted ? Importance.low : (critical ? Importance.max : Importance.high),
    priority: muted ? Priority.low : (critical ? Priority.max : Priority.high),
    playSound: !muted && soundEnabled,
    enableVibration: !muted && vibrationEnabled,
    actions: _androidActions,
  );
  final darwin = DarwinNotificationDetails(
    presentSound: !muted && soundEnabled,
    interruptionLevel:
        muted ? InterruptionLevel.passive : (critical ? InterruptionLevel.critical : InterruptionLevel.active),
    categoryIdentifier: _categorySnoozable,
  );
  return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
}

/// Everything a notification's tap/snooze handling needs is baked into its
/// `payload` at schedule time, since the background isolate that handles a
/// Snooze tap (see [onBackgroundNotificationResponse]) has no access to
/// [PodController] or anything else already in memory.
String _encodePayload({
  required NotificationTrigger trigger,
  required String title,
  required String body,
  required int snoozeMinutes,
}) =>
    jsonEncode({
      'trigger': trigger.name,
      'title': title,
      'body': body,
      'snoozeMinutes': snoozeMinutes,
    });

Map<String, dynamic>? _decodePayload(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

NotificationTrigger? _triggerFromName(String? name) {
  for (final t in NotificationTrigger.values) {
    if (t.name == name) return t;
  }
  return null;
}

/// "15 min" → 15. Falls back to 15 if the label is ever in an unexpected
/// shape — a snooze should never silently do nothing.
int _snoozeMinutesFrom(String label) => int.tryParse(label.split(' ').first) ?? 15;

// ===========================================================================

/// Wraps [FlutterLocalNotificationsPlugin] and turns the user's editable
/// [NotificationRule]s into real scheduled local notifications. A singleton so
/// `main` can initialize it once and `PodController` can call [sync] on change.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;
  bool _consumedInitialTrigger = false;

  final StreamController<NotificationTrigger> _tapController =
      StreamController<NotificationTrigger>.broadcast();

  /// Emits the [NotificationTrigger] of a notification the user tapped (its
  /// body — not the Snooze action) while the app process was already alive.
  /// `main.dart` listens to this to switch to the relevant tab (see
  /// [NotificationTriggerX.targetTab]) instead of just cold-opening to
  /// whatever tab was last showing. For a tap that *launched* the app from
  /// fully closed, see [consumeInitialTrigger] instead — this stream has no
  /// listener yet at that point, so the event would otherwise be lost.
  Stream<NotificationTrigger> get onTapped => _tapController.stream;

  /// Initialize the plugin, timezone database and request permissions.
  ///
  /// Safe to call multiple times — the underlying work only ever runs once,
  /// and every call (including the fire-and-forget one from `main`) shares
  /// the same [Future], so [sync] and [showLowStockNow] can simply await
  /// this even if `main`'s call is still in flight. Failures are swallowed
  /// so the app still runs.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('NotificationService: timezone init failed: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [_snoozeCategory],
    );

    try {
      await _plugin.initialize(
        settings: InitializationSettings(android: android, iOS: darwin, macOS: darwin),
        onDidReceiveNotificationResponse: _onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
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

  /// A plain tap (the notification body, `showsUserInterface: true` by
  /// default) always brings the app to the foreground and runs on the main
  /// isolate, so this can safely push onto [_tapController].
  void _onForegroundResponse(NotificationResponse response) {
    final trigger = _triggerFromName(_decodePayload(response.payload)?['trigger'] as String?);
    if (trigger != null) _tapController.add(trigger);
  }

  /// The [NotificationTrigger] that cold-launched the app by tapping a
  /// notification, or `null` on a normal launch (or if this has already
  /// been consumed once — each cold launch is only ever reported once).
  /// Call this at startup; it awaits [init] itself so callers don't need to
  /// sequence around it.
  Future<NotificationTrigger?> consumeInitialTrigger() async {
    if (_consumedInitialTrigger) return null;
    _consumedInitialTrigger = true;
    await init();
    if (!_ready) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return _triggerFromName(
        _decodePayload(details!.notificationResponse?.payload)?['trigger'] as String?);
  }

  /// Cancel everything and re-schedule from the current rules + session. Called
  /// on boot and (debounced) whenever rules, the session or delivery settings
  /// change.
  ///
  /// Awaits [init] first so a `sync` that lands before `main`'s fire-and-forget
  /// `init()` call has finished still schedules correctly instead of silently
  /// no-op'ing. The actual `zonedSchedule` calls are fired concurrently
  /// (rather than one `await` at a time) since a rule set with several
  /// site-rotation rules can mean a dozen-plus scheduling calls per sync.
  Future<void> sync(PodController c) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!c.enableNotifications) return;

    final now = tz.TZDateTime.now(tz.local);
    final tasks = <Future<void>>[];
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

        tasks.add(_scheduleOne(
          id: id++,
          rule: r,
          c: c,
          tzWhen: tzWhen,
          repeats: repeats,
        ));
      }
    }
    await Future.wait(tasks);
  }

  /// Schedules one occurrence. Failures are caught (and logged) per-call, not
  /// left to propagate, so [sync] can run every occurrence concurrently via
  /// [Future.wait] without one bad schedule call taking the rest down with it.
  Future<void> _scheduleOne({
    required int id,
    required NotificationRule rule,
    required PodController c,
    required tz.TZDateTime tzWhen,
    required bool repeats,
  }) async {
    final title = rule.displayTitle;
    final body = c.hidePreviews ? 'Open Pod Tracker' : rule.summary;
    final muted = c.quietHours && _isQuietHour(tzWhen);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: _buildDetails(
          critical: c.criticalAlerts,
          muted: muted,
          soundEnabled: c.soundEnabled,
          vibrationEnabled: c.vibrationEnabled,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeats ? DateTimeComponents.time : null,
        payload: _encodePayload(
          trigger: rule.trigger,
          title: title,
          body: body,
          snoozeMinutes: _snoozeMinutesFrom(c.snoozeDuration),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: schedule failed for ${rule.id}: $e');
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
    await init();
    if (!_ready || !c.enableNotifications) return;
    final title = 'Low pod stock';
    final body = c.hidePreviews
        ? 'Open Pod Tracker'
        : 'You have ${c.stock} ${c.stock == 1 ? 'pod' : 'pods'} left. Time to restock.';
    final muted = c.quietHours && _isQuietHour(DateTime.now());
    try {
      await _plugin.show(
        id: _lowStockId,
        title: title,
        body: body,
        notificationDetails: _buildDetails(
          critical: c.criticalAlerts,
          muted: muted,
          soundEnabled: c.soundEnabled,
          vibrationEnabled: c.vibrationEnabled,
        ),
        payload: _encodePayload(
          trigger: NotificationTrigger.lowStock,
          title: title,
          body: body,
          snoozeMinutes: _snoozeMinutesFrom(c.snoozeDuration),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: low-stock show failed: $e');
    }
  }
}

/// Handles a tap on a notification action that doesn't show the app's UI —
/// today, only "Snooze" (`showsUserInterface: false` in [_androidActions]).
/// Per the plugin's contract, such actions are *always* delivered here, on a
/// fresh background isolate, rather than to
/// [NotificationService._onForegroundResponse] — regardless of whether the
/// app happened to be open at the time. That isolate shares no memory with
/// the running app, so this can't reach [NotificationService.instance],
/// [PodController], or anything else already in memory: it rebuilds just
/// enough (its own plugin instance, the timezone database, and the handful
/// of delivery settings it needs, read directly from `shared_preferences`)
/// to reschedule the same reminder for `snoozeMinutes` from now, then gets
/// out of the way without ever bringing the app forward.
///
/// Must stay a top-level function annotated `@pragma('vm:entry-point')` so
/// the Dart compiler doesn't tree-shake it out of release builds.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(NotificationResponse response) async {
  if (response.actionId != _snoozeActionId) return;
  final data = _decodePayload(response.payload);
  if (data == null) return;

  final title = data['title'] as String? ?? 'Pod Tracker';
  final body = data['body'] as String? ?? '';
  final minutes = data['snoozeMinutes'] as int? ?? 15;
  final when = DateTime.now().add(Duration(minutes: minutes));

  try {
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    debugPrint('NotificationService: background timezone init failed: $e');
  }

  // Keys must stay in sync with PodController's `_k*` persistence constants
  // — there's no PodController here to read them from.
  final prefs = await SharedPreferences.getInstance();
  final soundEnabled = prefs.getBool('soundEnabled') ?? true;
  final vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
  final criticalAlerts = prefs.getBool('criticalAlerts') ?? true;
  final quietHours = prefs.getBool('quietHours') ?? true;
  final muted = quietHours && _isQuietHour(when);

  final plugin = FlutterLocalNotificationsPlugin();
  try {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.zonedSchedule(
      id: response.id ?? _snoozeFallbackId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _buildDetails(
        critical: criticalAlerts,
        muted: muted,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: response.payload, // snoozing again re-snoozes from the same info
    );
  } catch (e) {
    debugPrint('NotificationService: snooze reschedule failed: $e');
  }
}
