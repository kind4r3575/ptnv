import 'dart:async';

import 'package:flutter/foundation.dart';

/// Lifecycle of a pod relative to its wear time.
///
/// A pod is rated for [PodSession.durationHours] (72h). After that it enters an
/// [PodSession.graceHours] (8h) grace window where it is still delivering but
/// should be changed, and once that elapses it has stopped delivering (late).
enum PodStatus { onTrack, grace, late }

@immutable
class PodSession {
  const PodSession({required this.startedAt, this.site = 'Not set'});

  final DateTime startedAt;

  /// Insertion site chosen on the Add Pod sheet, carried into Session History.
  final String site;

  static const int durationHours = 72;
  static const int graceHours = 8;

  Duration get totalDuration => const Duration(hours: durationHours);

  /// When the pod reaches its rated 72h.
  DateTime get endAt => startedAt.add(totalDuration);

  /// When the grace window ends and the pod stops delivering (80h).
  DateTime get graceEndAt => endAt.add(const Duration(hours: graceHours));

  Duration elapsed(DateTime now) => now.difference(startedAt);

  PodStatus statusAt(DateTime now) {
    if (elapsed(now) < totalDuration) return PodStatus.onTrack;
    if (now.isBefore(graceEndAt)) return PodStatus.grace;
    return PodStatus.late;
  }

  /// Total time the pod has been worn.
  Duration worn(DateTime now) => _clamp(elapsed(now));

  /// Time left until the rated 72h end (0 once expired).
  Duration remaining(DateTime now) => _clamp(endAt.difference(now));

  /// Time left in the grace window (0 outside it).
  Duration graceLeft(DateTime now) => _clamp(graceEndAt.difference(now));

  /// How long past the grace end the pod has been delivering nothing.
  Duration overdue(DateTime now) => _clamp(now.difference(graceEndAt));

  /// Fraction of the 72h window elapsed, clamped to 0..1.
  double progress(DateTime now) =>
      (elapsed(now).inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);

  static Duration _clamp(Duration d) => d.isNegative ? Duration.zero : d;
}

/// One entry in the Pod Stock "Recent activity" / history log. A positive
/// [delta] added pods (restock), a negative one removed them (e.g. a session).
@immutable
class StockActivity {
  const StockActivity({
    required this.delta,
    required this.label,
    required this.at,
    this.note = '',
  });

  final int delta;
  final String label;
  final DateTime at;

  /// Optional second-line detail shown in the Stock History log
  /// (e.g. the insertion site for a session, or a restock note).
  final String note;
}

/// How a past pod session ended — drives the Session History badge/note colours.
enum HistoryOutcome { completed, endedEarly, wornTooLong }

/// One past pod session shown on the Session History screen.
@immutable
class SessionRecord {
  const SessionRecord({
    required this.date,
    required this.outcome,
    required this.started,
    required this.ended,
    required this.worn,
    required this.placedOn,
    required this.whyChanged,
    required this.remindersSent,
    required this.changes,
  });

  final DateTime date; // card title (the day it ended)
  final HistoryOutcome outcome;
  final DateTime started;
  final DateTime ended;
  final Duration worn;
  final String placedOn;
  final String whyChanged;
  final int remindersSent;
  final String changes; // "None" or e.g. "+3h 30m"

  Duration get planned => const Duration(hours: PodSession.durationHours);
}

/// Holds the Home page state and drives the per-second countdown.
///
/// Uses [ChangeNotifier] so the UI can rebuild via the built-in
/// `ListenableBuilder` — no external state-management package required.
class PodController extends ChangeNotifier {
  PodController() {
    _boot();
  }

  PodSession? _session;
  int _stock = 6;
  String? _reminder; // null => "None scheduled"
  bool _loading = true;
  Timer? _ticker;

  /// Rapid −/+ taps are coalesced into a single log entry, written this long
  /// after the last tap so Stock History doesn't fill with ±1 rows.
  static const Duration stockLogDelay = Duration(seconds: 3);
  Timer? _stockDebounce;
  int _pendingStockDelta = 0;

  /// Pods used up per day of supply estimate — "≈ stock × 3 days".
  static const int daysPerPod = 3;

