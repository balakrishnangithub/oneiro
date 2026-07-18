/// Pure-Dart parser for the Awoken plain-text dream-journal export format.
///
/// The format is a simple line-based convention:
///
/// ```
/// DREAMS FROM THE LUCID DREAMING TOOL - <APP NAME>
/// <blank>
/// link: <url>
/// <blank>
/// <blank>
/// ----
/// <blank>
/// Date: Mon 18 May 2026
/// <blank>
/// Lucidity: No
/// <blank>
/// Dream:
/// <body: 1..n free-text lines>
/// <blank>
/// <blank>
/// ----
/// ...next entry...
/// ```
///
/// Entries are separated by a line of exactly four dashes (`----`), which
/// precedes every entry including the first. The parser is deliberately
/// liberal: the weekday in the `Date:` line is ignored (so a wrong weekday
/// never rejects an entry), September is accepted as `Sep`, `Sept` or
/// `September`, CRLF line endings are tolerated, and malformed blocks are
/// counted and reported instead of throwing.
library;

/// One dream entry recovered from an Awoken export file.
class AwokenImportedEntry {
  const AwokenImportedEntry({
    required this.date,
    required this.isLucid,
    required this.body,
  });

  /// The dream's calendar day, normalized to local midnight.
  final DateTime date;

  /// Whether the dream was marked lucid.
  final bool isLucid;

  /// Free-text body, with leading/trailing blank lines stripped.
  final String body;

  @override
  bool operator ==(Object other) =>
      other is AwokenImportedEntry &&
      other.date == date &&
      other.isLucid == isLucid &&
      other.body == body;

  @override
  int get hashCode => Object.hash(date, isLucid, body);

  @override
  String toString() =>
      'AwokenImportedEntry($date, lucid: $isLucid, ${body.length} chars)';
}

/// Outcome of parsing an export file. Never throws: every anomaly is
/// reflected in [skippedCount] and [warnings].
class AwokenImportParseResult {
  const AwokenImportParseResult({
    required this.entries,
    required this.skippedCount,
    required this.warnings,
  });

  /// Successfully parsed entries, in file order (newest first in practice).
  final List<AwokenImportedEntry> entries;

  /// Blocks that looked like entries but could not be read.
  final int skippedCount;

  /// Human-readable notes about skipped blocks and oddities.
  final List<String> warnings;

  /// Total lucid entries in [entries].
  int get lucidCount => entries.where((e) => e.isLucid).length;

