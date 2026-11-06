import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// Purpose-built confirmation for starting a pod while one is already active.
///
/// Instead of a paragraph the user has to read, it shows the swap visually:
/// the current pod (which ends now) above the new pod (which starts), so the
/// reason the dialog appeared is obvious at a glance. Returns `true` to replace.
Future<bool?> showReplacePodDialog({
  required BuildContext context,
  required String currentSite,
  required Duration currentWorn,
  required String newSite,
  required DateTime newStart,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _ReplacePodDialog(
      currentSite: currentSite,
      currentWorn: currentWorn,
      newSite: newSite,
      newStart: newStart,
    ),
  );
}

class _ReplacePodDialog extends StatelessWidget {
  const _ReplacePodDialog({
    required this.currentSite,
    required this.currentWorn,
    required this.newSite,
    required this.newStart,
  });

  final String currentSite;
  final Duration currentWorn;
  final String newSite;
  final DateTime newStart;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startsNow = newStart.difference(now).abs() < const Duration(minutes: 1);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
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
            // Swap icon — the one-glance "this replaces something" signal.
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.amberBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_vert_rounded,
                    size: 26, color: AppColors.amberText),
              ),
            ),
            const SizedBox(height: 14),
            Center(child: Text('Replace active pod?', style: AppText.sheetTitle)),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'You already have a pod running.',
                style: AppText.sheetSubtitle,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            // The swap, shown visually: current pod ends, new pod starts.
            _podRow(
              dot: AppColors.amberText,
              label: 'Now on · worn ${fmtHm(currentWorn)}',
              site: currentSite,
              trailing: 'Ends now',
              trailingColor: AppColors.redText,
            ),
            _arrow(),
            _podRow(
              dot: AppColors.blue,
              label: 'New pod',
              site: newSite,
              trailing: startsNow ? 'Starts now' : fmtClock(newStart),
              trailingColor: AppColors.blue,
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'The current pod is saved to your history — nothing is lost.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _button(
                    label: 'Keep current',
                    bg: AppColors.surfaceAlt,
                    fg: AppColors.slate,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _button(
                    label: 'Replace',
                    bg: AppColors.blue,
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

  Widget _podRow({
    required Color dot,
    required String label,
    required String site,
    required String trailing,
    required Color trailingColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.eyebrow),
                const SizedBox(height: 2),
                Text(
                  site,
                  style: AppText.rowValue.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: AppText.caption.copyWith(
              color: trailingColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Icon(Icons.arrow_downward_rounded, size: 18, color: AppColors.slate),
      );

  Widget _button({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Pressable(
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
    return Pressable(
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

/// One option in [showChoiceDialog].
class DialogChoice<T> {
  const DialogChoice({
    required this.value,
    required this.label,
    this.detail,
    this.destructive = false,
  });

  final T value;
  final String label;

  /// One line under [label] saying what the choice will do.
  final String? detail;

  /// Red label and outline, for a choice that deletes data.
  final bool destructive;
}

/// [showConfirmDialog]'s sibling for picking one of several actions: each
/// [choices] entry is a full-width tile with an explanation underneath, then
/// a Cancel button. Returns the chosen value, or `null` if the user cancelled
/// or dismissed the dialog.
Future<T?> showChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<DialogChoice<T>> choices,
  String cancelLabel = 'Cancel',
}) {
  return showDialog<T>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _ChoiceDialog<T>(
      title: title,
      message: message,
      choices: choices,
      cancelLabel: cancelLabel,
    ),
  );
}

class _ChoiceDialog<T> extends StatelessWidget {
  const _ChoiceDialog({
    required this.title,
    required this.message,
    required this.choices,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final List<DialogChoice<T>> choices;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.sheetTitle),
              const SizedBox(height: 8),
              Text(message, style: AppText.sheetSubtitle),
              const SizedBox(height: 18),
              for (final choice in choices) ...[
                _tile(context, choice),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              Pressable(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(cancelLabel,
                      style: AppText.button.copyWith(fontSize: 15, color: AppColors.slate)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, DialogChoice<T> choice) {
    final accent = choice.destructive ? AppColors.endRed : AppColors.blue;
    return Pressable(
      onTap: () => Navigator.of(context).pop(choice.value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: choice.destructive
                ? AppColors.endRed.withValues(alpha: 0.4)
                : AppColors.cardBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(choice.label,
                      style: AppText.rowValue
                          .copyWith(fontWeight: FontWeight.w600, color: accent)),
                  if (choice.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(choice.detail!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 22, color: accent),
          ],
        ),
      ),
    );
  }
}