  /// Stock level at which the user is warned / reminded to reorder.
  static const int reorderThreshold = 3;

  bool _reorderReminder = true;

  // Newest-first activity log, seeded with the two design sample rows.
  final List<StockActivity> _activity = [
    StockActivity(
      delta: -1,
      label: 'Session started',
      note: 'Left abdomen',
      at: DateTime.now().copyWith(hour: 14, minute: 30, second: 0, millisecond: 0, microsecond: 0),
    ),
    StockActivity(
      delta: 5,
      label: 'Restocked',
      note: 'Pharmacy refill',
      at: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // Newest-first session history, seeded with the three design sample sessions.
  final List<SessionRecord> _history = [
    SessionRecord(
      date: DateTime(2026, 6, 5),
      outcome: HistoryOutcome.endedEarly,
      started: DateTime(2026, 6, 4, 14, 30),
      ended: DateTime(2026, 6, 5, 3, 0),
      worn: const Duration(hours: 12, minutes: 30),
      placedOn: 'Left abdomen',
      whyChanged: 'Blockage alert',
      remindersSent: 2,
      changes: 'None',
    ),
    SessionRecord(
      date: DateTime(2026, 6, 1),
      outcome: HistoryOutcome.wornTooLong,
      started: DateTime(2026, 5, 29, 9, 0),
      ended: DateTime(2026, 6, 1, 12, 30),
      worn: const Duration(hours: 75, minutes: 30),
      placedOn: 'Right thigh',
      whyChanged: 'Changed by hand',
      remindersSent: 4,
      changes: '+3h 30m',
    ),
    SessionRecord(
      date: DateTime(2026, 5, 28),
      outcome: HistoryOutcome.completed,
      started: DateTime(2026, 5, 25, 20, 15),
      ended: DateTime(2026, 5, 28, 20, 45),
      worn: const Duration(hours: 72),
      placedOn: 'Left arm',
      whyChanged: 'Planned change',
      remindersSent: 3,
      changes: 'None',
    ),
  ];

  PodSession? get session => _session;
  int get stock => _stock;
  bool get isLoading => _loading;
  String get reminderText => _reminder ?? 'None scheduled';
  bool get reorderReminder => _reorderReminder;
  List<StockActivity> get activity => List.unmodifiable(_activity);
  List<SessionRecord> get history => List.unmodifiable(_history);

  /// Estimated days of supply remaining: stock × [daysPerPod].
  int get daysOfSupply => _stock * daysPerPod;

  /// Approximate date the stock runs out, from today.
  DateTime get runsOutDate => DateTime.now().add(Duration(days: daysOfSupply));

  /// Kept for the Home info row; mirrors [runsOutDate].
  DateTime get predictedRunOut => runsOutDate;

  /// Adjust stock by [delta] (the −/+ steppers use ±1), clamped at 0, and log it.
  void adjustStock(int delta) {
    final next = (_stock + delta).clamp(0, 9999);
    if (next == _stock) return;
    _pendingStockDelta += next - _stock;
    _stock = next;
    _stockDebounce?.cancel();
    _stockDebounce = Timer(stockLogDelay, _commitPendingStock);
    notifyListeners(); // stock number updates immediately; the log entry waits
  }

  /// Flush the accumulated −/+ taps into a single log entry. Called when the
  /// debounce timer fires, and eagerly before any other activity is logged.
  void _commitPendingStock() {
    _stockDebounce?.cancel();
    _stockDebounce = null;
    final delta = _pendingStockDelta;
    _pendingStockDelta = 0;
    if (delta == 0) return; // e.g. +1 then −1 cancelled out — nothing to log
    _activity.insert(
      0,
      StockActivity(
        delta: delta,
        label: delta > 0 ? 'Added' : 'Removed',
        at: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Set stock to an exact [value] (from the "Set exact amount" field) and log it.
  void setStock(int value) {
    _commitPendingStock(); // log any pending taps first, in chronological order
    final next = value.clamp(0, 9999);
    if (next == _stock) return;
    final applied = next - _stock;
    _stock = next;
    _activity.insert(
      0,
      StockActivity(delta: applied, label: 'Set exact amount', at: DateTime.now()),
    );
    notifyListeners();
  }

  /// Undo the most recent activity entry, reverting its stock change.
  void undoLastActivity() {
    _commitPendingStock(); // fold pending taps into the log before undoing
    if (_activity.isEmpty) return;
    final last = _activity.removeAt(0);
    _stock = (_stock - last.delta).clamp(0, 9999);
    notifyListeners();
  }

  void setReorderReminder(bool value) {
    if (_reorderReminder == value) return;
    _reorderReminder = value;
    notifyListeners();
  }

  // --- Settings --------------------------------------------------------------
  // All in-memory; the Settings screen edits these and they persist for the
  // app session. (Data & Backup / About rows are non-functional for now.)
  int _defaultPodDurationHours = 72;
  int _lowStockThreshold = 3;
  String _podType = 'Omnipod · 72h';
  int _gracePeriodHours = 2;
  bool _siteRotationReminder = true;

  bool _enableNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _criticalAlerts = true;
  bool _lowStockAlert = true;
  bool _hidePreviews = false;

  bool _quietHours = true;
  String _snoozeDuration = '15 min';

  final List<int> _reminderHours = [24, 6, 1];

  String _language = 'English';
  String _timeFormat = '24-hour';
  String _dateFormat = 'DD/MM/YYYY';

  int get defaultPodDurationHours => _defaultPodDurationHours;
  int get lowStockThreshold => _lowStockThreshold;
  String get podType => _podType;
  int get gracePeriodHours => _gracePeriodHours;
  bool get siteRotationReminder => _siteRotationReminder;
  bool get enableNotifications => _enableNotifications;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get criticalAlerts => _criticalAlerts;
  bool get lowStockAlert => _lowStockAlert;
  bool get hidePreviews => _hidePreviews;
  bool get quietHours => _quietHours;
  String get snoozeDuration => _snoozeDuration;
  List<int> get reminderHours => List.unmodifiable(_reminderHours);
  String get language => _language;
  String get timeFormat => _timeFormat;
  String get dateFormat => _dateFormat;

  void setDefaultPodDuration(int hours) {
    final v = hours.clamp(1, 240);
    if (v == _defaultPodDurationHours) return;
    _defaultPodDurationHours = v;
    notifyListeners();
  }

  void setLowStockThreshold(int pods) {
    final v = pods.clamp(0, 999);
    if (v == _lowStockThreshold) return;
    _lowStockThreshold = v;
    notifyListeners();
  }

  void setPodType(String value) => _set(() => _podType = value, _podType != value);
  void setGracePeriodHours(int value) =>
      _set(() => _gracePeriodHours = value, _gracePeriodHours != value);
  void setSiteRotationReminder(bool value) =>
      _set(() => _siteRotationReminder = value, _siteRotationReminder != value);
  void setEnableNotifications(bool value) =>
      _set(() => _enableNotifications = value, _enableNotifications != value);
  void setSoundEnabled(bool value) =>
      _set(() => _soundEnabled = value, _soundEnabled != value);
  void setVibrationEnabled(bool value) =>
      _set(() => _vibrationEnabled = value, _vibrationEnabled != value);
  void setCriticalAlerts(bool value) =>
      _set(() => _criticalAlerts = value, _criticalAlerts != value);
  void setLowStockAlert(bool value) =>
      _set(() => _lowStockAlert = value, _lowStockAlert != value);
  void setHidePreviews(bool value) =>
      _set(() => _hidePreviews = value, _hidePreviews != value);
  void setQuietHours(bool value) => _set(() => _quietHours = value, _quietHours != value);
  void setSnoozeDuration(String value) =>
      _set(() => _snoozeDuration = value, _snoozeDuration != value);
  void setLanguage(String value) => _set(() => _language = value, _language != value);
  void setTimeFormat(String value) => _set(() => _timeFormat = value, _timeFormat != value);
  void setDateFormat(String value) => _set(() => _dateFormat = value, _dateFormat != value);

  /// Add a new "reminder before expiry" (hours before the 72h end).
  void addReminder(int hours) {
    _reminderHours.add(hours.clamp(0, 240));
    notifyListeners();
  }

  void updateReminder(int index, int hours) {
    if (index < 0 || index >= _reminderHours.length) return;
    final v = hours.clamp(0, 240);
    if (_reminderHours[index] == v) return;
    _reminderHours[index] = v;
    notifyListeners();
  }

  void removeReminder(int index) {
    if (index < 0 || index >= _reminderHours.length) return;
    _reminderHours.removeAt(index);
    notifyListeners();
  }

  void _set(VoidCallback apply, bool changed) {
    if (!changed) return;
    apply();
    notifyListeners();
  }

  Future<void> _boot() async {
    // Brief initial load so the skeleton state is visible on launch.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _loading = false;
    _session = PodSession(
      startedAt: DateTime.now().subtract(const Duration(minutes: 1, seconds: 43)),
    );
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session != null) notifyListeners();
    });
  }

  /// End the current pod → Home shows the "No Active Pod" state.
  ///
  /// Records the finished session at the top of [history]. [endedAt] defaults to
  /// now (the "Now" option); [reason] is the End Pod sheet's chosen reason. The
  /// outcome badge is derived from how long the pod was worn, reusing
  /// [PodSession.statusAt]: worn < 72h → ended early, within the grace window →
  /// completed, past it → worn too long.
  void endPod({DateTime? endedAt, String reason = 'Planned'}) {
    final session = _session;
    if (session == null) return;
    final end = endedAt ?? DateTime.now();
    final worn = end.difference(session.startedAt);
    final outcome = switch (session.statusAt(end)) {
      PodStatus.onTrack => HistoryOutcome.endedEarly,
      PodStatus.grace => HistoryOutcome.completed,
      PodStatus.late => HistoryOutcome.wornTooLong,
    };
    _history.insert(
      0,
      SessionRecord(
        date: end,
        outcome: outcome,
        started: session.startedAt,
        ended: end,
        worn: worn.isNegative ? Duration.zero : worn,
        placedOn: session.site,
        whyChanged: reason,
        remindersSent: 0, // reminder tracking not implemented yet
        changes: 'None', // duration adjustments not implemented yet
      ),
    );
    _session = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  /// Begin a fresh pod. Defaults to starting now; pass [startedAt] to record a
  /// custom application time (e.g. from the "Custom" start-time picker).
  ///
  /// Consumes one pod from stock (clamped at 0) and logs a "Session started"
  /// activity entry, matching the "1 will be used" note on the Add Pod sheet.
  void startPod({DateTime? startedAt, String site = 'Not set'}) {
    _commitPendingStock(); // log any pending taps before the session entry
    _session = PodSession(startedAt: startedAt ?? DateTime.now(), site: site);
    _loading = false;
    if (_stock > 0) {
      _stock -= 1;
      _activity.insert(
        0,
        StockActivity(delta: -1, label: 'Session started', note: site, at: DateTime.now()),
      );
    }
    _startTicker();
    notifyListeners();
  }

  // --- Temporary demo helper -------------------------------------------------
  // Long-press the "Pod Tracker" title to cycle through every Home state so all
  // five can be verified live before the other screens exist. Remove once real
  // navigation drives the state.
  int _demoIndex = 0;
  void cycleDemoState() {
    _demoIndex = (_demoIndex + 1) % 5;
    _loading = false;
    final now = DateTime.now();
    switch (_demoIndex) {
      case 0: // On track
        _session = PodSession(startedAt: now.subtract(const Duration(minutes: 1, seconds: 43)));
        _startTicker();
      case 1: // Grace
        _session = PodSession(startedAt: now.subtract(const Duration(hours: 74, minutes: 18)));
        _startTicker();
      case 2: // Late / stopped
        _session = PodSession(startedAt: now.subtract(const Duration(hours: 83, minutes: 43)));
        _startTicker();
      case 3: // No active pod
        _session = null;
        _ticker?.cancel();
        _ticker = null;
      case 4: // Loading
        _session = null;
        _ticker?.cancel();
        _ticker = null;
        _loading = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stockDebounce?.cancel();
    super.dispose();
  }
}
