import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import '../domain/spell_catalog.dart';

/// Where the imported spell list lives on this device, and how it gets there.
class SpellLibrary {
  SpellLibrary({Future<File> Function()? locate, this.pick = _pickJsonFile})
    : _locate = locate ?? _defaultFile;

  final Future<File> Function() _locate;

  /// Asks the user for a JSON file and returns its text, or null if they
  /// cancelled. Replaceable in tests.
  final Future<String?> Function() pick;

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/spells.json');
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
  /// file just leaves the catalog empty.
  Future<void> load() async {
    try {
      final f = await _locate();
      if (!await f.exists()) return;
      setSpellCatalog(
        parseSpellCatalog(await f.readAsString(), allowEmpty: true),
      );
    } catch (_) {
      setSpellCatalog(const []);
    }
  }

  /// Validates [json], then replaces the stored list and the in-memory one.
  /// Throws [SpellImportException] and changes nothing if it is not valid.
  /// Returns how many spells were imported.
  Future<int> import(String json) async {
    final spells = parseSpellCatalog(json);
    final f = await _locate();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
    setSpellCatalog(spells);
    return spells.length;
  }

  /// Persists [spells] as the whole catalogue (an empty list is fine) and
  /// switches the in-memory list, and with it every suggestion, over to it.
  /// The file's `source` and `license` notes are kept. Throws, changing
  /// nothing, if the file cannot be written.
  Future<void> save(List<Spell> spells) async {
    final f = await _locate();
    await f.parent.create(recursive: true);
    final notes = await _notes(f);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      encodeSpellCatalog(spells, source: notes.$1, license: notes.$2),
      flush: true,
    );
    await tmp.rename(f.path);
    setSpellCatalog(spells);
  }

  /// The current catalogue as file text, ready to share and to re-import.
  Future<String> exportJson() async {
    final notes = await _notes(await _locate());
    return encodeSpellCatalog(
      spellCatalog,
      source: notes.$1,
      license: notes.$2,
    );
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
