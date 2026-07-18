import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// A text file the user picked for import.
class PickedImportFile {
  const PickedImportFile({required this.name, required this.contents});

  /// Display name of the picked file, e.g. `dreams.txt`.
  final String name;

  /// Decoded file contents (UTF-8, malformed bytes tolerated).
  final String contents;
}

/// Abstraction over the platform file picker, so the import flow can be
/// widget-tested with a fake.
abstract class ImportFilePicker {
  /// Lets the user pick a `.txt` file; returns null when the pick is
  /// cancelled or the file cannot be read.
  Future<PickedImportFile?> pickImportFile();
}

/// [ImportFilePicker] backed by the `file_picker` plugin.
class PluginImportFilePicker implements ImportFilePicker {
  const PluginImportFilePicker();

  @override
  Future<PickedImportFile?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedImportFile(
      name: file.name,
      contents: utf8.decode(bytes, allowMalformed: true),
    );
  }
}
