import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// How far back the "Custom" start time may be set.
const int _maxDaysBack = 30;

/// Opens the time picker (Figma node `281:164`) over the calling sheet. Returns
/// the chosen [DateTime] (minute precision), or null if cancelled.
///
/// Reused for both "Start time" (Add Pod) and "End time" (End Pod) — the wording
/// is driven by [title], [subtitle], [confirmLabel] and the [footnote] builder.
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

  bool get _canForward => _date.isBefore(_today);
  bool get _canBack =>
      _date.isAfter(_today.subtract(const Duration(days: _maxDaysBack)));

  void _stepDay(int delta) {
    final next = _date.add(Duration(days: delta));
    if (next.isAfter(_today)) return;
    if (next.isBefore(_today.subtract(const Duration(days: _maxDaysBack)))) return;
    setState(() => _date = next);
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
                  _dateStepper(),
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
        GestureDetector(
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

  Widget _dateStepper() {
    Widget arrow(IconData icon, {required bool enabled, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 48,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? AppColors.slate : AppColors.slate.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, enabled: _canBack, onTap: () => _stepDay(-1)),
          Expanded(
            child: Center(
              child: Text(
                fmtDateStepper(_date, _today),
                style: AppText.statValue.copyWith(fontSize: 15),
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, enabled: _canForward, onTap: () => _stepDay(1)),
        ],
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
    return GestureDetector(
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
    return GestureDetector(
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
