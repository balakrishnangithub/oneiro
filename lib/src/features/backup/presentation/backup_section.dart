import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_x.dart';
import '../../../data/providers.dart';
import '../../settings/presentation/settings_page.dart';
import '../backup_providers.dart';
import '../domain/awoken_exporter.dart';
import '../domain/awoken_import_parser.dart';
import '../domain/awoken_import_service.dart';
import '../domain/journal_json_export.dart';

/// "Backup & Import" settings section: Awoken-format import with preview,
/// plus Awoken-compatible text and full-fidelity JSON export.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: 'Backup & Import',
      children: [
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('Import from Awoken export'),
          subtitle: const Text('Restore dreams from a .txt backup file'),
          onTap: () => _startImport(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.text_snippet_outlined),
          title: const Text('Export as Awoken-compatible text'),
          subtitle: const Text('A .txt any compatible tool can read'),
          onTap: () => _export(context, ref, json: false),
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: const Text('Export as JSON'),
          subtitle: const Text('Full fidelity: keeps ids and timestamps'),
          onTap: () => _export(context, ref, json: true),
        ),
      ],
    );
  }

  Future<void> _startImport(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(importFilePickerProvider).pickImportFile();
    if (picked == null || !context.mounted) return;

    final result = const AwokenImportParser().parse(picked.contents);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ImportPreviewDialog(
        fileName: picked.name,
        result: result,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final outcome = await _runImport(context, ref, result.entries);
    if (outcome == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import complete'),
        content: Text(
          'Imported ${outcome.imported}, skipped ${outcome.duplicates} '
          'duplicates, ${result.skippedCount} unreadable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Imports with a blocking progress dialog; returns null if cancelled by
  /// the user leaving the page mid-import.
  Future<AwokenImportOutcome?> _runImport(
    BuildContext context,
    WidgetRef ref,
    List<AwokenImportedEntry> entries,
  ) async {
    void Function(void Function())? refresh;
    var processed = 0;
    final total = entries.length;

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          refresh = setState;
          return AlertDialog(
            title: const Text('Importing dreams…'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: total == 0 ? null : processed / total,
                ),
                const SizedBox(height: 12),
                Text('$processed of $total'),
              ],
            ),
          );
        },
      ),
    );

    final outcome = await ref
        .read(awokenImportServiceProvider)
        .importEntries(
          entries,
          onProgress: (done, _) {
            processed = done;
            refresh?.call(() {});
          },
        );

    refresh = null;
    if (context.mounted) Navigator.of(context).pop();
    await dialogFuture;
    return outcome;
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool json,
  }) async {
    final repository = ref.read(dreamRepositoryProvider);
    final entries = await repository.getAllActive();
    if (!context.mounted) return;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to export yet')));
      return;
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    try {
      if (json) {
        final contents = const JournalJsonExporter().export(entries);
        await ref
            .read(backupShareGatewayProvider)
            .writeAndShare(
              fileName: 'oneiro_journal_$stamp.json',
              contents: contents,
              subject: 'Oneiro journal backup (JSON)',
            );
      } else {
        final contents = const AwokenExporter().export(
          entries.map(
            (entry) => AwokenImportedEntry(
              date: DateTime.fromMillisecondsSinceEpoch(entry.dreamDate),
              isLucid: entry.isLucid,
              body: entry.body,
            ),
          ),
        );
        await ref
            .read(backupShareGatewayProvider)
            .writeAndShare(
              fileName: 'oneiro_dreams_$stamp.txt',
              contents: contents,
              subject: 'Oneiro dream journal export',
            );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    }
  }
}

/// Shows what a parsed export file contains before anything is written:
/// entry count, date range, lucid count and malformed-block warnings.
class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({required this.fileName, required this.result});

  final String fileName;
  final AwokenImportParseResult result;

  @override
  Widget build(BuildContext context) {
    final entries = result.entries;
    final first = result.firstDate;
    final last = result.lastDate;
    return AlertDialog(
      title: const Text('Import preview'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('${entries.length} entries found'),
            if (first != null && last != null)
              Text('${formatDreamDate(first)} – ${formatDreamDate(last)}'),
            Text('${result.lucidCount} lucid'),
            if (result.skippedCount > 0)
              Text(
                '${result.skippedCount} unreadable blocks will be skipped',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Warnings',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final warning in result.warnings.take(5))
                Text(
                  '• $warning',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (result.warnings.length > 5)
                Text(
                  '…and ${result.warnings.length - 5} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: entries.isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
