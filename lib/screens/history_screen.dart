import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/pod.dart';
import '../state/root_tabs.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/home_parts.dart';
import '../widgets/number_edit_sheet.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/start_time_picker_sheet.dart';
import '../widgets/tab_listenable_builder.dart';

/// The Session History screen (Figma node `30:2`): a scroll of past-session
/// cards read from [PodController.history].
///
/// * **Hold** a card to edit it: it presses down while held, then swings
///   once, gently, as edit mode starts. In edit mode every editable value
///   (marked with a pencil) can be tapped and changed. Values worked out from
///   others (WORN, the badge, the bar, CHANGES, the date) update live. Nothing
///   is saved until Save; Cancel, Back, or leaving the tab throws the changes
///   away. Either way the card swings once more as edit mode ends. Once
///   saved, the card shows "✎ Edited" beside its badge.
/// * **Swipe left** to delete a card. A "Session deleted · Undo" bar puts it
///   back in place.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller, required this.tabs});

  final PodController controller;
  final RootTabController tabs;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// A value on a History card that can be changed in edit mode.
enum HistoryField { started, ended, planned, placedOn, whyChanged, reminders }

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _tabIndex = 3;

  /// The record being edited, as it is in [PodController.history], and the
  /// unsaved copy shown on its card. Both null outside edit mode.
  SessionRecord? _original;
  SessionRecord? _draft;

  bool get _editing => _original != null;

  @override
  void initState() {
    super.initState();
    widget.tabs.addListener(_onTabsChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.tabs.removeListener(_onTabsChanged);
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Leaving the tab ends edit mode without saving, so the card isn't still
  /// sitting in edit mode with half-made changes when the user comes back.
  void _onTabsChanged() {
    if (widget.tabs.index != _tabIndex && _editing) _cancelEdit();
  }

  /// The edited record vanished underneath us (e.g. history was cleared or
  /// replaced by an import): drop the edit rather than show a stale card.
  void _onControllerChanged() {
    final original = _original;
    if (original != null && !widget.controller.history.any((r) => identical(r, original))) {
      _cancelEdit();
    }
  }

  void _startEditing(SessionRecord r) => setState(() {
        _original = r;
        _draft = r;
      });

  void _cancelEdit() {
    if (!_editing) return;
    setState(() {
      _original = null;
      _draft = null;
    });
  }

  void _save() {
    final original = _original;
    final draft = _draft;
    if (original == null || draft == null) return;
    _cancelEdit();
    widget.controller.updateHistoryRecord(original, draft);
  }

  void _delete(SessionRecord r) {
    HapticFeedback.mediumImpact();
    final index = widget.controller.deleteHistoryRecord(r);
    if (index < 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Session deleted'),
        duration: const Duration(seconds: 4),
        persist: false, // auto-hide even though it has an action
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.controller.restoreHistoryRecord(r, index),
        ),
      ));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  // --- Field editors ----------------------------------------------------------

  /// Opens the editor for [field] and, if the user picks a new value, applies
  /// it to the draft. Nothing reaches the controller until Save.
  Future<void> _editField(HistoryField field) async {
    final d = _draft;
    if (d == null) return;
    final grace = widget.controller.gracePeriodHours;
    final next = switch (field) {
      HistoryField.started => await _pickStarted(d, grace),
      HistoryField.ended => await _pickEnded(d, grace),
      HistoryField.planned => await _pickPlanned(d, grace),
      HistoryField.placedOn => await _pickSite(d, grace),
      HistoryField.whyChanged => await _pickReason(d, grace),
      HistoryField.reminders => await _pickReminders(d, grace),
    };
    if (next == null || !mounted || !identical(_draft, d)) return;
    setState(() => _draft = next);
  }

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day &&
      a.hour == b.hour && a.minute == b.minute;

  Future<SessionRecord?> _pickStarted(SessionRecord d, int grace) async {
    final picked = await showStartTimePicker(
      context,
      initial: d.started,
      title: 'Started',
      subtitle: 'When was this pod applied?',
      confirmLabel: 'Set start time',
      footnote: (t) => t.isBefore(d.ended)
          ? 'Worn ${fmtHm(d.ended.difference(t))}'
          : 'Has to be before the end time',
    );
    if (picked == null || !mounted || _sameMinute(picked, d.started)) return null;
    if (!picked.isBefore(d.ended)) {
      _toast('The start has to be before the end time.');
      return null;
    }
    return d.withEdits(started: picked, fallbackGraceHours: grace);
  }

  Future<SessionRecord?> _pickEnded(SessionRecord d, int grace) async {
    final picked = await showStartTimePicker(
      context,
      initial: d.ended,
      title: 'Ended',
      subtitle: 'When did you change this pod?',
      confirmLabel: 'Set end time',
      footnote: (t) => t.isAfter(d.started)
          ? 'Worn ${fmtHm(t.difference(d.started))}'
          : 'Has to be after the start time',
    );
    if (picked == null || !mounted || _sameMinute(picked, d.ended)) return null;
    if (!picked.isAfter(d.started)) {
      _toast('The end has to be after the start time.');
      return null;
    }
    if (picked.isAfter(DateTime.now())) {
      _toast("The end time can't be in the future.");
      return null;
    }
    return d.withEdits(ended: picked, fallbackGraceHours: grace);
  }

  Future<SessionRecord?> _pickPlanned(SessionRecord d, int grace) async {
    final v = await showNumberEditSheet(
      context: context,
      title: 'Planned wear',
      subtitle: 'How many hours this pod was meant to last',
      initial: d.plannedHours,
      unit: 'hours',
      min: 1,
      max: 240,
    );
    if (v == null || v == d.plannedHours) return null;
    return d.withEdits(plannedHours: v, fallbackGraceHours: grace);
  }

  /// [standard] options, plus [current] first if it isn't one of them (e.g. a
  /// "Not set" site or a "Replaced" reason), so it still shows as selected.
  static List<String> _optionsWith(List<String> standard, String current) =>
      [if (!standard.contains(current)) current, ...standard];

  Future<SessionRecord?> _pickSite(SessionRecord d, int grace) async {
    final v = await showOptionPickerSheet<String>(
      context: context,
      title: 'Placed on',
      subtitle: 'Where was this pod placed?',
      options: _optionsWith(PodSession.insertionSites, d.placedOn),
      selected: d.placedOn,
      labelOf: (s) => s,
    );
    if (v == null || v == d.placedOn) return null;
    return d.withEdits(placedOn: v, fallbackGraceHours: grace);
  }

  Future<SessionRecord?> _pickReason(SessionRecord d, int grace) async {
    final v = await showOptionPickerSheet<String>(
      context: context,
      title: 'Why changed',
      subtitle: 'Why was this pod changed?',
      options: _optionsWith(SessionRecord.changeReasons, d.whyChanged),
      selected: d.whyChanged,
      labelOf: (s) => s,
    );
    if (v == null || v == d.whyChanged) return null;
    return d.withEdits(whyChanged: v, fallbackGraceHours: grace);
  }

  Future<SessionRecord?> _pickReminders(SessionRecord d, int grace) async {
    final v = await showNumberEditSheet(
      context: context,
      title: 'Reminders sent',
      subtitle: 'How many reminders went out for this pod',
      initial: d.remindersSent,
      unit: 'sent',
      min: 0,
      max: 99,
    );
    if (v == null || v == d.remindersSent) return null;
    return d.withEdits(remindersSent: v, fallbackGraceHours: grace);
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back while editing leaves edit mode instead of leaving the app.
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelEdit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: TabListenableBuilder(
            listenable: widget.controller,
            tabs: widget.tabs,
            tabIndex: _tabIndex,
            builder: (context) {
              return Column(
                children: [
                  AppBarWave(
                    title: 'History',
                    leading: appBackButton(context, widget.tabs),
                  ),
                  Expanded(child: _body(context)),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: appBottomBar(context, widget.controller, widget.tabs, _tabIndex),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final items = widget.controller.history;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: 14),
            Text('No pod history yet', style: AppText.emptyTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 6),
            Text('Finished pods show up here.', style: AppText.emptySub),
          ],
        ),
      );
    }
    final editing = _original;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      // Cards are keyed by the record's id, which survives an edit, so a
      // saved card keeps its widget state (and plays its closing swing) even
      // though Save swaps in a new record, and even if a new end time moves
      // it in the list.
      findItemIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final i = items.indexWhere((r) => r.id == key.value);
        return i < 0 ? null : i;
      },
      itemBuilder: (_, i) {
        final r = items[i];
        final isEditing = identical(r, editing);
        final draft = _draft;
        return Dismissible(
          key: ValueKey<String>(r.id),
          // No swiping while any card is being edited.
          direction: editing == null ? DismissDirection.endToStart : DismissDirection.none,
          dismissThresholds: const {DismissDirection.endToStart: 0.4},
          background: const _DeleteBackground(),
          onUpdate: (details) {
            // A tick as the swipe crosses the point where letting go deletes.
            if (details.reached != details.previousReached) HapticFeedback.selectionClick();
          },
          onDismissed: (_) => _delete(r),
          child: _HoldToEdit(
            editing: isEditing,
            onLongPress: editing == null ? () => _startEditing(r) : null,
            child: SessionHistoryCard(
              record: isEditing && draft != null ? draft : r,
              onEdit: isEditing ? _editField : null,
              footer: isEditing && draft != null
                  ? _EditActions(
                      canSave: !r.hasSameEditsAs(draft),
                      onCancel: _cancelEdit,
                      onSave: _save,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// One past-session card rendered per the Figma design.
///
/// With [onEdit] set the card is in edit mode: each editable value shows a
/// pencil after its label and calls [onEdit] when tapped. [footer] (the
/// Save / Cancel row) goes under the last row.
class SessionHistoryCard extends StatelessWidget {
  const SessionHistoryCard({super.key, required this.record, this.onEdit, this.footer});

  final SessionRecord record;
  final ValueChanged<HistoryField>? onEdit;
  final Widget? footer;

  ({String label, Color fg, Color bg}) get _badge {
    switch (record.outcome) {
      case HistoryOutcome.endedEarly:
        return (label: 'Ended early', fg: AppColors.amberText, bg: AppColors.amberBg);
      case HistoryOutcome.wornTooLong:
        return (label: 'Worn too long', fg: AppColors.redText, bg: AppColors.redBg);
      case HistoryOutcome.completed:
        return (label: 'Completed', fg: AppColors.green, bg: AppColors.green.withValues(alpha: 0.14));
    }
  }

  ({String text, Color color}) get _note {
    switch (record.outcome) {
      case HistoryOutcome.endedEarly:
        return (text: 'Changed ${fmtHm(record.planned - record.worn)} early', color: AppColors.amberText);
      case HistoryOutcome.wornTooLong:
        return (text: 'Worn ${fmtHm(record.worn - record.planned)} too long', color: AppColors.redText);
      case HistoryOutcome.completed:
        return (text: 'Worn the full ${record.planned.inHours}h', color: AppColors.green);
    }
  }

  /// The tap handler for [field] in edit mode, or null outside it.
  VoidCallback? _editor(HistoryField field) {
    final edit = onEdit;
    return edit == null ? null : () => edit(field);
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final note = _note;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                // Shrinks rather than cuts off when the Edited mark and a
                // long badge share a narrow phone's row.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmtDate(record.date),
                    maxLines: 1,
                    style: AppText.sheetTitle.copyWith(fontSize: 19),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (record.edited) ...[
                const Icon(Icons.edit_rounded, size: 12, color: AppColors.slate),
                const SizedBox(width: 3),
                Text('Edited', style: AppText.caption),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: badge.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: badge.fg, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(badge.label,
                        style: AppText.badge.copyWith(color: badge.fg, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const _CardDivider(),
          _PairRow(
            left: _Field(
              label: 'STARTED',
              value: fmtExpiry(record.started),
              onTap: _editor(HistoryField.started),
            ),
            right: _Field(
              label: 'ENDED',
              value: fmtExpiry(record.ended),
              onTap: _editor(HistoryField.ended),
            ),
          ),
          const _CardDivider(),
          _PairRow(
            left: _Field(
              label: 'WORN',
              value: fmtHm(record.worn),
              valueStyle: AppText.sheetTitle.copyWith(fontSize: 18),
            ),
            right: _Field(
              label: 'PLANNED',
              value: '${record.planned.inHours}h',
              valueStyle: AppText.statValue.copyWith(fontSize: 16, color: AppColors.slate),
              onTap: _editor(HistoryField.planned),
            ),
          ),
          const SizedBox(height: 12),
          _HistoryBar(record: record),
          const SizedBox(height: 8),
          Text(note.text, style: AppText.caption.copyWith(color: note.color)),
          const _CardDivider(),
          _PairRow(
            left: _Field(
              label: 'PLACED ON',
              value: record.placedOn,
              onTap: _editor(HistoryField.placedOn),
            ),
            right: _Field(
              label: 'WHY CHANGED',
              value: record.whyChanged,
              onTap: _editor(HistoryField.whyChanged),
            ),
          ),
          const SizedBox(height: 14),
          _PairRow(
            left: _Field(
              label: 'REMINDERS',
              value: '${record.remindersSent} sent',
              onTap: _editor(HistoryField.reminders),
            ),
            right: _Field(label: 'CHANGES', value: record.changes),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: footer ?? const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.divider),
      );
}

/// Two side-by-side fields, each taking half the card's width.
class _PairRow extends StatelessWidget {
  const _PairRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        Expanded(child: right),
      ],
    );
  }
}

/// An eyebrow label over a value. With [onTap] set (edit mode) a pencil
/// follows the label and the whole half-width cell is a tap target. The
/// pencil is smaller than the label's line height, so entering edit mode
/// doesn't shift the layout.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.valueStyle = AppText.statValue,
    this.onTap,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final editable = onTap != null;
    final content = SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(label, style: AppText.statLabel)),
              if (editable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded, size: 11, color: AppColors.blue),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: valueStyle),
        ],
      ),
    );
    if (!editable) return content;
    return Pressable(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
  }
}

