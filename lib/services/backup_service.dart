import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/pod.dart';

/// A parsed, not-yet-applied backup file — enough to show the user what
/// they're about to import before [PodController.restoreFromBackupJson] or
/// [PodController.mergeFromBackupJson] changes their current data.
class ParsedBackup {
  const ParsedBackup({
    required this.data,
    required this.exportedAt,
    required this.historyCount,
    required this.activityCount,
  });

  final Map<String, dynamic> data;
  final DateTime? exportedAt;
  final int historyCount;
  final int activityCount;
}

/// Reads and writes the full app state — everything [PodController] persists,
/// not just session history — as one portable JSON file. This is Pod
/// Tracker's manual stand-in for cloud sync, since the app has no backend to
/// sync through: export before switching phones or reinstalling, import
/// after. The file is plain JSON, so it moves between Android and iPhone.
///
/// A backup arrives in one of two ways: picked in Settings → Import Data
/// ([pickBackup]), or opened from another app — a messenger, email, Files —
/// via "Open with Pod Tracker" (see `IncomingFileService`). Both end in
/// [parse].
class BackupService {
  BackupService._();

  /// Bumped only if the backup shape changes in a way older app versions
  /// can't read. [parse] refuses to import a newer schema than this.
  static const int schemaVersion = 1;

  static const String _mimeType = 'application/json';

  // --- Export -----------------------------------------------------------

  /// Hands the backup file to the platform share sheet — to send it to the
  /// new phone (messenger, email, Quick Share, AirDrop, Drive…).
  static Future<void> shareBackup(PodController controller) async {
    final (:name, :bytes) = await _buildBackup(controller);
    final file = await _writeTemp(name, bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: _mimeType, name: name)],
      fileNameOverrides: [name],
      subject: 'Pod Tracker — all data',
    ));
  }

  /// Opens the system "save as" dialog (e.g. Downloads, or Files on iPhone),
  /// so the backup outlives an uninstall/reinstall of the app. Returns
  /// `false` if the user cancelled the dialog.
  static Future<bool> saveBackupToDevice(PodController controller) async {
    final (:name, :bytes) = await _buildBackup(controller);
    final saved = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: _mimeType,
      dialogTitle: 'Save Pod Tracker data',
    );
    return saved != null;
  }

  static Future<({String name, Uint8List bytes})> _buildBackup(
      PodController controller) async {
    final info = await PackageInfo.fromPlatform();
    final now = DateTime.now();
    final doc = {
      'app': 'Pod Tracker',
      'schemaVersion': schemaVersion,
      'appVersion': info.version,
      'exportedAt': now.toIso8601String(),
      'data': controller.toBackupJson(),
    };
    return (
      name: 'pod-tracker-backup-${_fileStamp(now)}.json',
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(doc))),
    );
  }

  // --- Import -------------------------------------------------------------

  /// Opens the system file picker for a `.json` backup and validates it.
  /// Returns `null` if the user cancels the picker. Throws a
  /// [FormatException], with a message safe to show the user directly, if
  /// the file isn't a Pod Tracker backup this app version can read.
  static Future<ParsedBackup?> pickBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return null; // user cancelled

    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      throw const FormatException("Couldn't read that file.");
    }
    return parse(bytes);
  }

  /// Validates raw file [bytes] as a Pod Tracker backup. Throws a
  /// [FormatException] with a user-facing message if it isn't one this app
  /// version can read.
  static ParsedBackup parse(Uint8List bytes) {
    const notABackup = FormatException("That doesn't look like a Pod Tracker backup file.");

    final Map<String, dynamic> doc;
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('﻿')) text = text.substring(1); // BOM added by some editors
      doc = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw notABackup;
    }

    final version = doc['schemaVersion'];
    if (version is! int) throw notABackup;
    if (version > schemaVersion) {
      throw const FormatException(
          'This backup was made with a newer version of Pod Tracker. Update the app '
          'on this phone, then try again.');
    }

    final data = doc['data'];
    if (data is! Map<String, dynamic>) throw notABackup;

    final history = data['history'];
    final activity = data['activity'];
    final exportedAt = doc['exportedAt'];
    return ParsedBackup(
      data: data,
      exportedAt: exportedAt is String ? DateTime.tryParse(exportedAt) : null,
      historyCount: history is List ? history.length : 0,
      activityCount: activity is List ? activity.length : 0,
    );
  }

  // --- Shared ---------------------------------------------------------------

  static Future<File> _writeTemp(String filename, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsBytes(bytes, flush: true);
  }

  static String _fileStamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
