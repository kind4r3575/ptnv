import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// Where Settings → Export All Data sends the backup file.
enum ExportDestination {
  /// The platform share sheet — to get the file onto the new phone.
  send,

  /// The system "save as" dialog — a local copy that survives a reinstall.
  save,
}

/// The Export All Data sheet: same chrome as the option picker (drag handle,
/// title/subtitle, close button), with the two destinations as action rows.
/// Returns the chosen [ExportDestination], or null if dismissed.
Future<ExportDestination?> showExportDataSheet(BuildContext context) {
  return showModalBottomSheet<ExportDestination>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => const _ExportDataSheet(),
  );
}

class _ExportDataSheet extends StatelessWidget {
  const _ExportDataSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
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
          child: SafeArea(
            top: false,
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
                  const SizedBox(height: 16),
                  _ActionRow(
                    icon: Icons.send_rounded,
                    label: 'Send to another phone or app',
                    detail: 'Messenger, email, Quick Share, AirDrop, Drive…',
                    onTap: () => Navigator.of(context).pop(ExportDestination.send),
                  ),
                  const SizedBox(height: 10),
                  _ActionRow(
                    icon: Icons.download_rounded,
                    label: 'Save to this phone',
                    detail: 'Keep a copy in Downloads or Files — e.g. before reinstalling.',
                    onTap: () => Navigator.of(context).pop(ExportDestination.save),
                  ),
                ],
              ),
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
              Text('Export All Data', style: AppText.sheetTitle),
              const SizedBox(height: 4),
              Text(
                'One file with your stock, history, pod in use, settings and '
                'reminders. Open it with Pod Tracker on another phone to import it.',
                style: AppText.sheetSubtitle,
              ),
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
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.cyanBg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: AppColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.rowValue.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(detail, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.slate),
          ],
        ),
      ),
    );
  }
}
