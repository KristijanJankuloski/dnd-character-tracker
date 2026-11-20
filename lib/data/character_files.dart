import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Picks and saves character backup files (`.json`). Replaceable in tests.
class CharacterFiles {
  const CharacterFiles({this.pick = _pickJsonFile, this.save = _saveJsonFile});

  /// Asks the user for a JSON file and returns its text, or null if they
  /// cancelled.
  final Future<String?> Function() pick;

  /// Asks the user where to save [json] as `<fileName>.json`. Returns true if
  /// the file was written, false if the user cancelled.
  final Future<bool> Function(String fileName, String json) save;

  /// A file name for [characterName], safe on common file systems.
  static String fileNameFor(String characterName) {
    final safe = characterName
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '')
        .trim();
    return safe.isEmpty ? 'character' : safe;
  }

  static Future<String?> _pickJsonFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = r?.files.single.bytes;
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Future<bool> _saveJsonFile(String fileName, String json) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save file',
      fileName: '$fileName.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: utf8.encode(json),
    );
    return path != null;
  }
}
