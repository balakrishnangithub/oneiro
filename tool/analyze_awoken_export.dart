// Investigates an Awoken export file with the real Oneiro parser and dedupe
// signature: totals, lucid counts and any in-file duplicate collisions.
//
// Run from the repo root:
//   dart run tool/analyze_awoken_export.dart <path-to-export.txt>

import 'dart:io';

import 'package:oneiro/src/core/utils/date_x.dart';
import 'package:oneiro/src/features/backup/domain/awoken_import_parser.dart';

// Verbatim copy of normalizeBodyForDedupe + dreamContentSignature from
// lib/src/features/backup/domain/awoken_import_service.dart — that file pulls
// in the drift database (dart:ui), which plain `dart run` cannot load. The
// functions are deterministic pure Dart; keep them in sync with the service.
String normalizeBodyForDedupe(String body) =>
    body.trim().replaceAll(RegExp(r'\s+'), ' ');

String dreamContentSignature(int dreamDateMillis, String body) {
  final input = '$dreamDateMillis\n${normalizeBodyForDedupe(body)}';
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final unit in input.codeUnits) {
    hash = ((hash ^ BigInt.from(unit)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/analyze_awoken_export.dart <file>');
    exitCode = 2;
    return;
  }
  final file = File(args[0]);
  final contents = await file.readAsString();
  final result = AwokenImportParser().parse(contents);

  stdout
    ..writeln('parsed entries : ${result.entries.length}')
    ..writeln(
      'lucid entries  : ${result.entries.where((e) => e.isLucid).length}',
    )
    ..writeln('skipped blocks : ${result.skippedCount}');
  for (final warning in result.warnings) {
    stdout.writeln('warning        : $warning');
  }

  final bySignature = <String, List<int>>{};
  for (var i = 0; i < result.entries.length; i++) {
    final entry = result.entries[i];
    bySignature
        .putIfAbsent(
          dreamContentSignature(entry.date.dayMillis, entry.body),
          () => [],
        )
        .add(i);
  }

  final collisions = bySignature.entries.where((e) => e.value.length > 1);
  if (collisions.isEmpty) {
    stdout.writeln('duplicates     : none — every entry is unique');
    return;
  }
  for (final collision in collisions) {
    final first = result.entries[collision.value.first];
    stdout
      ..writeln('---')
      ..writeln('duplicate group: indexes ${collision.value} (0-based)')
      ..writeln('  date   : ${first.date}');
    for (final index in collision.value) {
      final body = result.entries[index].body;
      final snippet = body.length > 120 ? '${body.substring(0, 120)}…' : body;
      stdout.writeln(
        '  [$index] lucid=${result.entries[index].isLucid} "$snippet"',
      );
      stdout.writeln('       body length: ${body.length} chars');
    }
    // Are the two bodies byte-identical, or only equal after whitespace
    // normalization?
    final bodies = collision.value.map((i) => result.entries[i].body).toList();
    stdout.writeln(
      '  byte-identical bodies: '
      '${bodies.every((b) => b == bodies.first)}',
    );
  }
}
