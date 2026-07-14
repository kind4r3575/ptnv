import 'package:flutter/material.dart';

import '../state/notification_rule.dart';
import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_switch.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/home_parts.dart';
import '../widgets/sheet_parts.dart';

/// Full-screen editor for a single [NotificationRule]. Reached by tapping a rule
/// in the Notifications list, or "＋ Add notification" (with [rule] == null).
class NotificationEditScreen extends StatefulWidget {
  const NotificationEditScreen({super.key, required this.controller, this.rule});

  final PodController controller;

  /// The rule being edited, or null to create a new one.
  final NotificationRule? rule;

  @override
  State<NotificationEditScreen> createState() => _NotificationEditScreenState();
}

class _NotificationEditScreenState extends State<NotificationEditScreen> {
  /// Common "how long before" presets, in minutes.
  static const List<int> _offsetPresets = [15, 30, 60, 120, 360, 720, 1440, 2880];

  late NotificationRule _draft;
  bool get _isNew => widget.rule == null;

  @override
  void initState() {
    super.initState();
    _draft = widget.rule?.copyWith() ??
        NotificationRule.create(NotificationTrigger.podExpiry);
  }

  void _save() {
    widget.controller.updateRule(_draft); // add-or-replace by id
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete notification?',
      message: 'This reminder will be removed and no longer fire.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok == true && mounted) {
      widget.controller.removeRule(_draft.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBarWave(
              title: _isNew ? 'New notification' : 'Edit notification',
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                splashRadius: 22,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _card(child: _situationBlock()),
                  const SizedBox(height: 14),
                  _card(child: _timingBlock()),
                  const SizedBox(height: 14),
                  _card(child: _enabledRow()),
                  const SizedBox(height: 24),
                  _saveButton(),
                  if (!_isNew) ...[
                    const SizedBox(height: 10),
                    _deleteButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sections --------------------------------------------------------------

  Widget _situationBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SITUATION', style: AppText.eyebrow),
        const SizedBox(height: 4),
        Text('When should this notification fire?', style: AppText.sheetSubtitle),
        const SizedBox(height: 12),
        for (final t in NotificationTrigger.values) _situationTile(t),
      ],
    );
  }

  Widget _situationTile(NotificationTrigger t) {
    final selected = _draft.trigger == t;
    return GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(trigger: t)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanBg : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.cyan : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(t.icon, size: 22, color: selected ? AppColors.blue : AppColors.slate),
            const SizedBox(width: 12),
            Expanded(child: Text(t.title, style: AppText.rowValue)),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.blue : AppColors.slate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timingBlock() {
    final t = _draft.trigger;
    if (t.usesOffset) return _offsetBlock();
    if (t == NotificationTrigger.dailyTime) return _timeOfDayBlock();
    if (t == NotificationTrigger.siteRotation) return _rotationBlock();
    return _lowStockBlock();
  }

  Widget _offsetBlock() {
    final label = _draft.trigger == NotificationTrigger.podOverdue
        ? 'HOW LONG AFTER'
        : 'HOW LONG BEFORE';
    final isCustom = !_offsetPresets.contains(_draft.offsetMinutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.eyebrow),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _offsetPresets)
              SizedBox(
                width: 74,
                child: SelectableChip(
                  label: fmtDuration(m).replaceAll(' minutes', 'm').replaceAll(' minute', 'm')
                      .replaceAll(' hours', 'h').replaceAll(' hour', 'h')
                      .replaceAll(' days', 'd').replaceAll(' day', 'd'),
                  selected: _draft.offsetMinutes == m,
                  onTap: () => setState(() => _draft = _draft.copyWith(offsetMinutes: m)),
                ),
              ),
            SizedBox(
              width: 90,
              child: SelectableChip(
                label: isCustom ? 'Custom ✎' : 'Custom',
                selected: isCustom,
                onTap: _pickCustomOffset,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_draft.summary, style: AppText.sheetSubtitle),
      ],
    );
  }

