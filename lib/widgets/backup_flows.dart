import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../state/pod.dart';
import '../theme/tokens.dart';
import 'confirm_dialog.dart';
import 'export_data_sheet.dart';

/// The user-facing export / import flows behind Settings → Data & Backup,
/// shared with "Open with Pod Tracker" (see `IncomingFileService`) so a
/// backup behaves the same however it reaches the app.

/// Settings → Export All Data: ask Send or Save, then do it.
Future<void> runExportFlow(BuildContext context, PodController c) async {
  final destination = await showExportDataSheet(context);
  if (destination == null || !context.mounted) return;
  try {
    switch (destination) {
      case ExportDestination.send:
        await BackupService.shareBackup(c);
      case ExportDestination.save:
        final saved = await BackupService.saveBackupToDevice(c);
        if (saved && context.mounted) _toast(context, 'Saved.');
    }
  } catch (_) {
    if (context.mounted) _toast(context, 'Export failed. Please try again.');
  }
}

/// Settings → Import Data: pick a backup file, then [_confirmAndImport].
Future<void> runImportFromPicker(BuildContext context, PodController c) async {
  final ParsedBackup? backup;
  try {
    backup = await BackupService.pickBackup();
  } catch (e) {
    if (context.mounted) _toast(context, _readError(e), long: true);
    return;
  }
  if (backup == null || !context.mounted) return; // user cancelled the picker
  await _confirmAndImport(context, c, backup);
}

/// A file opened in Pod Tracker from another app. [bytes] is null if the
/// platform couldn't read it.
Future<void> runImportFromBytes(BuildContext context, PodController c, Uint8List? bytes) async {
  final ParsedBackup backup;
  try {
    if (bytes == null) throw const FormatException("Couldn't read that file.");
    backup = BackupService.parse(bytes);
  } catch (e) {
    if (context.mounted) _toast(context, _readError(e), long: true);
    return;
  }
  await _confirmAndImport(context, c, backup);
}

enum _ImportMode { replace, merge }

/// On a phone with no records yet, a plain "Import?" confirm. On one that
/// already has history, activity or a pod in use, the user chooses Merge or
/// Replace everything (see [PodController.mergeFromBackupJson]).
Future<void> _confirmAndImport(BuildContext context, PodController c, ParsedBackup b) async {
  await c.loaded; // a cold launch via "Open with" can get here before saved data has loaded
  if (!context.mounted) return;

  final _ImportMode? mode;
  if (c.hasUserData) {
    mode = await showChoiceDialog<_ImportMode>(
      context: context,
      title: 'Import Data',
      message: 'This phone already has data. How should ${_describe(b)} be imported?',
      choices: const [
        DialogChoice(
          value: _ImportMode.merge,
          label: 'Merge',
          detail: "Keep this phone's history and add the backup's. "
              'Settings and reminders come from the backup.',
        ),
        DialogChoice(
          value: _ImportMode.replace,
          label: 'Replace everything',
          detail: 'This phone becomes an exact copy of the backup. '
              'Its current data is deleted.',
          destructive: true,
        ),
      ],
    );
  } else {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Import Data?',
      message: 'Set up Pod Tracker from ${_describe(b)} — stock, history, the pod in '
          'use, settings and reminders.',
      confirmLabel: 'Import',
    );
    mode = ok == true ? _ImportMode.replace : null;
  }
  if (mode == null) return;

  try {
    switch (mode) {
      case _ImportMode.replace:
        c.restoreFromBackupJson(b.data);
      case _ImportMode.merge:
        c.mergeFromBackupJson(b.data);
    }
    if (context.mounted) {
      _toast(context, mode == _ImportMode.merge ? 'Data merged.' : 'Data imported.');
    }
  } catch (_) {
    if (context.mounted) {
      _toast(context, "That backup file is damaged and couldn't be imported.", long: true);
    }
  }
}

String _describe(ParsedBackup b) {
  final when = b.exportedAt == null ? 'this backup' : 'the backup from ${fmtFullDate(b.exportedAt!)}';
  final sessions = '${b.historyCount} session${b.historyCount == 1 ? '' : 's'}';
  final activity = '${b.activityCount} stock ${b.activityCount == 1 ? 'entry' : 'entries'}';
  return '$when ($sessions, $activity)';
}

String _readError(Object e) => e is FormatException ? e.message : "Couldn't read that file.";

void _toast(BuildContext context, String message, {bool long = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: long ? const Duration(seconds: 3) : const Duration(milliseconds: 1500),
    ));
}
