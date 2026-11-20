import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/feat_catalog.dart';
import '../domain/models.dart';

/// Where the imported feat list lives on this device, and how it gets there.
/// Works like `SpellLibrary`, in its own file (`feats.json`).
class FeatLibrary {
  FeatLibrary({Future<File> Function()? locate, this.pick = _pickJsonFile})
    : _locate = locate ?? _defaultFile;

  final Future<File> Function() _locate;

  /// Asks the user for a JSON file and returns its text, or null if they
  /// cancelled. Replaceable in tests.
  final Future<String?> Function() pick;

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/feats.json');
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

  /// Loads the previously imported list, if any. A missing or unreadable
  /// file just leaves the catalogue empty.
  Future<void> load() async {
    try {
      final f = await _locate();
      if (!await f.exists()) return;
      setFeatCatalog(
        parseFeatCatalog(await f.readAsString(), allowEmpty: true),
      );
    } catch (_) {
      setFeatCatalog(const []);
    }
  }

  /// Validates [json], then replaces the stored list and the in-memory one.
  /// Throws [FeatImportException] and changes nothing if it is not valid.
  /// Returns how many feats were imported.
  Future<int> import(String json) async {
    final feats = parseFeatCatalog(json);
    final f = await _locate();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
    setFeatCatalog(feats);
    return feats.length;
  }

  /// Persists [feats] as the whole catalogue (an empty list is fine). The
  /// file's `source` and `license` notes are kept. Throws, changing nothing,
  /// if the file cannot be written.
  Future<void> save(List<Feat> feats) async {
    final f = await _locate();
    await f.parent.create(recursive: true);
    final notes = await _notes(f);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      encodeFeatCatalog(feats, source: notes.$1, license: notes.$2),
      flush: true,
    );
    await tmp.rename(f.path);
    setFeatCatalog(feats);
  }

  /// The current catalogue as file text, ready to share and to re-import.
  Future<String> exportJson() async {
    final notes = await _notes(await _locate());
    return encodeFeatCatalog(featCatalog, source: notes.$1, license: notes.$2);
  }

  Future<(String?, String?)> _notes(File f) async {
    try {
      final root = jsonDecode(await f.readAsString());
      if (root is Map) {
        final s = root['source'];
        final l = root['license'];
        return (s is String ? s : null, l is String ? l : null);
      }
    } catch (_) {}
    return (null, null);
  }
}
