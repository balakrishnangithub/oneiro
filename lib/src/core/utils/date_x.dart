import 'package:intl/intl.dart';

/// Day-granularity helpers for dream dates.
///
/// Dreams are recorded per calendar day, not per instant, so all
/// [DreamEntry]-facing code normalizes to local midnight before persisting.
extension DateX on DateTime {
  /// Local midnight at the start of this calendar day.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Milliseconds since the Unix epoch of [startOfDay].
  int get dayMillis => startOfDay.millisecondsSinceEpoch;

  /// Whether this date is the same calendar day as [other].
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

/// Header-style date format used across the journal, e.g. `Mon 18 May 2026`.
String formatDreamDate(DateTime date) =>
    DateFormat('EEE d MMM yyyy').format(date);

/// Longer, friendlier date format for the editor, e.g. `Monday 18 May 2026`.
String formatDreamDateLong(DateTime date) =>
    DateFormat('EEEE d MMM yyyy').format(date);
