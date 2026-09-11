import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../state/pod.dart';
import '../theme/tokens.dart' show fmtClock, fmtDate, fmtHm;

/// Turns [PodController.history] into a CSV or PDF file and hands it to the
/// platform share sheet — so a session log can be saved, emailed, or handed
/// to a clinician without the app needing a backend, an account, or storage
/// permissions.
///
/// CSV values are ISO-formatted and numeric (portable, spreadsheet-friendly);
/// the PDF renders the same rows in the user's own date/time/duration display
/// conventions (see `theme/tokens.dart`), since one is for machines and the
/// other for people.
class ExportService {
  ExportService._();

  static const List<String> _columns = [
    'Started', 'Ended', 'Outcome', 'Worn', 'Planned', 'Site', 'Why changed',
  ];

  // --- CSV --------------------------------------------------------------

  static Future<void> exportCsv(List<SessionRecord> history) async {
    final rows = history.reversed; // oldest first, like a timeline
    final buffer = StringBuffer('﻿'); // BOM so Excel detects UTF-8
    buffer.write(_csvRow(_columns));
    for (final r in rows) {
      buffer.write(_csvRow([
        _isoStamp(r.started),
        _isoStamp(r.ended),
        _outcomeLabel(r.outcome),
        (r.worn.inMinutes / 60).toStringAsFixed(2),
        r.plannedHours.toString(),
        r.placedOn,
        r.whyChanged,
      ]));
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final name = 'pod-tracker-history-${_fileStamp(DateTime.now())}.csv';
    final file = await _writeTemp(name, bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv', name: name)],
      fileNameOverrides: [name],
      subject: 'Pod Tracker — session history (CSV)',
    ));
  }

  static String _csvRow(List<String> values) => '${values.map(_csvField).join(',')}\r\n';

  static String _csvField(String value) {
    final needsQuoting =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// "2026-09-05 21:33" — unambiguous and sorts correctly regardless of the
  /// reader's locale, unlike the user's chosen display date format.
  static String _isoStamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  // --- PDF ----------------------------------------------------------------

  static Future<void> exportPdf(List<SessionRecord> history) async {
    final rows = history.reversed.toList();
    final now = DateTime.now();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 28),
        header: (context) =>
            context.pageNumber == 1 ? _pdfHeader(now, rows.length) : pw.SizedBox(),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: _columns,
            data: [for (final r in rows) _pdfRow(r)],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellAlignments: const {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'pod-tracker-history-${_fileStamp(now)}.pdf',
    );
  }

  static pw.Widget _pdfHeader(DateTime generatedAt, int count) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Pod Tracker — Session History',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated ${_isoStamp(generatedAt)} · $count session${count == 1 ? '' : 's'}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
      );

  static List<String> _pdfRow(SessionRecord r) => [
        '${fmtDate(r.started)} ${fmtClock(r.started)}',
        '${fmtDate(r.ended)} ${fmtClock(r.ended)}',
        _outcomeLabel(r.outcome),
        fmtHm(r.worn),
        '${r.plannedHours}h',
        r.placedOn,
        r.whyChanged,
      ];

  // --- Shared ---------------------------------------------------------------

  static String _outcomeLabel(HistoryOutcome o) => switch (o) {
        HistoryOutcome.completed => 'Completed',
        HistoryOutcome.endedEarly => 'Ended early',
        HistoryOutcome.wornTooLong => 'Worn too long',
      };

  static String _fileStamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static Future<File> _writeTemp(String filename, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsBytes(bytes, flush: true);
  }
}
