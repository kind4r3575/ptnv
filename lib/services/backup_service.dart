import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/pod.dart';

/// A parsed, not-yet-applied backup file — enough to show the user what
/// they're about to restore before [PodController.restoreFromBackupJson]
/// overwrites their current data.
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
/// sync through: back up before switching phones or reinstalling, restore
/// after.
class BackupService {
  BackupService._();

  /// Bumped only if the backup shape changes in a way older app versions
  /// can't read. [pickBackup] refuses to restore a newer schema than this.
  static const int schemaVersion = 1;

  // --- Export -----------------------------------------------------------

  static Future<void> exportBackup(PodController controller) async {
    final info = await PackageInfo.fromPlatform();
    final now = DateTime.now();
    final doc = {
      'app': 'Pod Tracker',
      'schemaVersion': schemaVersion,
      'appVersion': info.version,
      'exportedAt': now.toIso8601String(),
      'data': controller.toBackupJson(),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(doc)));
    final name = 'pod-tracker-backup-${_fileStamp(now)}.json';
    final file = await _writeTemp(name, bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: 'Pod Tracker — backup',
    ));
  }

  // --- Restore ------------------------------------------------------------

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

    final Map<String, dynamic> doc;
    try {
      doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException("That doesn't look like a Pod Tracker backup file.");
    }

    final version = doc['schemaVersion'];
    if (version is! int || version > schemaVersion) {
      throw const FormatException(
          'This backup was made with a newer version of Pod Tracker and '
          "can't be restored here.");
    }

    final data = doc['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException("That doesn't look like a Pod Tracker backup file.");
    }

    final history = data['history'];
    final activity = data['activity'];
    return ParsedBackup(
      data: data,
      exportedAt: DateTime.tryParse(doc['exportedAt'] as String? ?? ''),
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
