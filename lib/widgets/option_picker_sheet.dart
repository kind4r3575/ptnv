import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A bottom-sheet single-choice picker (Figma node `294:287`). Slides up over a
/// scrim with a drag handle, a title/subtitle header and a circular close
/// button, then a list of options where the current one is highlighted with a
/// cyan fill and a check. Returns the chosen option, or null if dismissed.
///
/// Replaces the tap-to-cycle value rows in Settings — tapping a row opens this.
Future<T?> showOptionPickerSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<T> options,
  required T selected,
  required String Function(T value) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _OptionPickerSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      selected: selected,
      labelOf: labelOf,
    ),
  );
}

class _OptionPickerSheet<T> extends StatelessWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.labelOf,
  });

  final String title;
  final String? subtitle;
  final List<T> options;
  final T selected;
  final String Function(T value) labelOf;

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
                _header(context),
                const SizedBox(height: 12),
                for (final option in options)
                  _OptionRow(
                    label: labelOf(option),
                    selected: option == selected,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.sheetTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppText.sheetSubtitle),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
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
}

/// One selectable row. Highlighted (cyan fill + check) when it is the current
/// value, plain otherwise.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.rowValue.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 22, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}
