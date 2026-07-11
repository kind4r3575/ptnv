import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lifecycle of a pod relative to its wear time.
///
/// A pod is rated for [PodSession.durationHours] (72h). After that it enters an
/// [PodSession.graceHours] (8h) grace window where it is still delivering but
/// should be changed, and once that elapses it has stopped delivering (late).
enum PodStatus { onTrack, grace, late }

@immutable
class PodSession {
  const PodSession({
    required this.startedAt,
    this.site = 'Not set',
    this.durationHours = defaultDurationHours,
    this.graceHours = defaultGraceHours,
  });

  final DateTime startedAt;

  /// Insertion site chosen on the Add Pod sheet, carried into Session History.
  final String site;

  /// How many hours this pod is rated for. Defaults to [defaultDurationHours]
  /// but a session started from Settings carries the user's chosen value.
  final int durationHours;

  /// Grace window (hours) after the rated end, during which the pod still
  /// delivers. Carries the user's "Grace Period" setting.
  final int graceHours;

  static const int defaultDurationHours = 72;
  static const int defaultGraceHours = 8;

  Duration get totalDuration => Duration(hours: durationHours);

  /// When the pod reaches its rated 72h.
  DateTime get endAt => startedAt.add(totalDuration);

  /// When the grace window ends and the pod stops delivering (80h).
  DateTime get graceEndAt => endAt.add(Duration(hours: graceHours));

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

  Map<String, dynamic> toJson() => {
        'delta': delta,
        'label': label,
        'note': note,
        'at': at.toIso8601String(),
      };

  factory StockActivity.fromJson(Map<String, dynamic> j) => StockActivity(
        delta: j['delta'] as int,
        label: j['label'] as String,
        note: j['note'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
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

/// Holds the Home page state and drives the per-second countdown.
///
/// Uses [ChangeNotifier] so the UI can rebuild via the built-in
/// `ListenableBuilder` — no external state-management package required.
class PodController extends ChangeNotifier {
  PodController() {
    addListener(_scheduleSave); // persist on every real (non-tick) change
    _boot();
  }

  PodSession? _session;
  int _stock = 6;
  String? _reminder; // null => "None scheduled"
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

  /// Pods used up per day of supply estimate — "≈ stock × 3 days".
  static const int daysPerPod = 3;

  bool _reorderReminder = true;

  // --- Persistence (shared_preferences + JSON) -------------------------------
  SharedPreferences? _prefs;
  bool _ready = false; // becomes true after the initial load; gates saving
  Timer? _saveDebounce;
  static const Duration _saveDelay = Duration(milliseconds: 400);

  // Newest-first activity log. Empty on first launch; fills as the user acts.
  final List<StockActivity> _activity = [];

  // Newest-first session history. Empty on first launch; fills when pods end.
  final List<SessionRecord> _history = [];

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
    notifyListeners();
  }

  Future<void> _boot() async {
    _prefs = await SharedPreferences.getInstance();
    _load(); // restore saved state, or keep the seeded defaults on first run
    _loading = false;
    _ready = true;
    if (_session != null) _startTicker();
    notifyListeners();
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
            .map((e) => StockActivity.fromJson(e as Map<String, dynamic>)));
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
  }

  /// Debounced save, fired by the self-listener on every real change. Coalesces
  /// bursts (e.g. rapid stepper taps) into a single write.
  void _scheduleSave() {
    if (!_ready) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDelay, _save);
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt(_kStock, _stock);
    await p.setBool(_kReorder, _reorderReminder);
    await p.setString(
        _kActivity, jsonEncode(_activity.map((e) => e.toJson()).toList()));
    await p.setString(
        _kHistory, jsonEncode(_history.map((e) => e.toJson()).toList()));
    final s = _session;
    await p.setString(_kSession, s == null ? '' : jsonEncode(s.toJson()));
    await p.setInt(_kDuration, _defaultPodDurationHours);
    await p.setInt(_kLowStock, _lowStockThreshold);
    await p.setString(_kPodType, _podType);
    await p.setInt(_kGrace, _gracePeriodHours);
    await p.setBool(_kSiteRot, _siteRotationReminder);
    await p.setBool(_kEnableNotif, _enableNotifications);
    await p.setBool(_kSound, _soundEnabled);
    await p.setBool(_kVibration, _vibrationEnabled);
    await p.setBool(_kCritical, _criticalAlerts);
    await p.setBool(_kLowStockAlert, _lowStockAlert);
    await p.setBool(_kHidePrev, _hidePreviews);
    await p.setBool(_kQuiet, _quietHours);
    await p.setString(_kSnooze, _snoozeDuration);
    await p.setStringList(
        _kReminders, _reminderHours.map((e) => e.toString()).toList());
    await p.setString(_kLanguage, _language);
    await p.setString(_kTimeFmt, _timeFormat);
    await p.setString(_kDateFmt, _dateFormat);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session != null) _tick.value++; // Home-only pulse, not a full notify
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
        plannedHours: session.durationHours,
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
  /// The session carries the user's Default Pod Duration and Grace Period.
  void startPod({DateTime? startedAt, String site = 'Not set'}) {
    _commitPendingStock(); // log any pending taps before the session entry
    _session = PodSession(
      startedAt: startedAt ?? DateTime.now(),
      site: site,
      durationHours: _defaultPodDurationHours,
      graceHours: _gracePeriodHours,
    );
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
    _saveDebounce?.cancel();
    _tick.dispose();
    super.dispose();
  }
}