  Future<void> _pickCustomOffset() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.navy.withValues(alpha: 0.45),
      builder: (_) => _CustomOffsetSheet(initialMinutes: _draft.offsetMinutes),
    );
    if (picked != null) setState(() => _draft = _draft.copyWith(offsetMinutes: picked));
  }

  Widget _timeOfDayBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('TIME OF DAY', style: AppText.eyebrow),
        const SizedBox(height: 12),
        _timePickerRow(),
        const SizedBox(height: 12),
        Text(_draft.summary, style: AppText.sheetSubtitle),
      ],
    );
  }

  Widget _rotationBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EVERY N DAYS', style: AppText.eyebrow),
        const SizedBox(height: 12),
        _stepperRow(
          value: _draft.everyDays,
          unit: _draft.everyDays == 1 ? 'day' : 'days',
          onChanged: (v) => setState(() => _draft = _draft.copyWith(everyDays: v.clamp(1, 30))),
        ),
        const SizedBox(height: 16),
        Text('TIME OF DAY', style: AppText.eyebrow),
        const SizedBox(height: 12),
        _timePickerRow(),
        const SizedBox(height: 12),
        Text(_draft.summary, style: AppText.sheetSubtitle),
      ],
    );
  }

  Widget _lowStockBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WHEN IT FIRES', style: AppText.eyebrow),
        const SizedBox(height: 8),
        Text(
          'Fires immediately when your pods in stock drop to the Low Stock '
          'threshold set in Settings. No time to configure.',
          style: AppText.sheetSubtitle,
        ),
      ],
    );
  }

  Widget _timePickerRow() {
    final m = _draft.timeOfDayMinutes;
    final time = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) {
          setState(() => _draft =
              _draft.copyWith(timeOfDayMinutes: picked.hour * 60 + picked.minute));
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 20, color: AppColors.slate),
            const SizedBox(width: 10),
            Expanded(child: Text(time.format(context), style: AppText.rowValue.copyWith(fontSize: 18))),
            const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.slate),
          ],
        ),
      ),
    );
  }

  Widget _stepperRow({
    required int value,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    Widget btn(IconData icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cyanBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.blue, size: 22),
          ),
        );
    return Row(
      children: [
        btn(Icons.remove_rounded, () => onChanged(value - 1)),
        Expanded(
          child: Center(
            child: Text('$value $unit', style: AppText.rowValue.copyWith(fontSize: 18)),
          ),
        ),
        btn(Icons.add_rounded, () => onChanged(value + 1)),
      ],
    );
  }

  Widget _enabledRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enabled', style: AppText.rowValue),
              const SizedBox(height: 2),
              Text('Turn this notification on or off', style: AppText.sheetSubtitle),
            ],
          ),
        ),
        AppSwitch(
          value: _draft.enabled,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(enabled: v)),
        ),
      ],
    );
  }

  // --- Buttons / scaffolding -------------------------------------------------

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
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
        child: child,
      );

  Widget _saveButton() => GestureDetector(
        onTap: _save,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.35),
                blurRadius: 9,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(_isNew ? 'Add notification' : 'Save', style: AppText.button.copyWith(fontSize: 16)),
        ),
      );

  Widget _deleteButton() => GestureDetector(
        onTap: _delete,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            'Delete',
            style: AppText.button.copyWith(fontSize: 15, color: AppColors.endRed),
          ),
        ),
      );
}

/// Bottom sheet to enter a custom offset: a number + a minutes/hours/days unit.
class _CustomOffsetSheet extends StatefulWidget {
  const _CustomOffsetSheet({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_CustomOffsetSheet> createState() => _CustomOffsetSheetState();
}

class _CustomOffsetSheetState extends State<_CustomOffsetSheet> {
  // unit index: 0 = minutes, 1 = hours, 2 = days
  late int _unit;
  late final TextEditingController _controller;

  static const List<String> _units = ['Minutes', 'Hours', 'Days'];
  static const List<int> _factors = [1, 60, 1440];

  @override
  void initState() {
    super.initState();
    final m = widget.initialMinutes;
    if (m % 1440 == 0) {
      _unit = 2;
      _controller = TextEditingController(text: '${m ~/ 1440}');
    } else if (m % 60 == 0) {
      _unit = 1;
      _controller = TextEditingController(text: '${m ~/ 60}');
    } else {
      _unit = 0;
      _controller = TextEditingController(text: '$m');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final n = int.tryParse(_controller.text.trim()) ?? 0;
    final minutes = (n * _factors[_unit]).clamp(1, 60 * 24 * 30);
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Custom time', style: AppText.sheetTitle),
              const SizedBox(height: 4),
              Text('How far before the event should it fire?', style: AppText.sheetSubtitle),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppText.rowValue.copyWith(fontSize: 18),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < _units.length; i++)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _unit = i),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: _unit == i
                                      ? BoxDecoration(
                                          color: AppColors.white,
                                          borderRadius: BorderRadius.circular(9),
                                        )
                                      : null,
                                  child: Text(
                                    _units[i],
                                    style: AppText.rowTitle.copyWith(
                                      fontSize: 13,
                                      color: _unit == i ? AppColors.navy : AppColors.slate,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _done,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Done', style: AppText.button.copyWith(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
