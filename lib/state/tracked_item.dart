/// Generic pieces shared by anything Pod Tracker could track over time: a
/// session with a start time, a rated duration, and a grace window after it
/// expires, plus a delta-based stock/activity log. Used today only by pods
/// (see [PodSession] and the `TrackedItemActivity` list in `pod.dart`'s
/// `PodController`), but nothing about either shape is pod-specific — pulled
/// out on their own so a future device type (a CGM sensor, an infusion set,
/// a reservoir, ...) can reuse the exact same wear-tracking state machine and
/// stock log instead of duplicating them, per the app's roadmap of
/// generalizing beyond pods.
///
/// This file is a pure extraction, not a new feature: nothing about how the
/// app behaves changes. Pod Tracker still only ever tracks pods —
/// [PodSession] is still the one concrete session type in use, now built on
/// top of [TrackedItemSession] instead of duplicating its math.
library;

import 'package:flutter/foundation.dart';

/// Lifecycle of a tracked item relative to its wear/expiry time: on track
/// while within its rated duration, in its grace window after that, then
/// late once the grace window elapses too.
enum TrackedItemStatus { onTrack, grace, late }

/// A wear-tracked item's timeline: started at a point in time, rated for
/// [durationHours], with a [graceHours] window after that during which it's
/// still considered usable.
@immutable
abstract class TrackedItemSession {
  const TrackedItemSession({
    required this.startedAt,
    required this.durationHours,
    required this.graceHours,
  });

  final DateTime startedAt;

  /// How many hours this item is rated for before [statusAt] moves past
  /// [TrackedItemStatus.onTrack].
  final int durationHours;

  /// Grace window (hours) after the rated end, during which the item is
  /// still considered usable.
  final int graceHours;

  Duration get totalDuration => Duration(hours: durationHours);

  /// When the item reaches its rated duration.
  DateTime get endAt => startedAt.add(totalDuration);

  /// When the grace window ends.
  DateTime get graceEndAt => endAt.add(Duration(hours: graceHours));

  Duration elapsed(DateTime now) => now.difference(startedAt);

  TrackedItemStatus statusAt(DateTime now) {
    if (elapsed(now) < totalDuration) return TrackedItemStatus.onTrack;
    if (now.isBefore(graceEndAt)) return TrackedItemStatus.grace;
    return TrackedItemStatus.late;
  }

  /// Total time the item has been in use.
  Duration worn(DateTime now) => _clamp(elapsed(now));

  /// Time left until the rated end (0 once expired).
  Duration remaining(DateTime now) => _clamp(endAt.difference(now));

  /// Time left in the grace window (0 outside it).
  Duration graceLeft(DateTime now) => _clamp(graceEndAt.difference(now));

  /// How long past the grace end the item has gone unchanged.
  Duration overdue(DateTime now) => _clamp(now.difference(graceEndAt));

  /// Fraction of the rated duration elapsed, clamped to 0..1.
  double progress(DateTime now) =>
      (elapsed(now).inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);

  static Duration _clamp(Duration d) => d.isNegative ? Duration.zero : d;
}

/// One entry in a tracked item's stock/activity log. A positive [delta]
/// added to stock (a restock), a negative one removed from it (e.g. one
/// consumed by starting a new session). Used today only for pod stock (see
/// `PodController.activity` in `pod.dart`), but nothing about its shape —
/// a signed count, a label, a timestamp, an optional note — is pod-specific.
@immutable
class TrackedItemActivity {
  const TrackedItemActivity({
    required this.delta,
    required this.label,
    required this.at,
    this.note = '',
  });

  final int delta;
  final String label;
  final DateTime at;

  /// Optional second-line detail (e.g. the insertion site for a pod
  /// session, or a restock note).
  final String note;

  Map<String, dynamic> toJson() => {
        'delta': delta,
        'label': label,
        'note': note,
        'at': at.toIso8601String(),
      };

  factory TrackedItemActivity.fromJson(Map<String, dynamic> j) => TrackedItemActivity(
        delta: j['delta'] as int,
        label: j['label'] as String,
        note: j['note'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
      );
}
