import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// A bottom-sheet number editor in the same floating-card style as
/// [showOptionPickerSheet]: − / + steppers around a typed field, with the
/// [unit] beside the number, and a Done button. Used for editing a past
/// session's PLANNED hours and REMINDERS count. Returns the chosen value,
/// clamped to [min]..[max], or null if dismissed.
Future<int?> showNumberEditSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required int initial,
  required String unit,
  int min = 0,
  int max = 999,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _NumberEditSheet(
      title: title,
      subtitle: subtitle,
      initial: initial,
      unit: unit,
      min: min,
      max: max,
    ),
  );
}

class _NumberEditSheet extends StatefulWidget {
  const _NumberEditSheet({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.unit,
    required this.min,
    required this.max,
  });

  final String title;
  final String? subtitle;
  final int initial;
  final String unit;
  final int min;
  final int max;

  @override
  State<_NumberEditSheet> createState() => _NumberEditSheetState();
}

class _NumberEditSheetState extends State<_NumberEditSheet> {
  late final TextEditingController _text =
      TextEditingController(text: '${widget.initial.clamp(widget.min, widget.max)}');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// What the field holds, clamped; an empty or unreadable field counts as
  /// the starting value.
  int get _value =>
      (int.tryParse(_text.text.trim()) ?? widget.initial).clamp(widget.min, widget.max);

  void _step(int delta) {
    final next = (_value + delta).clamp(widget.min, widget.max);
    setState(() => _text.text = '$next');
  }

  void _done() => Navigator.of(context).pop(_value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        top: 14,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCD9E5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _header(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _stepButton(Icons.remove_rounded, _value > widget.min ? () => _step(-1) : null),
                    const SizedBox(width: 12),
                    Expanded(child: _field()),
                    const SizedBox(width: 12),
                    _stepButton(Icons.add_rounded, _value < widget.max ? () => _step(1) : null),
                  ],
                ),
                const SizedBox(height: 20),
                Pressable(
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
              Text(widget.title, style: AppText.sheetTitle),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.subtitle!, style: AppText.sheetSubtitle),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Pressable(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
          ),
        ),
      ],
    );
  }

  Widget _field() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: AppText.rowValue.copyWith(fontSize: 18),
              onChanged: (_) => setState(() {}), // keep the steppers' limits current
              onSubmitted: (_) => _done(),
              decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
            ),
          ),
          Text(widget.unit, style: AppText.rowTitle),
        ],
      ),
    );
  }

  /// A 52×52 − / + button; [onTap] null greys it out at the limit.
  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return Pressable(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap == null ? AppColors.chipBorder : AppColors.navy,
        ),
      ),
    );
  }
}
