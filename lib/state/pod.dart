import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../theme/tokens.dart' show AppFormats, fmtClock, fmtHm, fmtWeekdayDate;
import 'notification_rule.dart';
import 'tracked_item.dart';

export 'tracked_item.dart' show TrackedItemActivity, TrackedItemStatus;

/// One pod session — everything [TrackedItemSession] tracks (start time,
/// rated duration, grace window), plus the insertion [site] this device type
/// needs and nothing else does.
///
/// A pod is rated for [durationHours] (72h). After that it enters a
/// [graceHours] (8h) grace window where it is still delivering but should be
/// changed, and once that elapses it has stopped delivering (late).
@immutable
class PodSession extends TrackedItemSession {
  const PodSession({
    required super.startedAt,
    this.site = 'Not set',
    super.durationHours = defaultDurationHours,
    super.graceHours = defaultGraceHours,
  });

  /// Insertion site chosen on the Add Pod sheet, carried into Session History.
  final String site;

  static const int defaultDurationHours = 72;
  static const int defaultGraceHours = 8;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'site': site,
        'durationHours': durationHours,
        'graceHours': graceHours,
      };

  factory PodSession.fromJson(Map<String, dynamic> j) => PodSession(
        startedAt: DateTime.parse(j['startedAt'] as String),
        site: j['site'] as String? ?? 'Not set',
        durationHours: j['durationHours'] as int? ?? defaultDurationHours,
        graceHours: j['graceHours'] as int? ?? defaultGraceHours,
      );
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
    this.plannedHours = PodSession.defaultDurationHours,
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

  /// Planned wear time for this session (the pod's rated hours at start).
  final int plannedHours;

  Duration get planned => Duration(hours: plannedHours);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'outcome': outcome.name,
        'started': started.toIso8601String(),
        'ended': ended.toIso8601String(),
        'wornSeconds': worn.inSeconds,
        'placedOn': placedOn,
        'whyChanged': whyChanged,
        'remindersSent': remindersSent,
        'changes': changes,
        'plannedHours': plannedHours,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        date: DateTime.parse(j['date'] as String),
        outcome: HistoryOutcome.values.firstWhere(
          (e) => e.name == j['outcome'],
          orElse: () => HistoryOutcome.completed,
        ),
        started: DateTime.parse(j['started'] as String),
        ended: DateTime.parse(j['ended'] as String),
        worn: Duration(seconds: j['wornSeconds'] as int),
        placedOn: j['placedOn'] as String,
        whyChanged: j['whyChanged'] as String,
        remindersSent: j['remindersSent'] as int,
        changes: j['changes'] as String,
        plannedHours: j['plannedHours'] as int? ?? PodSession.defaultDurationHours,
      );
}

/// A pod/pump model — its display label and the default wear/grace hours
/// picking it applies to [PodController.defaultPodDurationHours] /
/// [PodController.gracePeriodHours]. The three bundled presets are
/// illustrative starting points, not clinical guidance (see the Terms of
/// Service medical disclaimer) — a user can add their own via
/// [PodController.addCustomPodType], letting Pod Type actually mean
/// something instead of just relabeling a fixed 72h/8h pair.
@immutable
class PodTypePreset {
  const PodTypePreset({
    required this.name,
    required this.durationHours,
    required this.graceHours,
  });

  final String name;
  final int durationHours;
  final int graceHours;

  /// e.g. "Omnipod · 72h" — what's shown in the picker and stored as
  /// [PodController.podType] once applied.
  String get label => '$name · ${durationHours}h';

  static const List<PodTypePreset> builtIn = [
    PodTypePreset(name: 'Omnipod', durationHours: 72, graceHours: 8),
    PodTypePreset(name: 'Omnipod 5', durationHours: 72, graceHours: 8),
    PodTypePreset(name: 'Dana', durationHours: 48, graceHours: 4),
  ];

  Map<String, dynamic> toJson() =>
      {'name': name, 'durationHours': durationHours, 'graceHours': graceHours};

  factory PodTypePreset.fromJson(Map<String, dynamic> j) => PodTypePreset(
        name: j['name'] as String,
        durationHours: j['durationHours'] as int,
        graceHours: j['graceHours'] as int,
      );
}

