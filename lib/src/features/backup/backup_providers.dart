import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'data/backup_share_gateway.dart';
import 'data/import_file_picker.dart';
import 'domain/awoken_import_service.dart';

/// Platform file picker for Awoken `.txt` imports; faked in tests.
final importFilePickerProvider = Provider<ImportFilePicker>(
  (ref) => const PluginImportFilePicker(),
);

/// Share-sheet gateway for exported backups; faked in tests.
final backupShareGatewayProvider = Provider<BackupShareGateway>(
  (ref) => const PluginBackupShareGateway(),
);

/// Dedupe-aware importer for parsed Awoken entries.
final awokenImportServiceProvider = Provider<AwokenImportService>(
  (ref) => AwokenImportService(ref.watch(dreamRepositoryProvider)),
);
