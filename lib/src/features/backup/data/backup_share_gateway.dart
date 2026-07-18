import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Abstraction over "write a backup file to app documents and hand it to the
/// OS share sheet", so export stays widget-testable without plugins.
abstract class BackupShareGateway {
  /// Writes [contents] to [fileName] in the app documents directory and
  /// opens the share sheet for it. Returns the written file's path.
  Future<String> writeAndShare({
    required String fileName,
    required String contents,
    required String subject,
  });
}

/// [BackupShareGateway] backed by `path_provider` and `share_plus`.
class PluginBackupShareGateway implements BackupShareGateway {
  const PluginBackupShareGateway();

  @override
  Future<String> writeAndShare({
    required String fileName,
    required String contents,
    required String subject,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(contents, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
    return file.path;
  }
}
