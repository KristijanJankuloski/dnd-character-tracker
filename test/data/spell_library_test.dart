import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/data/spell_library.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';

const _two =
    '{"spells":[{"id":"a","name":"A","level":0},{"id":"b","name":"B","level":3}]}';
const _one = '{"spells":[{"id":"c","name":"C","level":1}]}';

void main() {
  late Directory dir;
  late SpellLibrary lib;

  setUp(() {
    resetSpellCatalogForTests();
    dir = Directory.systemTemp.createTempSync('spells');
    lib = SpellLibrary(locate: () async => File('${dir.path}/sub/spells.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('nothing stored means an empty catalog', () async {
    await lib.load();
    expect(spellCatalog, isEmpty);
  });

  test('an import is persisted and survives a reload', () async {
    expect(await lib.import(_two), 2);
    resetSpellCatalogForTests();
    await lib.load();
    expect(spellCatalog.map((s) => s.name), ['A', 'B']);
  });

  test('a new import replaces the previous list', () async {
    await lib.import(_two);
    await lib.import(_one);
    expect(spellCatalog.map((s) => s.id), ['c']);
    resetSpellCatalogForTests();
    await lib.load();
    expect(spellCatalog.map((s) => s.id), ['c']);
  });

  test('an invalid file changes nothing', () async {
    await lib.import(_two);
    await expectLater(lib.import('{"spells":[{"id":"x"}]}'),
        throwsA(isA<SpellImportException>()));
    expect(spellCatalog, hasLength(2));
    resetSpellCatalogForTests();
    await lib.load();
    expect(spellCatalog, hasLength(2));
  });
}
