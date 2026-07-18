import '../../../core/utils/date_x.dart';
import 'awoken_import_parser.dart';

/// Renders journal entries into the Awoken plain-text export grammar, so
/// files produced by Oneiro stay interchangeable with files produced by the
/// old tool (and with [AwokenImportParser]).
///
/// Only the title line names the producing app ("ONEIRO"); the entry grammar
/// — `----` separators, `Date:` / `Lucidity:` / `Dream:` labels, blank-line
/// layout — is identical, and the round-trip property holds:
/// `AwokenImportParser().parse(export(entries))` equals the input entries
/// (for bodies without leading/trailing blank lines).
class AwokenExporter {
  const AwokenExporter();

  /// Title line naming Oneiro as the producer.
  static const String titleLine =
      'DREAMS FROM THE LUCID DREAMING TOOL - ONEIRO';

  /// Project link line, keeping the header layout format-compatible.
  static const String linkLine =
      'link: https://github.com/oneiro-dream-journal/oneiro';

  static const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `Mon 18 May 2026` — weekday plus zero-padded day, English month name.
  /// September renders as `Sep`; the parser also accepts `Sept`.
  static String formatAwokenDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    return '${_weekdayNames[date.weekday - 1]} $day '
        '${_monthNames[date.month - 1]} ${date.year}';
  }

  /// Exports [entries] (already sorted as desired) into the shared grammar.
  ///
  /// Dates are normalized to calendar days and the weekday is recomputed
  /// from the date, so it always matches. LF line endings; the file ends
  /// with the last body followed by a blank line.
  String export(Iterable<AwokenImportedEntry> entries) {
    final buffer = StringBuffer()
      ..writeln(titleLine)
      ..writeln()
      ..writeln(linkLine)
      ..writeln();

    for (final entry in entries) {
      final day = entry.date.startOfDay;
      buffer
        ..writeln()
        ..writeln('----')
        ..writeln()
        ..writeln('Date: ${formatAwokenDate(day)}')
        ..writeln()
        ..writeln('Lucidity: ${entry.isLucid ? 'Yes' : 'No'}')
        ..writeln()
        ..writeln('Dream:')
        ..writeln(entry.body)
        ..writeln();
    }

    return buffer.toString();
  }
}
