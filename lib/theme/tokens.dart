import 'package:flutter/material.dart';

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
///
/// Poppins is bundled locally (see `pubspec.yaml` / `assets/fonts`) rather
/// than fetched at runtime via the `google_fonts` package, so the app's own
/// text never depends on a network call. Styles are `static final` (computed
/// once) rather than `static TextStyle get` — each is read dozens of times
/// per build, and a getter would rebuild the TextStyle on every read.
abstract final class AppText {
  static const String _family = 'Poppins';

  static const TextStyle appTitle =
      TextStyle(fontFamily: _family, fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy);
  static const TextStyle bigTime = TextStyle(
      fontFamily: _family, fontSize: 52, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.0);
  static const TextStyle cardDate =
      TextStyle(fontFamily: _family, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navy);
  static const TextStyle eyebrow = TextStyle(
      fontFamily: _family, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate, letterSpacing: 0.8);
  static const TextStyle caption =
      TextStyle(fontFamily: _family, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate);
  static const TextStyle statLabel = TextStyle(
      fontFamily: _family, fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate, letterSpacing: 0.6);
  static const TextStyle statValue =
      TextStyle(fontFamily: _family, fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy);
  static const TextStyle rowTitle =
      TextStyle(fontFamily: _family, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate);
  static const TextStyle rowValue =
      TextStyle(fontFamily: _family, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navy);
  static const TextStyle button =
      TextStyle(fontFamily: _family, fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white);
  static const TextStyle emptyTitle =
      TextStyle(fontFamily: _family, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.navy);
  static const TextStyle emptySub =
      TextStyle(fontFamily: _family, fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.slate);
  static const TextStyle badge =
      TextStyle(fontFamily: _family, fontSize: 12.5, fontWeight: FontWeight.w600);
  static const TextStyle statusLabel =
      TextStyle(fontFamily: _family, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.4);

  // Add Pod sheet -----------------------------------------------------------
  static const TextStyle sheetTitle =
      TextStyle(fontFamily: _family, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy);
  static const TextStyle sheetSubtitle =
      TextStyle(fontFamily: _family, fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.slate);
  static const TextStyle chipLabel =
      TextStyle(fontFamily: _family, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate);
  static const TextStyle chipLabelSelected =
      TextStyle(fontFamily: _family, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy);
  static const TextStyle segLabel =
      TextStyle(fontFamily: _family, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate);
  static const TextStyle segLabelSelected =
      TextStyle(fontFamily: _family, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy);
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

/// App-wide date/time display preferences, mirrored from `PodController`
/// settings so the pure `fmt*` helpers can honor the user's choices without
/// threading a formatter through every call site. `PodController` keeps these
/// in sync (on load, on change, on reset); UI reads them during build.
class AppFormats {
  AppFormats._();

  /// `true` → 24-hour clock ("20:17"); `false` → 12-hour ("8:17 PM").
  static bool use24Hour = true;

  /// One of 'DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD' — controls [fmtDate].
  static String dateStyle = 'DD/MM/YYYY';
}

/// "20:17" (24-hour) or "8:17 PM" (12-hour), per [AppFormats.use24Hour].
String fmtClock(DateTime d) {
  if (AppFormats.use24Hour) return '${_two(d.hour)}:${_two(d.minute)}';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  return '$h12:${_two(d.minute)} $suffix';
}

/// "Tuesday, June 3, 2026"
String fmtFullDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_monthsFull[d.month - 1]} ${d.day}, ${d.year}';

/// "May 31, 20:17"
String fmtShortStamp(DateTime d) => '${_monthsShort[d.month - 1]} ${d.day}, ${fmtClock(d)}';

/// Numeric full date in the user's chosen order + separator
/// ([AppFormats.dateStyle]): the order is read from whether the pattern starts
/// with YYYY or MM (else day-first), and the separator ('/', '-' or '.') is
/// taken from the pattern itself — so "21/06/2026", "2026-06-21", "21.06.2026"
/// and "06.21.2026" all work.
String fmtDate(DateTime d) {
  final dd = _two(d.day);
  final mm = _two(d.month);
  final yyyy = d.year.toString();
  final f = AppFormats.dateStyle;
  final sep = f.contains('.') ? '.' : (f.contains('-') ? '-' : '/');
  if (f.startsWith('YYYY')) return '$yyyy$sep$mm$sep$dd';
  if (f.startsWith('MM')) return '$mm$sep$dd$sep$yyyy';
  return '$dd$sep$mm$sep$yyyy';
}

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