  /// Earliest parsed dream day, or null when [entries] is empty.
  DateTime? get firstDate {
    if (entries.isEmpty) return null;
    return entries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Latest parsed dream day, or null when [entries] is empty.
  DateTime? get lastDate {
    if (entries.isEmpty) return null;
    return entries.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// Parses Awoken-format export text. Stateful but effectively immutable;
/// a single shared instance is fine.
class AwokenImportParser {
  const AwokenImportParser();

  /// A line of exactly four dashes (trailing whitespace tolerated) — the
  /// only entry separator. Three-dash `---` lines and indented lines are
  /// ordinary body content and never split an entry.
  static final RegExp _separator = RegExp(r'^----\s*$');

  static final RegExp _blank = RegExp(r'^\s*$');

  /// Parses [contents] into entries. Garbage input yields an empty result
  /// with warnings; it never throws.
  AwokenImportParseResult parse(String contents) {
    final entries = <AwokenImportedEntry>[];
    final warnings = <String>[];
    var skipped = 0;

    if (contents.trim().isEmpty) {
      warnings.add('The file is empty.');
      return AwokenImportParseResult(
        entries: entries,
        skippedCount: skipped,
        warnings: warnings,
      );
    }

    final lines = contents.split(RegExp(r'\r\n|\r|\n'));

    // Split into blocks on `----` lines. The first block is the file header
    // (title/link lines) and is ignored; every later block is one entry.
    final blocks = <List<String>>[];
    var current = <String>[];
    var sawSeparator = false;
    for (final line in lines) {
      if (_separator.hasMatch(line)) {
        sawSeparator = true;
        blocks.add(current);
        current = <String>[];
      } else {
        current.add(line);
      }
    }
    blocks.add(current);

    if (!sawSeparator) {
      warnings.add(
        'No entry separators (----) found — this does not look like an '
        'Awoken export file.',
      );
      return AwokenImportParseResult(
        entries: entries,
        skippedCount: skipped,
        warnings: warnings,
      );
    }

    // Skip block 0 (the preamble before the first separator).
    for (var i = 1; i < blocks.length; i++) {
      final block = blocks[i];
      // Ignore a trailing block that is entirely blank (file tail).
      if (block.every((line) => _blank.hasMatch(line))) continue;
      final parsed = _parseBlock(block, i, warnings);
      if (parsed == null) {
        skipped++;
      } else {
        entries.add(parsed);
      }
    }

    return AwokenImportParseResult(
      entries: entries,
      skippedCount: skipped,
      warnings: warnings,
    );
  }

  /// Parses one entry block; returns null (after logging a warning) when the
  /// block is unusable. [blockIndex] is the 1-based position among blocks.
  AwokenImportedEntry? _parseBlock(
    List<String> block,
    int blockIndex,
    List<String> warnings,
  ) {
    String? dateLine;
    String? lucidityLine;
    var dreamIndex = -1;

    for (var i = 0; i < block.length; i++) {
      final line = block[i];
      if (dateLine == null && line.startsWith('Date: ')) {
        dateLine = line;
      } else if (lucidityLine == null && line.startsWith('Lucidity: ')) {
        lucidityLine = line;
      } else if (dreamIndex < 0 &&
          (line == 'Dream:' || line.startsWith('Dream: '))) {
        dreamIndex = i;
      }
    }

    if (dateLine == null) {
      warnings.add('Block $blockIndex: missing "Date:" label — skipped.');
      return null;
    }
    if (dreamIndex < 0) {
      warnings.add('Block $blockIndex: missing "Dream:" label — skipped.');
      return null;
    }

    final date = _parseDate(dateLine.substring('Date: '.length));
    if (date == null) {
      warnings.add(
        'Block $blockIndex: unreadable date '
        '"${dateLine.substring('Date: '.length).trim()}" — skipped.',
      );
      return null;
    }

    var isLucid = false;
    if (lucidityLine == null) {
      warnings.add(
        'Block $blockIndex: missing "Lucidity:" label — assuming "No".',
      );
    } else {
      final value = lucidityLine.substring('Lucidity: '.length).trim();
      if (value == 'Yes') {
        isLucid = true;
      } else if (value != 'No') {
        warnings.add(
          'Block $blockIndex: unexpected lucidity "$value" — assuming "No".',
        );
      }
    }

    // Body: everything after the "Dream:" line, minus surrounding blanks.
    final bodyLines = block.sublist(dreamIndex + 1);
    var start = 0;
    var end = bodyLines.length;
    while (start < end && _blank.hasMatch(bodyLines[start])) {
      start++;
    }
    while (end > start && _blank.hasMatch(bodyLines[end - 1])) {
      end--;
    }
    if (start >= end) {
      warnings.add('Block $blockIndex: empty dream body — skipped.');
      return null;
    }
    final body = bodyLines.sublist(start, end).join('\n');

    return AwokenImportedEntry(date: date, isLucid: isLucid, body: body);
  }

  /// Liberal parser for `E dd MMM yyyy` dates. The weekday token is ignored
  /// entirely, and month names are matched case-insensitively on their first
  /// three letters, so `Sep`, `Sept` and `September` all work.
  static DateTime? _parseDate(String raw) {
    final tokens = raw.trim().split(RegExp(r'\s+'));
    // Drop a leading non-numeric token (the weekday), if present.
    if (tokens.isNotEmpty && int.tryParse(tokens.first) == null) {
      tokens.removeAt(0);
    }
    if (tokens.length != 3) return null;
    final day = int.tryParse(tokens[0]);
    final year = int.tryParse(tokens[2]);
    final month = _monthNumber(tokens[1]);
    if (day == null || year == null || month == null) return null;
    if (day < 1 || day > 31 || year < 1) return null;
    // DateTime rolls overflow days into the next month; reject that.
    final candidate = DateTime(year, month, day);
    if (candidate.month != month || candidate.day != day) return null;
    return candidate;
  }

  static int? _monthNumber(String name) {
    final lower = name.toLowerCase();
    // `sept` (and any longer spelling of September) normalizes to `sep`.
    final key = lower.length > 3 && lower.startsWith('sep')
        ? 'sep'
        : lower.substring(0, lower.length < 3 ? lower.length : 3);
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final index = months.indexOf(key);
    return index < 0 ? null : index + 1;
  }
}
