import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/data/feat_library.dart';
import 'package:jjs_character_tracker/domain/feat_catalog.dart';
import 'package:jjs_character_tracker/domain/models.dart';

const _two =
    '{"source":"Mine","feats":[{"id":"a","name":"A"},{"id":"b","name":"B"}]}';
const _one = '{"feats":[{"id":"c","name":"C"}]}';

void main() {
  late Directory dir;
  late FeatLibrary lib;

  setUp(() {
    resetFeatCatalogForTests();
    dir = Directory.systemTemp.createTempSync('feats');
    lib = FeatLibrary(locate: () async => File('${dir.path}/sub/feats.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('nothing stored means an empty catalogue', () async {
    await lib.load();
    expect(featCatalog, isEmpty);
  });

  test('an import is persisted and survives a reload', () async {
    expect(await lib.import(_two), 2);
    resetFeatCatalogForTests();
    await lib.load();
    expect(featCatalog.map((f) => f.name), ['A', 'B']);
  });

  test('a new import replaces the previous list', () async {
    await lib.import(_two);
    await lib.import(_one);
    expect(featCatalog.map((f) => f.id), ['c']);
  });

  test('an invalid file changes nothing', () async {
    await lib.import(_two);
    await expectLater(
      lib.import('{"feats":[{"name":"no id"}]}'),
      throwsA(isA<FeatImportException>()),
    );
    expect(featCatalog, hasLength(2));
    resetFeatCatalogForTests();
    await lib.load();
    expect(featCatalog, hasLength(2));
  });

  test('save keeps the source note and export re-imports', () async {
    await lib.import(_two);
    await lib.save([const Feat(id: 'z', name: 'Z', text: 'zed')]);
    final text = await lib.exportJson();
    expect(text, contains('"source": "Mine"'));
    expect(parseFeatCatalog(text).single.text, 'zed');
  });

  test('an unreadable stored file leaves the catalogue empty', () async {
    File('${dir.path}/sub/feats.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('garbage');
    await lib.load();
    expect(featCatalog, isEmpty);
  });
}
