import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The "situation" a [NotificationRule] fires in.
///
/// The first three are relative to the active pod session; [lowStock] is a
/// condition (fired the moment stock drops to the threshold, not scheduled);
/// [dailyTime] and [siteRotation] are absolute time-of-day reminders.
enum NotificationTrigger {
  podExpiry, // before the rated end (uses offsetMinutes = minutes before)
  graceEnding, // before the grace window ends (offsetMinutes = minutes before)
  podOverdue, // at/after the grace end (offsetMinutes = minutes after)
  lowStock, // when stock <= Low Stock threshold (condition, not scheduled)
  siteRotation, // every N days at a time of day
  dailyTime, // every day at a time of day
}

extension NotificationTriggerX on NotificationTrigger {
  /// Short human name shown as the situation label.
  String get title => switch (this) {
        NotificationTrigger.podExpiry => 'Pod expiry',
        NotificationTrigger.graceEnding => 'Grace period ending',
        NotificationTrigger.podOverdue => 'Pod overdue',
        NotificationTrigger.lowStock => 'Low stock',
        NotificationTrigger.siteRotation => 'Site rotation',
        NotificationTrigger.dailyTime => 'Daily reminder',
      };

  IconData get icon => switch (this) {
        NotificationTrigger.podExpiry => Icons.timelapse_rounded,
        NotificationTrigger.graceEnding => Icons.hourglass_bottom_rounded,
        NotificationTrigger.podOverdue => Icons.warning_amber_rounded,
        NotificationTrigger.lowStock => Icons.inventory_2_outlined,
        NotificationTrigger.siteRotation => Icons.autorenew_rounded,
        NotificationTrigger.dailyTime => Icons.schedule_rounded,
      };

  /// Whether this trigger uses a "how long before/after" offset (vs a time of day).
  bool get usesOffset =>
      this == NotificationTrigger.podExpiry ||
      this == NotificationTrigger.graceEnding ||
      this == NotificationTrigger.podOverdue;

  /// Whether this trigger fires at a wall-clock time of day.
  bool get usesTimeOfDay =>
      this == NotificationTrigger.dailyTime || this == NotificationTrigger.siteRotation;
}

/// A single, fully-editable notification the user can add/remove. Persisted as
/// JSON in shared_preferences (see `PodController`), and translated into a real
/// scheduled local notification by `NotificationService`.
class NotificationRule {
  NotificationRule({
    required this.id,
    required this.trigger,
    this.enabled = true,
    this.offsetMinutes = 360, // 6h — a sensible lifecycle default
    this.timeOfDayMinutes = 9 * 60, // 09:00
    this.everyDays = 3,
    this.label,
  });

  final String id;
  bool enabled;
  NotificationTrigger trigger;

  /// Lifecycle triggers: minutes before the event ([podOverdue] = minutes after).
  int offsetMinutes;

  /// [dailyTime] / [siteRotation]: minutes since midnight the reminder fires at.
  int timeOfDayMinutes;

  /// [siteRotation]: rotate every N days.
  int everyDays;

  /// Optional custom title; falls back to a generated [summary] when null.
  String? label;

  NotificationRule copyWith({
    bool? enabled,
    NotificationTrigger? trigger,
    int? offsetMinutes,
    int? timeOfDayMinutes,
    int? everyDays,
    String? label,
    bool clearLabel = false,
  }) =>
      NotificationRule(
        id: id,
        enabled: enabled ?? this.enabled,
        trigger: trigger ?? this.trigger,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
        timeOfDayMinutes: timeOfDayMinutes ?? this.timeOfDayMinutes,
        everyDays: everyDays ?? this.everyDays,
        label: clearLabel ? null : (label ?? this.label),
      );

  /// A fresh rule with a unique id, defaulted for [trigger].
  factory NotificationRule.create(NotificationTrigger trigger) => NotificationRule(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        trigger: trigger,
      );

  /// Generated one-line description ("6 hours before expiry", "Daily at 09:00").
  String get summary {
    switch (trigger) {
      case NotificationTrigger.podExpiry:
        return '${fmtDuration(offsetMinutes)} before pod expires';
      case NotificationTrigger.graceEnding:
        return '${fmtDuration(offsetMinutes)} before grace ends';
      case NotificationTrigger.podOverdue:
        return offsetMinutes == 0
            ? 'When the pod becomes overdue'
            : '${fmtDuration(offsetMinutes)} after grace ends';
      case NotificationTrigger.lowStock:
        return 'When stock drops to the Low Stock threshold';
      case NotificationTrigger.siteRotation:
        return 'Every $everyDays days at ${_clockOf(timeOfDayMinutes)}';
      case NotificationTrigger.dailyTime:
        return 'Every day at ${_clockOf(timeOfDayMinutes)}';
    }
  }

  /// Title shown in the notification / list row.
  String get displayTitle => label?.trim().isNotEmpty == true ? label!.trim() : trigger.title;

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'trigger': trigger.name,
        'offsetMinutes': offsetMinutes,
        'timeOfDayMinutes': timeOfDayMinutes,
        'everyDays': everyDays,
        'label': label,
      };

  factory NotificationRule.fromJson(Map<String, dynamic> j) => NotificationRule(
        id: j['id'] as String,
        enabled: j['enabled'] as bool? ?? true,
        trigger: NotificationTrigger.values.firstWhere(
          (e) => e.name == j['trigger'],
          orElse: () => NotificationTrigger.podExpiry,
        ),
        offsetMinutes: j['offsetMinutes'] as int? ?? 360,
        timeOfDayMinutes: j['timeOfDayMinutes'] as int? ?? 9 * 60,
        everyDays: j['everyDays'] as int? ?? 3,
        label: j['label'] as String?,
      );
}

/// Formats a minutes-since-midnight value as a clock string honoring the user's
/// 12/24-hour preference (via [AppFormats]).
String _clockOf(int minutesOfDay) {
  final m = minutesOfDay % (24 * 60);
  return fmtClock(DateTime(2000, 1, 1, m ~/ 60, m % 60));
}

/// Human duration for an offset in minutes: "45 minutes", "1 hour", "6 hours",
/// "1 day", "2 days 6 hours".
String fmtDuration(int minutes) {
  if (minutes <= 0) return '0 minutes';
  final days = minutes ~/ (24 * 60);
  final hours = (minutes % (24 * 60)) ~/ 60;
  final mins = minutes % 60;
  final parts = <String>[];
  if (days > 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
  if (hours > 0) parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
  if (mins > 0) parts.add('$mins ${mins == 1 ? 'minute' : 'minutes'}');
  return parts.join(' ');
}
