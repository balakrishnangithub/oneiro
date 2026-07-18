import 'package:oneiro/src/features/backup/data/backup_share_gateway.dart';
import 'package:oneiro/src/features/backup/data/import_file_picker.dart';

/// Returns a scripted file instead of opening the platform picker.
class FakeImportFilePicker implements ImportFilePicker {
  FakeImportFilePicker({this.next});

  PickedImportFile? next;
  int pickCount = 0;

  @override
  Future<PickedImportFile?> pickImportFile() async {
    pickCount++;
    return next;
  }
}

/// Records shares instead of touching the filesystem / share sheet.
class FakeBackupShareGateway implements BackupShareGateway {
  final List<({String fileName, String contents, String subject})> shared = [];

  @override
  Future<String> writeAndShare({
    required String fileName,
    required String contents,
    required String subject,
  }) async {
    shared.add((fileName: fileName, contents: contents, subject: subject));
    return '/fake/$fileName';
  }
}