/// Cancel / Save under an edited card. Save stays greyed out until something
/// has actually changed.
class _EditActions extends StatelessWidget {
  const _EditActions({required this.canSave, required this.onCancel, required this.onSave});

  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  Widget _button({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback? onTap,
  }) {
    return Pressable(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: AppText.button.copyWith(fontSize: 15, color: fg)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: _button(
              label: 'Cancel',
              bg: AppColors.surfaceAlt,
              fg: AppColors.slate,
              onTap: onCancel,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _button(
              label: 'Save',
              bg: canSave ? AppColors.blue : AppColors.chipBorder,
              fg: AppColors.white,
              onTap: canSave ? onSave : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hold-to-edit wrapper for a History card.
///
/// While a finger rests on the card it slowly presses down over the
/// long-press delay, so a quick touch at the start of a scroll barely moves
/// it. When the hold completes it springs back with [Pressable]'s release
/// bounce, gives a haptic tick and calls [onLongPress].
///
/// Whenever [editing] turns on or off, the card swings once, gently: it tips
/// one way, comes back a little less the other way, and settles, all within
/// [_swingDuration]. There's no swing when the system asks for reduced
/// motion.
class _HoldToEdit extends StatefulWidget {
  const _HoldToEdit({required this.onLongPress, required this.editing, required this.child});

  final VoidCallback? onLongPress;
  final bool editing;
  final Widget child;

  @override
  State<_HoldToEdit> createState() => _HoldToEditState();
}

class _HoldToEditState extends State<_HoldToEdit> with TickerProviderStateMixin {
  static const double _pressedScale = 0.97;
  static const double _swingAngle = 0.012; // radians; the first lean peaks near 0.5°
  static const Duration _swingDuration = Duration(milliseconds: 500);

  /// Press depth, as in [Pressable]: 0 at rest, 1 fully pressed, below 0
  /// during the release bounce.
  late final AnimationController _depth = AnimationController.unbounded(vsync: this);
  late final Animation<double> _scale =
      _depth.drive(Tween<double>(begin: 1, end: _pressedScale));
  late final AnimationController _swing =
      AnimationController(vsync: this, duration: _swingDuration);

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// The card's tilt at the current point of the swing: one full sine wave
  /// (over, back, home) fading out as it goes, so it ends at rest.
  double get _angle {
    final t = _swing.value;
    return math.sin(t * 2 * math.pi) * (1 - t) * _swingAngle;
  }

  @override
  void didUpdateWidget(_HoldToEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing != oldWidget.editing && !_reduceMotion) {
      _swing.forward(from: 0); // edit mode started or ended
    }
    if (widget.onLongPress == null) _release(); // disabled mid-hold
  }

  @override
  void dispose() {
    _depth.dispose();
    _swing.dispose();
    super.dispose();
  }

  void _pressIn() {
    if (_reduceMotion) return;
    _depth.animateTo(1, duration: kLongPressTimeout, curve: Curves.easeOut);
  }

  void _release() {
    if (_depth.value == 0) {
      _depth.stop();
      return;
    }
    _depth.animateWith(PressRelease(from: _depth.value));
  }

  void _onLongPress() {
    _release();
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onLongPress != null;
    return GestureDetector(
      onLongPressDown: enabled ? (_) => _pressIn() : null,
      onLongPressCancel: enabled ? _release : null,
      onLongPress: enabled ? _onLongPress : null,
      child: AnimatedBuilder(
        animation: _swing,
        builder: (context, child) => Transform.rotate(angle: _angle, child: child),
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// What a swipe-left reveals behind a card: red, with a trash icon at the
/// right edge.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      decoration: BoxDecoration(
        color: AppColors.endRed,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: AppColors.white, size: 26),
          const SizedBox(height: 4),
          Text('Delete', style: AppText.button.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Worn-vs-planned bar: blue fill = worn/72, with a red overflow cap when the
/// pod was worn too long.
class _HistoryBar extends StatelessWidget {
  const _HistoryBar({required this.record});

  final SessionRecord record;

  @override
  Widget build(BuildContext context) {
    final tooLong = record.outcome == HistoryOutcome.wornTooLong;
    final fraction =
        (record.worn.inMinutes / record.planned.inMinutes).clamp(0.0, 1.0);
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final fillW = fraction <= 0 ? 0.0 : (w * fraction).clamp(8.0, w);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: fillW,
                decoration: BoxDecoration(
                  color: AppColors.progressFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (tooLong)
                Positioned(
                  right: 0,
                  child: Container(
                    width: w * 0.07,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.endRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