/// Holds the Home page state and drives the per-second countdown.
///
/// Uses [ChangeNotifier] so the UI can rebuild via the built-in
/// `ListenableBuilder` — no external state-management package required.
class PodController extends ChangeNotifier {
  PodController() {
    addListener(_scheduleSave); // persist on every real (non-tick) change
    addListener(_onNotifChange); // keep scheduled notifications in sync
    _boot();
  }

  PodSession? _session;
  int _stock = 6;
  bool _loading = true;
  Timer? _ticker;

  /// Per-second countdown pulse, kept separate from [notifyListeners] so only
  /// Home rebuilds each second — other screens (Settings, Stock, History) don't
  /// flicker and no disk save is triggered by the tick.
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Listenable get secondTick => _tick;

  /// Rapid −/+ taps are coalesced into a single log entry, written this long
  /// after the last tap so Stock History doesn't fill with ±1 rows.
  static const Duration stockLogDelay = Duration(seconds: 3);
  Timer? _stockDebounce;
  int _pendingStockDelta = 0;

  /// How many recent finished sessions [_avgDaysPerPod] averages over — recent
  /// enough to reflect current habits, wide enough not to be thrown off by
  /// one unusual week.
  static const int _avgSessionWindow = 10;

  /// Caps on the newest-first activity/history lists so years of daily use
  /// don't grow either list — and the JSON blob [_save] re-encodes on every
  /// debounced write — without bound. Oldest entries fall off first.
  static const int _maxActivityEntries = 500;
  static const int _maxHistoryEntries = 365;

  bool _reorderReminder = true;

  // --- Persistence (shared_preferences + JSON) -------------------------------
  SharedPreferences? _prefs;
  bool _ready = false; // becomes true after the initial load; gates saving
  Timer? _saveDebounce;
  static const Duration _saveDelay = Duration(milliseconds: 400);

  Timer? _notifDebounce;
  static const Duration _notifDelay = Duration(milliseconds: 600);
  bool _lowStockLatch = false; // true while stock is at/below threshold

  // Newest-first activity log. Empty on first launch; fills as the user acts.
  final List<TrackedItemActivity> _activity = [];

  // Newest-first session history. Empty on first launch; fills when pods end.
  final List<SessionRecord> _history = [];

  // Editable notification rules (add/edit/remove in the Notifications editor).
  final List<NotificationRule> _rules = [];

  // User-added pod types, alongside PodTypePreset.builtIn (add/remove in the
  // Pod Type picker).
  final List<PodTypePreset> _customPodTypes = [];

  void _insertActivity(TrackedItemActivity a) {
    _activity.insert(0, a);
    if (_activity.length > _maxActivityEntries) {
      _activity.removeRange(_maxActivityEntries, _activity.length);
    }
  }

  void _insertHistory(SessionRecord r) {
    _history.insert(0, r);
    if (_history.length > _maxHistoryEntries) {
      _history.removeRange(_maxHistoryEntries, _history.length);
    }
  }

  PodSession? get session => _session;
  int get stock => _stock;
  bool get isLoading => _loading;
  List<NotificationRule> get rules => List.unmodifiable(_rules);
  List<PodTypePreset> get customPodTypes => List.unmodifiable(_customPodTypes);

  /// Every pod type selectable in the picker: the three bundled presets
  /// followed by whatever the user has added.
  List<PodTypePreset> get podTypePresets => [...PodTypePreset.builtIn, ..._customPodTypes];

  String get reminderText => _formatNextReminder(nextReminderAt);
  bool get reorderReminder => _reorderReminder;
  List<TrackedItemActivity> get activity => List.unmodifiable(_activity);
  List<SessionRecord> get history => List.unmodifiable(_history);

  /// Real average wear time per pod, in days, from the most recently
  /// finished sessions — every outcome counts, not just "completed": an
  /// early swap or a stretched pod both changed how long that pod actually
  /// lasted, which is exactly the rate this is estimating. Falls back to the
  /// configured pod duration before any session history exists to learn from.
  double get _avgDaysPerPod {
    if (_history.isEmpty) return _defaultPodDurationHours / 24;
    final recent = _history.take(_avgSessionWindow);
    final avgHours =
        recent.fold<double>(0, (sum, r) => sum + r.worn.inMinutes / 60) / recent.length;
    return avgHours > 0 ? avgHours / 24 : _defaultPodDurationHours / 24;
  }

  /// Estimated days of supply remaining: stock × the real recent average
  /// wear time per pod ([_avgDaysPerPod]) — personalized to actual usage
  /// instead of a flat assumption.
  int get daysOfSupply => (_stock * _avgDaysPerPod).round();

