import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pod Tracker brand palette, converted from the Figma design tokens
/// (original 0–1 RGB values noted alongside each color).
abstract final class AppColors {
  static const Color navy = Color(0xFF052646); // {0.0196, 0.149, 0.2745}
  static const Color slate = Color(0xFF5B7185); // {0.357, 0.443, 0.522}
  static const Color background = Color(0xFFF8F9FF); // {0.973, 0.976, 1}
  static const Color white = Colors.white;

  static const Color blue = Color(0xFF33658A); // primary button {0.2, 0.396, 0.541}
  static const Color cyan = Color(0xFF86BBD8); // accent / borders {0.525, 0.733, 0.847}
  static const Color cyanBg = Color(0xFFE2F6FF); // card surfaces {0.886, 0.965, 1}

  static const Color green = Color(0xFF21A86B); // on track {0.13, 0.66, 0.42}
  static const Color amberText = Color(0xFFC7730A); // grace {0.78, 0.45, 0.04}
  static const Color amberBg = Color(0xFFFFEDC9); // {1, 0.93, 0.79}
  static const Color redText = Color(0xFFC91F2E); // late / stopped {0.79, 0.12, 0.18}
  static const Color redBg = Color(0xFFFCE3E6); // {0.99, 0.89, 0.90}
  static const Color endRed = Color(0xFFE63946); // End Pod confirm button

  static const Color progressTrack = Color(0xFFD9F6FF); // worn-bar track
  static const Color progressFill = Color(0xFF68C6EA); // worn-bar fill

  static const Color stockGreenText = Color(0xFF08805C); // restock delta / value
  static const Color stockGreenBg = Color(0xFFD9F5EB); // positive delta chip bg
  static const Color cardBorder = Color(0x7386BBD8); // cyan @ 45% — card outline

  static const Color divider = Color(0xFFE6EEF5);
  static const Color chipBorder = Color(0xFFE0E8F0); // unselected chip outline
  static const Color surfaceAlt = Color(0xFFF2F6FB); // segmented track / close button
  static const Color surfaceAlt2 = Color(0xFFEDF2F7); // date stepper / picker close
}

/// Poppins text styles used across the Home page.
abstract final class AppText {
  static TextStyle get appTitle =>
      GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy);
  static TextStyle get bigTime => GoogleFonts.poppins(
      fontSize: 52, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.0);
  static TextStyle get cardDate =>
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navy);
  static TextStyle get eyebrow => GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate, letterSpacing: 0.8);
  static TextStyle get caption =>
      GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate);
  static TextStyle get statLabel => GoogleFonts.poppins(
      fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate, letterSpacing: 0.6);
  static TextStyle get statValue =>
      GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy);
  static TextStyle get rowTitle =>
      GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate);
  static TextStyle get rowValue =>
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navy);
  static TextStyle get button =>
      GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle get emptyTitle =>
      GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.navy);
  static TextStyle get emptySub =>
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.slate);
  static TextStyle get badge => GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600);
  static TextStyle get statusLabel =>
      GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.4);

  // Add Pod sheet -----------------------------------------------------------
  static TextStyle get sheetTitle =>
      GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy);
  static TextStyle get sheetSubtitle =>
      GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.slate);
  static TextStyle get chipLabel =>
      GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate);
  static TextStyle get chipLabelSelected =>
      GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy);
  static TextStyle get segLabel =>
      GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate);
  static TextStyle get segLabelSelected =>
      GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy);
}

// ---------------------------------------------------------------------------
// Lightweight date / duration formatting (no intl dependency).
// ---------------------------------------------------------------------------

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _monthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const List<String> _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const List<String> _weekdaysShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "20:17"
String fmtClock(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Tuesday, June 3, 2026"
String fmtFullDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_monthsFull[d.month - 1]} ${d.day}, ${d.year}';

/// "May 31, 20:17"
String fmtShortStamp(DateTime d) => '${_monthsShort[d.month - 1]} ${d.day}, ${fmtClock(d)}';

/// "Jun 21, 2026"
String fmtDate(DateTime d) => '${_monthsShort[d.month - 1]} ${d.day}, ${d.year}';

/// "71h 58m"
String fmtHm(Duration d) => '${d.inHours}h ${d.inMinutes % 60}m';

/// "1m 43s"
String fmtMs(Duration d) => '${d.inMinutes}m ${d.inSeconds % 60}s';

/// "71h 58m" when ≥ 1h, otherwise "1m 43s".
String fmtAuto(Duration d) => d.inHours > 0 ? fmtHm(d) : fmtMs(d);

/// "Jun 11 · 14:30"
String fmtExpiry(DateTime d) => '${_monthsShort[d.month - 1]} ${d.day} · ${fmtClock(d)}';

/// "Wed, Jun 11"
String fmtWeekdayDate(DateTime d) =>
    '${_weekdaysShort[d.weekday - 1]}, ${_monthsShort[d.month - 1]} ${d.day}';

/// "Starts today at 14:30" (same day) or "Starts Wed, Jun 11 at 14:30".
String fmtStartsAt(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
  return sameDay
      ? 'Starts today at ${fmtClock(d)}'
      : 'Starts ${fmtWeekdayDate(d)} at ${fmtClock(d)}';
}

/// "Ends today at 15:32" (same day) or "Ends Wed, Jun 11 at 15:32".
String fmtEndsAt(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
  return sameDay
      ? 'Ends today at ${fmtClock(d)}'
      : 'Ends ${fmtWeekdayDate(d)} at ${fmtClock(d)}';
}

/// "Jun 26"
String fmtMonthDay(DateTime d) => '${_monthsShort[d.month - 1]} ${d.day}';

/// "JUNE 2026" — Stock History month-group header.
String fmtMonthYearUpper(DateTime d) =>
    '${_monthsFull[d.month - 1].toUpperCase()} ${d.year}';

/// Activity timestamp: "today 14:30" / "yesterday" / "Jun 26".
String fmtActivityTime(DateTime at, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final a = DateTime(at.year, at.month, at.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = a.difference(today).inDays;
  if (diff == 0) return 'today ${fmtClock(at)}';
  if (diff == -1) return 'yesterday';
  return fmtMonthDay(at);
}

/// Date-stepper label: "Today · Wed, Jun 11" / "Yesterday · …" / "Tomorrow · …"
/// or just "Wed, Jun 11" beyond ±1 day.
String fmtDateStepper(DateTime sel, DateTime now) {
  final s = DateTime(sel.year, sel.month, sel.day);
  final t = DateTime(now.year, now.month, now.day);
  final diff = s.difference(t).inDays;
  final wd = fmtWeekdayDate(sel);
  return switch (diff) {
    0 => 'Today · $wd',
    -1 => 'Yesterday · $wd',
    1 => 'Tomorrow · $wd',
    _ => wd,
  };
}
