import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// How far back the date field's calendar opens by default.
const int _maxDaysBack = 30;

/// Opens the date/time picker over the calling sheet. Returns the chosen
/// [DateTime] (minute precision), or null if cancelled.
///
/// The date half is Material 3's modal date picker ([showDatePicker]) opened
/// from the field at the top; the time half is the app's own wheels (Figma
/// node `281:164`). Reused for "Start time" (Add Pod), "End time" (End Pod)
/// and editing the running pod's start from Home — the wording is driven by
/// [title], [subtitle], [confirmLabel] and the [footnote] builder.
Future<DateTime?> showStartTimePicker(
  BuildContext context, {
  required DateTime initial,
  required String Function(DateTime selected) footnote,
  String title = 'Start time',
  String subtitle = 'When did you apply this pod?',
  String confirmLabel = 'Set start time',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _StartTimePickerSheet(
      initial: initial,
      footnote: footnote,
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
    ),
  );
}

class _StartTimePickerSheet extends StatefulWidget {
  const _StartTimePickerSheet({
    required this.initial,
    required this.footnote,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  final DateTime initial;
  final String Function(DateTime selected) footnote;
  final String title;
  final String subtitle;
  final String confirmLabel;

  @override
  State<_StartTimePickerSheet> createState() => _StartTimePickerSheetState();
}

class _StartTimePickerSheetState extends State<_StartTimePickerSheet> {
  late final DateTime _today;
  late DateTime _date; // date part only
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourCtl;
  late final FixedExtentScrollController _minuteCtl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final i = widget.initial;
    _date = DateTime(i.year, i.month, i.day);
    _hour = i.hour;
    _minute = i.minute;
    _hourCtl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtl.dispose();
    _minuteCtl.dispose();
    super.dispose();
  }

  DateTime get _selected =>
      DateTime(_date.year, _date.month, _date.day, _hour, _minute);

  /// Material 3's modal date picker, over this sheet. Only the day is taken
  /// from it — the time keeps coming from the wheels below, so a pick never
  /// silently resets the hour and minute the user already set.
  ///
  /// The window is the last [_maxDaysBack] days up to today, widened when
  /// needed to include the value the sheet opened on: a pod worn far past its
  /// grace window can have started before that window, and [showDatePicker]
  /// requires its initial date to be inside the range.
  Future<void> _pickDate() async {
    final earliest = _today.subtract(const Duration(days: _maxDaysBack));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(earliest) ? _date : earliest,
      lastDate: _date.isAfter(_today) ? _date : _today,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x2E052646), // navy @ ~0.18
                blurRadius: 28,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.slate.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _header(),
                  const SizedBox(height: 20),
                  _dateField(),
                  const SizedBox(height: 18),
                  _timeWheels(),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      widget.footnote(_selected),
                      style: AppText.caption.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _primaryButton(),
                  const SizedBox(height: 6),
                  _cancelButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: AppText.sheetTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: AppText.sheetSubtitle),
            ],
          ),
        ),
        Pressable(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Pressable(
      onTap: _pickDate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.slate),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fmtDateStepper(_date, _today),
                style: AppText.statValue.copyWith(fontSize: 15),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.slate),
          ],
        ),
      ),
    );
  }

  Widget _timeWheels() {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center selection pill.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.cyanBg,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _WheelColumn(
                  controller: _hourCtl,
                  count: 24,
                  onChanged: (i) => setState(() => _hour = i),
                ),
              ),
              Text(':', style: AppText.bigTime.copyWith(fontSize: 26)),
              Expanded(
                child: _WheelColumn(
                  controller: _minuteCtl,
                  count: 60,
                  onChanged: (i) => setState(() => _minute = i),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryButton() {
    return Pressable(
      onTap: () => Navigator.of(context).pop(_selected),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(widget.confirmLabel, style: AppText.button.copyWith(fontSize: 16)),
      ),
    );
  }

  Widget _cancelButton() {
    return Pressable(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Text(
          'Cancel',
          style: AppText.rowTitle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A flat scroll wheel of zero-padded numbers (0..count-1) with the centered
/// value emphasised and neighbours faded, matching the Figma time picker.
class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.count,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 60,
      physics: const FixedExtentScrollPhysics(),
      perspective: 0.0001,
      diameterRatio: 100,
      useMagnifier: true,
      magnification: 1.36,
      overAndUnderCenterOpacity: 0.4,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => Center(
          child: Text(
            index.toString().padLeft(2, '0'),
            style: AppText.statValue.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