  /// Approximate date the stock runs out, from today.
  DateTime get runsOutDate => DateTime.now().add(Duration(days: daysOfSupply));

  /// Kept for the Home info row; mirrors [runsOutDate].
  DateTime get predictedRunOut => runsOutDate;

  /// The most recently used insertion site, and when it was placed there —
  /// the active session's site if one is running (it's still in use),
  /// otherwise the most recent finished session's. `null` if there's nothing
  /// yet to compare against. Surfaced on the Add Pod sheet so the site
  /// rotation reminder has something real to rotate away from.
  ({String site, DateTime since})? get lastUsedSite {
    final active = _session;
    if (active != null && active.site != 'Not set') {
      return (site: active.site, since: active.startedAt);
    }
    if (_history.isEmpty) return null;
    final last = _history.first;
    if (last.placedOn == 'Not set') return null;
    return (site: last.placedOn, since: last.started);
  }

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
    _insertActivity(TrackedItemActivity(
      delta: delta,
      label: delta > 0 ? 'Added' : 'Removed',
      at: DateTime.now(),
    ));
    notifyListeners();
  }

  /// Set stock to an exact [value] (from the "Set exact amount" field) and log it.
  void setStock(int value) {
    _commitPendingStock(); // log any pending taps first, in chronological order
    final next = value.clamp(0, 9999);
    if (next == _stock) return;
    final applied = next - _stock;
    _stock = next;
    _insertActivity(
        TrackedItemActivity(delta: applied, label: 'Set exact amount', at: DateTime.now()));
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
  int _defaultPodDurationHours = 72;
  int _lowStockThreshold = 3;
  String _podType = 'Omnipod · 72h';
  int _gracePeriodHours = PodSession.defaultGraceHours; // 8h, matches the model
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

  /// Applies [preset]'s duration/grace as the new defaults and sets Pod Type
  /// to its label — picking a type actually changes behavior instead of
  /// just relabeling a fixed pair. Duration/Grace stay independently
  /// editable afterward via their own rows; this only sets the starting
  /// point.
  void applyPodTypePreset(PodTypePreset preset) {
    _podType = preset.label;
    _defaultPodDurationHours = preset.durationHours.clamp(1, 240);
    _gracePeriodHours = preset.graceHours.clamp(0, 240);
    notifyListeners();
  }

  /// Adds a user-defined pod type — persisted alongside the built-in
  /// presets in [podTypePresets] — and immediately applies it. A second
  /// type added under the same [name] replaces the first rather than
  /// duplicating it.
  void addCustomPodType({
    required String name,
    required int durationHours,
    required int graceHours,
  }) {
    final trimmed = name.trim();
    final preset = PodTypePreset(
      name: trimmed.isEmpty ? 'Custom' : trimmed,
      durationHours: durationHours.clamp(1, 240),
      graceHours: graceHours.clamp(0, 240),
    );
    _customPodTypes.removeWhere((p) => p.name == preset.name);
    _customPodTypes.add(preset);
    applyPodTypePreset(preset); // also notifies
  }

  /// Removes a user-added pod type. Does nothing to built-in presets or to
  /// the currently applied duration/grace, even if [name] is the type
  /// currently selected — it just drops out of the picker's list.
  void removeCustomPodType(String name) {
    final before = _customPodTypes.length;
    _customPodTypes.removeWhere((p) => p.name == name);
    if (_customPodTypes.length != before) notifyListeners();
  }

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
  void setTimeFormat(String value) {
    _set(() => _timeFormat = value, _timeFormat != value);
    _syncFormats();
  }

  void setDateFormat(String value) {
    _set(() => _dateFormat = value, _dateFormat != value);
    _syncFormats();
  }

  /// Mirror the current time/date format settings into the ambient [AppFormats]
  /// holder so every `fmt*` helper across the app renders with the user's
  /// choice. Called on load, on change, and on reset.
  void _syncFormats() {
    AppFormats.use24Hour = _timeFormat != '12-hour';
    AppFormats.dateStyle = _dateFormat;
  }

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

  // --- Notification rules ----------------------------------------------------

  void addRule(NotificationRule rule) {
    _rules.add(rule);
    notifyListeners();
  }

  void updateRule(NotificationRule rule) {
    final i = _rules.indexWhere((r) => r.id == rule.id);
    if (i < 0) {
      _rules.add(rule);
    } else {
      _rules[i] = rule;
    }
    notifyListeners();
  }

  void removeRule(String id) {
    final before = _rules.length;
    _rules.removeWhere((r) => r.id == id);
    if (_rules.length != before) notifyListeners();
  }

  void toggleRule(String id, bool enabled) {
    final i = _rules.indexWhere((r) => r.id == id);
    if (i < 0 || _rules[i].enabled == enabled) return;
    _rules[i].enabled = enabled;
    notifyListeners();
  }

  /// The soonest upcoming fire time across all enabled rules, given the current
  /// session — or null if nothing is scheduled. [lowStock] is condition-based
  /// and excluded here.
  DateTime? get nextReminderAt {
    final now = DateTime.now();
    DateTime? soonest;
    for (final r in _rules) {
      if (!r.enabled) continue;
      final at = _nextFireFor(r, now);
      if (at == null || !at.isAfter(now)) continue;
      if (soonest == null || at.isBefore(soonest)) soonest = at;
    }
    return soonest;
  }

  /// Concrete next fire time for [r] given the current session (public wrapper
  /// used by the notification scheduler). Null for condition-based rules.
  DateTime? nextFireFor(NotificationRule r) => _nextFireFor(r, DateTime.now());

  DateTime? _nextFireFor(NotificationRule r, DateTime now) {
    final s = _session;
    switch (r.trigger) {
      case NotificationTrigger.podExpiry:
        return s?.endAt.subtract(Duration(minutes: r.offsetMinutes));
      case NotificationTrigger.graceEnding:
        return s?.graceEndAt.subtract(Duration(minutes: r.offsetMinutes));
      case NotificationTrigger.podOverdue:
        return s?.graceEndAt.add(Duration(minutes: r.offsetMinutes));
      case NotificationTrigger.dailyTime:
      case NotificationTrigger.siteRotation:
        return _nextTimeOfDay(now, r.timeOfDayMinutes);
      case NotificationTrigger.lowStock:
        return null; // condition-based, fired immediately on stock change
    }
  }

  /// The next wall-clock occurrence of [minutesOfDay] at or after [now].
  DateTime _nextTimeOfDay(DateTime now, int minutesOfDay) {
    final today = DateTime(now.year, now.month, now.day, minutesOfDay ~/ 60, minutesOfDay % 60);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  String _formatNextReminder(DateTime? at) {
    if (at == null) return 'None scheduled';
    final now = DateTime.now();
    final d = at.difference(now);
    if (d.inMinutes < 1) return 'in under a minute';
    if (d.inMinutes < 60) return 'in ${d.inMinutes}m';
    if (d.inHours < 24) return 'in ${d.inHours}h ${d.inMinutes % 60}m';
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final tomorrow = at.difference(DateTime(now.year, now.month, now.day)).inDays == 1;
    if (sameDay) return 'Today ${fmtClock(at)}';
    if (tomorrow) return 'Tomorrow ${fmtClock(at)}';
    return '${fmtWeekdayDate(at)} ${fmtClock(at)}';
  }

  /// Clear the Session History (the "Clear History" action). Stock and settings
  /// are left untouched.
  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
  }

  /// Reset every Pod / Notification / Language setting to its factory default
  /// (the "Reset to Defaults" action). Stock, activity and history are kept.
  void resetToDefaults() {
    _defaultPodDurationHours = 72;
    _lowStockThreshold = 3;
    _podType = 'Omnipod · 72h';
    _gracePeriodHours = PodSession.defaultGraceHours;
    _siteRotationReminder = true;
    _enableNotifications = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _criticalAlerts = true;
    _lowStockAlert = true;
    _hidePreviews = false;
    _quietHours = true;
    _snoozeDuration = '15 min';
    _reminderHours
      ..clear()
      ..addAll([24, 6, 1]);
    _language = 'English';
    _timeFormat = '24-hour';
    _dateFormat = 'DD/MM/YYYY';
    _syncFormats();
    notifyListeners();
  }

  // --- Backup / restore --------------------------------------------------

  /// Everything this controller persists, as one JSON-able map — the same
  /// shape [_save] writes to `shared_preferences`, just bundled together
  /// instead of split across keys. Wrapped with a schema version and export
  /// timestamp by [BackupService], which owns the file I/O and share sheet.
  Map<String, dynamic> toBackupJson() {
    final s = _session;
    return {
      'stock': _stock,
      'reorderReminder': _reorderReminder,
      'activity': _activity.map((e) => e.toJson()).toList(),
      'history': _history.map((e) => e.toJson()).toList(),
      'session': s?.toJson(),
      'defaultPodDurationHours': _defaultPodDurationHours,
      'lowStockThreshold': _lowStockThreshold,
      'podType': _podType,
      'gracePeriodHours': _gracePeriodHours,
      'siteRotationReminder': _siteRotationReminder,
      'enableNotifications': _enableNotifications,
      'soundEnabled': _soundEnabled,
      'vibrationEnabled': _vibrationEnabled,
      'criticalAlerts': _criticalAlerts,
      'lowStockAlert': _lowStockAlert,
      'hidePreviews': _hidePreviews,
      'quietHours': _quietHours,
      'snoozeDuration': _snoozeDuration,
      'reminderHours': _reminderHours,
      'rules': _rules.map((e) => e.toJson()).toList(),
      'customPodTypes': _customPodTypes.map((e) => e.toJson()).toList(),
      'language': _language,
      'timeFormat': _timeFormat,
      'dateFormat': _dateFormat,
    };
  }

  /// Replaces every persisted field with what's in [j] (the `data` object of
  /// a parsed backup — see `BackupService.pickBackup`). Everything is parsed
  /// into locals first and only assigned once all of it succeeds, so a
  /// corrupt or hand-edited file throws before any current data is touched
  /// rather than leaving a half-overwritten state.
  void restoreFromBackupJson(Map<String, dynamic> j) {
    final stock = j['stock'] as int? ?? _stock;
    final reorder = j['reorderReminder'] as bool? ?? _reorderReminder;
    final activity = ((j['activity'] as List?) ?? const [])
        .map((e) => TrackedItemActivity.fromJson(e as Map<String, dynamic>))
        .toList();
    final history = ((j['history'] as List?) ?? const [])
        .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final sessionJson = j['session'] as Map<String, dynamic>?;
    final session = sessionJson != null ? PodSession.fromJson(sessionJson) : null;
    final duration = j['defaultPodDurationHours'] as int? ?? _defaultPodDurationHours;
    final lowStock = j['lowStockThreshold'] as int? ?? _lowStockThreshold;
    final podType = j['podType'] as String? ?? _podType;
    final grace = j['gracePeriodHours'] as int? ?? _gracePeriodHours;
    final siteRotation = j['siteRotationReminder'] as bool? ?? _siteRotationReminder;
    final enableNotif = j['enableNotifications'] as bool? ?? _enableNotifications;
    final sound = j['soundEnabled'] as bool? ?? _soundEnabled;
    final vibration = j['vibrationEnabled'] as bool? ?? _vibrationEnabled;
    final critical = j['criticalAlerts'] as bool? ?? _criticalAlerts;
    final lowStockAlert = j['lowStockAlert'] as bool? ?? _lowStockAlert;
    final hidePrev = j['hidePreviews'] as bool? ?? _hidePreviews;
    final quiet = j['quietHours'] as bool? ?? _quietHours;
    final snooze = j['snoozeDuration'] as String? ?? _snoozeDuration;
    final reminderHours = (j['reminderHours'] as List?)?.map((e) => e as int).toList() ??
        List<int>.from(_reminderHours);
    final rules = ((j['rules'] as List?) ?? const [])
        .map((e) => NotificationRule.fromJson(e as Map<String, dynamic>))
        .toList();
    final customPodTypes = ((j['customPodTypes'] as List?) ?? const [])
        .map((e) => PodTypePreset.fromJson(e as Map<String, dynamic>))
        .toList();
    final language = j['language'] as String? ?? _language;
    final timeFormat = j['timeFormat'] as String? ?? _timeFormat;
    final dateFormat = j['dateFormat'] as String? ?? _dateFormat;

    // Everything parsed cleanly — commit it all at once.
    _stockDebounce?.cancel();
    _stockDebounce = null;
    _pendingStockDelta = 0;

    _stock = stock;
    _reorderReminder = reorder;
    _activity
      ..clear()
      ..addAll(activity);
    _history
      ..clear()
      ..addAll(history);
    _session = session;
    _defaultPodDurationHours = duration;
    _lowStockThreshold = lowStock;
    _podType = podType;
    _gracePeriodHours = grace;
    _siteRotationReminder = siteRotation;
    _enableNotifications = enableNotif;
    _soundEnabled = sound;
    _vibrationEnabled = vibration;
    _criticalAlerts = critical;
    _lowStockAlert = lowStockAlert;
    _hidePreviews = hidePrev;
    _quietHours = quiet;
    _snoozeDuration = snooze;
    _reminderHours
      ..clear()
      ..addAll(reminderHours);
    _rules
      ..clear()
      ..addAll(rules);
    _customPodTypes
      ..clear()
      ..addAll(customPodTypes);
    _language = language;
    _timeFormat = timeFormat;
    _dateFormat = dateFormat;
    _syncFormats();

    _lowStockLatch = _stock <= _lowStockThreshold; // don't alert for pre-existing low stock
    if (_session != null) {
      _startTicker();
    } else {
      _ticker?.cancel();
      _ticker = null;
    }

    notifyListeners(); // triggers the usual debounced save + notification resync
  }

  Future<void> _boot() async {
    _prefs = await SharedPreferences.getInstance();
    _load(); // restore saved state, or keep the seeded defaults on first run
    _loading = false;
    _ready = true;
    _lowStockLatch = _stock <= _lowStockThreshold; // don't alert for pre-existing low stock
    if (_session != null) _startTicker();
    notifyListeners();
    NotificationService.instance.sync(this); // schedule from restored rules
  }

  // --- Persistence keys ------------------------------------------------------
  static const String _kStock = 'stock';
  static const String _kReorder = 'reorderReminder';
  static const String _kActivity = 'activity';
  static const String _kHistory = 'history';
  static const String _kSession = 'session';
  static const String _kDuration = 'defaultPodDurationHours';
  static const String _kLowStock = 'lowStockThreshold';
  static const String _kPodType = 'podType';
  static const String _kGrace = 'gracePeriodHours';
  static const String _kSiteRot = 'siteRotationReminder';
  static const String _kEnableNotif = 'enableNotifications';
  static const String _kSound = 'soundEnabled';
  static const String _kVibration = 'vibrationEnabled';
  static const String _kCritical = 'criticalAlerts';
  static const String _kLowStockAlert = 'lowStockAlert';
  static const String _kHidePrev = 'hidePreviews';
  static const String _kQuiet = 'quietHours';
  static const String _kSnooze = 'snoozeDuration';
  static const String _kReminders = 'reminderHours';
  static const String _kRules = 'notificationRules';
  static const String _kCustomPodTypes = 'customPodTypes';
  static const String _kLanguage = 'language';
  static const String _kTimeFmt = 'timeFormat';
  static const String _kDateFmt = 'dateFormat';

  /// Restore all persisted state. Missing keys leave the in-memory defaults
  /// (seeds on first run) untouched.
  void _load() {
    final p = _prefs;
    if (p == null) return;

    if (p.containsKey(_kStock)) _stock = p.getInt(_kStock)!;
    if (p.containsKey(_kReorder)) _reorderReminder = p.getBool(_kReorder)!;

    final act = p.getString(_kActivity);
    if (act != null) {
      _activity
        ..clear()
        ..addAll((jsonDecode(act) as List)
            .map((e) => TrackedItemActivity.fromJson(e as Map<String, dynamic>)));
    }

    final his = p.getString(_kHistory);
    if (his != null) {
      _history
        ..clear()
        ..addAll((jsonDecode(his) as List)
            .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>)));
    }

    final ses = p.getString(_kSession);
    _session = (ses != null && ses.isNotEmpty)
        ? PodSession.fromJson(jsonDecode(ses) as Map<String, dynamic>)
        : null;

    _defaultPodDurationHours = p.getInt(_kDuration) ?? _defaultPodDurationHours;
    _lowStockThreshold = p.getInt(_kLowStock) ?? _lowStockThreshold;
    _podType = p.getString(_kPodType) ?? _podType;
    _gracePeriodHours = p.getInt(_kGrace) ?? _gracePeriodHours;
    _siteRotationReminder = p.getBool(_kSiteRot) ?? _siteRotationReminder;
    _enableNotifications = p.getBool(_kEnableNotif) ?? _enableNotifications;
    _soundEnabled = p.getBool(_kSound) ?? _soundEnabled;
    _vibrationEnabled = p.getBool(_kVibration) ?? _vibrationEnabled;
    _criticalAlerts = p.getBool(_kCritical) ?? _criticalAlerts;
    _lowStockAlert = p.getBool(_kLowStockAlert) ?? _lowStockAlert;
    _hidePreviews = p.getBool(_kHidePrev) ?? _hidePreviews;
    _quietHours = p.getBool(_kQuiet) ?? _quietHours;
    _snoozeDuration = p.getString(_kSnooze) ?? _snoozeDuration;
    final rem = p.getStringList(_kReminders);
    if (rem != null) {
      _reminderHours
        ..clear()
        ..addAll(rem.map(int.parse));
    }
    _language = p.getString(_kLanguage) ?? _language;
    _timeFormat = p.getString(_kTimeFmt) ?? _timeFormat;
    _dateFormat = p.getString(_kDateFmt) ?? _dateFormat;
    _syncFormats();

    final rulesJson = p.getString(_kRules);
    if (rulesJson != null) {
      _rules
        ..clear()
        ..addAll((jsonDecode(rulesJson) as List)
            .map((e) => NotificationRule.fromJson(e as Map<String, dynamic>)));
    } else {
      _migrateRules(); // first run after this feature: seed from legacy settings
    }

    final customTypesJson = p.getString(_kCustomPodTypes);
    if (customTypesJson != null) {
      _customPodTypes
        ..clear()
        ..addAll((jsonDecode(customTypesJson) as List)
            .map((e) => PodTypePreset.fromJson(e as Map<String, dynamic>)));
    }
  }

  /// One-time seed of notification rules from the pre-editor state: each
  /// "hours before expiry" reminder, plus Low Stock and Site Rotation, which
  /// used to be standalone toggles.
  void _migrateRules() {
    _rules.clear();
    final base = DateTime.now().microsecondsSinceEpoch;
    var seq = 0;
    for (final h in _reminderHours) {
      _rules.add(NotificationRule(
        id: '${base}_${seq++}',
        trigger: NotificationTrigger.podExpiry,
        offsetMinutes: h * 60,
      ));
    }
    _rules.add(NotificationRule(
      id: '${base}_${seq++}',
      trigger: NotificationTrigger.lowStock,
      enabled: _lowStockAlert,
    ));
    _rules.add(NotificationRule(
      id: '${base}_${seq++}',
      trigger: NotificationTrigger.siteRotation,
      enabled: _siteRotationReminder,
    ));
  }

  /// Debounced save, fired by the self-listener on every real change. Coalesces
  /// bursts (e.g. rapid stepper taps) into a single write.
  void _scheduleSave() {
    if (!_ready) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDelay, _save);
  }

  /// Fired on every real change: reacts immediately to a low-stock crossing and
  /// debounces a full reschedule of the timed notifications.
  void _onNotifChange() {
    if (!_ready) return;
    _checkLowStock();
    _notifDebounce?.cancel();
    _notifDebounce = Timer(_notifDelay, () => NotificationService.instance.sync(this));
  }

  /// Fire an immediate low-stock notification once, the moment stock drops to
  /// the threshold. The latch resets when stock rises above it again.
  void _checkLowStock() {
    if (_stock <= _lowStockThreshold) {
      if (!_lowStockLatch) {
        _lowStockLatch = true;
        final hasRule =
            _rules.any((r) => r.enabled && r.trigger == NotificationTrigger.lowStock);
        if (hasRule) NotificationService.instance.showLowStockNow(this);
      }
    } else {
      _lowStockLatch = false;
    }
  }

  /// Writes every key independently, so they're fired concurrently rather
  /// than as ~20 sequential platform-channel round-trips.
  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    final s = _session;
    await Future.wait([
      p.setInt(_kStock, _stock),
      p.setBool(_kReorder, _reorderReminder),
      p.setString(_kActivity, jsonEncode(_activity.map((e) => e.toJson()).toList())),
      p.setString(_kHistory, jsonEncode(_history.map((e) => e.toJson()).toList())),
      p.setString(_kSession, s == null ? '' : jsonEncode(s.toJson())),
      p.setInt(_kDuration, _defaultPodDurationHours),
      p.setInt(_kLowStock, _lowStockThreshold),
      p.setString(_kPodType, _podType),
      p.setInt(_kGrace, _gracePeriodHours),
      p.setBool(_kSiteRot, _siteRotationReminder),
      p.setBool(_kEnableNotif, _enableNotifications),
      p.setBool(_kSound, _soundEnabled),
      p.setBool(_kVibration, _vibrationEnabled),
      p.setBool(_kCritical, _criticalAlerts),
      p.setBool(_kLowStockAlert, _lowStockAlert),
      p.setBool(_kHidePrev, _hidePreviews),
      p.setBool(_kQuiet, _quietHours),
      p.setString(_kSnooze, _snoozeDuration),
      p.setStringList(_kReminders, _reminderHours.map((e) => e.toString()).toList()),
      p.setString(_kRules, jsonEncode(_rules.map((e) => e.toJson()).toList())),
      p.setString(_kCustomPodTypes, jsonEncode(_customPodTypes.map((e) => e.toJson()).toList())),
      p.setString(_kLanguage, _language),
      p.setString(_kTimeFmt, _timeFormat),
      p.setString(_kDateFmt, _dateFormat),
    ]);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session != null) _tick.value++; // Home-only pulse, not a full notify
    });
  }

  /// How many of the currently-configured lifecycle reminders (pod expiry,
  /// grace ending, pod overdue) were due to fire for [session] before [end] —
  /// the closest honest proxy for "reminders sent" this app can compute: a
  /// scheduled local notification confirms only that it was *tapped* (see
  /// `NotificationService`), never that it was actually delivered, but the
  /// app does know exactly when each enabled rule was due to fire relative
  /// to this session, using the same fire-time math as `_nextFireFor`.
  int _remindersFiredFor(PodSession session, DateTime end) {
    var count = 0;
    for (final r in _rules) {
      if (!r.enabled) continue;
      final at = switch (r.trigger) {
        NotificationTrigger.podExpiry =>
          session.endAt.subtract(Duration(minutes: r.offsetMinutes)),
        NotificationTrigger.graceEnding =>
          session.graceEndAt.subtract(Duration(minutes: r.offsetMinutes)),
        NotificationTrigger.podOverdue =>
          session.graceEndAt.add(Duration(minutes: r.offsetMinutes)),
        _ => null,
      };
      if (at != null && !at.isBefore(session.startedAt) && !at.isAfter(end)) count++;
    }
    return count;
  }

  /// "+3h 30m" / "-3h 30m" / "None" — how far actual wear time differed from
  /// what the pod was planned for, shown in the History card's CHANGES field.
  String _formatChanges(Duration worn, Duration planned) {
    final delta = worn - planned;
    if (delta.inMinutes.abs() < 1) return 'None';
    return '${delta.isNegative ? '-' : '+'}${fmtHm(delta.abs())}';
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
    final wornClamped = worn.isNegative ? Duration.zero : worn;
    final outcome = switch (session.statusAt(end)) {
      TrackedItemStatus.onTrack => HistoryOutcome.endedEarly,
      TrackedItemStatus.grace => HistoryOutcome.completed,
      TrackedItemStatus.late => HistoryOutcome.wornTooLong,
    };
    _insertHistory(SessionRecord(
      date: end,
      outcome: outcome,
      started: session.startedAt,
      ended: end,
      worn: wornClamped,
      placedOn: session.site,
      whyChanged: reason,
      remindersSent: _remindersFiredFor(session, end),
      changes: _formatChanges(wornClamped, session.totalDuration),
      plannedHours: session.durationHours,
    ));
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
  /// The session carries the user's Default Pod Duration and Grace Period.
  ///
  /// If a pod is already active it is ended first — at the new pod's start time
  /// — so the replaced session is recorded in history rather than silently
  /// discarded. The Add Pod sheet confirms this replacement with the user.
  void startPod({DateTime? startedAt, String site = 'Not set'}) {
    _commitPendingStock(); // log any pending taps before the session entry
    final start = startedAt ?? DateTime.now();
    if (_session != null) endPod(endedAt: start, reason: 'Replaced');
    _session = PodSession(
      startedAt: start,
      site: site,
      durationHours: _defaultPodDurationHours,
      graceHours: _gracePeriodHours,
    );
    _loading = false;
    if (_stock > 0) {
      _stock -= 1;
      _insertActivity(
        TrackedItemActivity(delta: -1, label: 'Session started', note: site, at: DateTime.now()),
      );
    }
    _startTicker();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stockDebounce?.cancel();
    _saveDebounce?.cancel();
    _notifDebounce?.cancel();
    _tick.dispose();
    super.dispose();
  }
}
