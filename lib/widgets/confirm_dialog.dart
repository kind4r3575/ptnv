import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A centered confirmation dialog in the app's card style — used for
/// destructive / reset actions (Clear History, Reset to Defaults). Returns
/// `true` if the user confirmed, `false`/`null` if they cancelled or dismissed.
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.sheetTitle),
            const SizedBox(height: 8),
            Text(message, style: AppText.sheetSubtitle),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _button(
                    label: cancelLabel,
                    bg: AppColors.surfaceAlt,
                    fg: AppColors.slate,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _button(
                    label: confirmLabel,
                    bg: destructive ? AppColors.endRed : AppColors.blue,
                    fg: AppColors.white,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: AppText.button.copyWith(fontSize: 15, color: fg)),
      ),
    );
  }
}
